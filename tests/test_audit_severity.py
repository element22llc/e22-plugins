"""Tests for scripts/audit_severity.py — the blast-radius severity ceiling.

The property under test is the one the release gate rests on: severity is a pure
function of the path, and `cap` only ever moves a finding *down*. The regression
case is `docs/reference/hooks.md`, the docs-site page whose wording nit was
graded a blocker and halted the 6.0.0 cut.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import audit_severity  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


@pytest.mark.parametrize(
    ("path", "tier", "ceiling"),
    [
        # Release-critical: the manifests whose agreement *is* the release.
        ("CHANGELOG.md", "release-critical", "blocker"),
        ("plugins/steer/.claude-plugin/plugin.json", "release-critical", "blocker"),
        ("plugins/steer/.github/plugin/plugin.json", "release-critical", "blocker"),
        (".github/plugin/marketplace.json", "release-critical", "blocker"),
        (".claude-plugin/marketplace.json", "release-critical", "blocker"),
        # Shipped executables reach a consumer session.
        ("plugins/steer/hooks/lib/json.sh", "shipped-code", "high"),
        ("plugins/steer/hooks/check-bash-actions.sh", "shipped-code", "high"),
        ("plugins/steer/scripts/scaffold_reconcile.py", "shipped-code", "high"),
        ("plugins/steer/hooks/hooks.json", "shipped-code", "high"),
        ("plugins/steer/.mcp.json", "shipped-code", "high"),
        # Shipped prose misleads; it does not misexecute.
        ("plugins/steer/rules/24-worktrees.md", "shipped-prose", "medium"),
        ("plugins/steer/skills/intake/SKILL.md", "shipped-prose", "medium"),
        ("plugins/steer/templates/reference/MIGRATIONS.md", "shipped-prose", "medium"),
        ("plugins/steer/agents/steer-reviewer.md", "shipped-prose", "medium"),
        # Repo tooling ships nothing but can blind a gate.
        ("scripts/check_changelog.py", "repo-tooling", "medium"),
        ("mise.toml", "repo-tooling", "medium"),
        (".github/workflows/plugin-quality.yml", "repo-tooling", "medium"),
        # Non-shipping: real findings, never a reason to hold a release.
        ("docs/reference/hooks.md", "non-shipping", "low"),
        ("docs/concepts/copilot-support.md", "non-shipping", "low"),
        ("CLAUDE.md", "non-shipping", "low"),
        ("CROSS-SURFACE.md", "non-shipping", "low"),
        (".claude/audit/PRE-RELEASE-AUDIT.md", "non-shipping", "low"),
        ("plugins/steer/README.md", "non-shipping", "low"),
        ("plugins/steer/hooks/tests/run.sh", "non-shipping", "low"),
        ("plugins/steer/evals/routes-lost-user-to-next/case.yaml", "non-shipping", "low"),
    ],
)
def test_classification(path: str, tier: str, ceiling: str) -> None:
    assert audit_severity.classify(path) == tier
    assert audit_severity.ceiling(path) == ceiling


def test_leading_dot_slash_is_normalised() -> None:
    assert audit_severity.classify("./CHANGELOG.md") == "release-critical"


def test_empty_path_rejected() -> None:
    with pytest.raises(ValueError):
        audit_severity.classify("   ")


def test_cap_never_escalates() -> None:
    """A reviewer may rank below the ceiling; it may never rank above it."""
    # The 6.0.0 regression: a docs-site nit graded blocker becomes low.
    assert audit_severity.cap("docs/reference/hooks.md", "blocker") == "low"
    assert audit_severity.cap("docs/reference/hooks.md", "high") == "low"
    # Below the ceiling is preserved — capping clamps down only.
    assert audit_severity.cap("plugins/steer/hooks/lib/json.sh", "low") == "low"
    assert audit_severity.cap("plugins/steer/hooks/lib/json.sh", "blocker") == "high"
    assert audit_severity.cap("CHANGELOG.md", "blocker") == "blocker"
    assert audit_severity.cap("CHANGELOG.md", "low") == "low"


def test_cap_rejects_unknown_severity() -> None:
    with pytest.raises(ValueError):
        audit_severity.cap("CHANGELOG.md", "critical")


def test_blocks_release_only_for_release_critical() -> None:
    assert audit_severity.blocks_release("CHANGELOG.md", "blocker")
    assert not audit_severity.blocks_release("docs/reference/hooks.md", "blocker")
    assert not audit_severity.blocks_release("plugins/steer/hooks/lib/json.sh", "blocker")
    assert not audit_severity.blocks_release("CHANGELOG.md", "high")


def test_shipping_boundary_is_not_duplicated() -> None:
    """The classifier must agree with the changelog gate's own definition.

    If these ever diverge, one gate demands a CHANGELOG entry for a path the
    other calls non-shipping — which is the drift this module exists to prevent.
    """
    import check_changelog

    for path in (
        "plugins/steer/rules/24-worktrees.md",
        "plugins/steer/hooks/lib/json.sh",
        ".github/plugin/marketplace.json",
    ):
        assert check_changelog._is_behaviour(path)
        assert audit_severity.classify(path) != "non-shipping"

    for path in ("docs/reference/hooks.md", "plugins/steer/README.md", "CLAUDE.md"):
        assert not check_changelog._is_behaviour(path)


def test_cli_reports_ceilings() -> None:
    out = subprocess.run(
        [
            sys.executable,
            "scripts/audit_severity.py",
            "--explain",
            "docs/reference/hooks.md",
            "CHANGELOG.md",
        ],
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
        check=True,
    )
    assert "low" in out.stdout and "non-shipping" in out.stdout
    assert "blocker" in out.stdout and "release-critical" in out.stdout


def test_cli_requires_paths() -> None:
    out = subprocess.run(
        [sys.executable, "scripts/audit_severity.py"],
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
        check=False,
    )
    assert out.returncode != 0
