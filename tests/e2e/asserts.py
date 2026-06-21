"""Structural assertions over a repo a steer skill has just produced.

Deliberately checks *invariants* (file presence + grep-able wiring markers), not
exact prose — LLM output varies. The source of truth for every marker is
``plugins/steer/templates/reference/CAPABILITIES.md`` (the ``always`` entries)
plus the spec-spine file list the ``init``/``adopt`` skills instantiate. When a
capability's ``Wired-when`` marker changes there, update the matching assert
here.
"""

from __future__ import annotations

import re
from pathlib import Path

# --- low-level helpers ----------------------------------------------------


def assert_file(repo: Path, rel: str) -> Path:
    p = repo / rel
    assert p.is_file(), f"expected file missing: {rel}"
    return p


def assert_contains(repo: Path, rel: str, needle: str) -> None:
    text = assert_file(repo, rel).read_text(encoding="utf-8")
    assert needle in text, f"{rel} missing expected marker: {needle!r}"


def assert_matches(repo: Path, rel: str, pattern: str) -> None:
    text = assert_file(repo, rel).read_text(encoding="utf-8")
    assert re.search(pattern, text), f"{rel} does not match /{pattern}/"


# --- capability bundles (CAPABILITIES.md "always" entries + spine) --------

# The spec spine the init/adopt skills instantiate.
SPINE_FILES = (
    "spec/vision.md",
    "spec/users.md",
    "spec/glossary.md",
    "spec/HISTORY.md",
    "spec/tracker.md",
    "spec/app/README.md",
)


def assert_spec_spine(repo: Path) -> None:
    """Spine complete and version-stamped (``spec/.version`` carries a semver)."""
    assert_matches(repo, "spec/.version", r"\d+\.\d+\.\d+")
    for rel in SPINE_FILES:
        assert_file(repo, rel)


def assert_plugin_enabled_local(repo: Path) -> None:
    """capability ``plugin-enabled-local``: settings.json enables the plugin."""
    assert_contains(repo, ".claude/settings.json", "steer@e22-plugins")


def assert_toolchain_pin(repo: Path) -> None:
    """capability ``toolchain-pin``: mise.toml + mise.lock present."""
    assert_file(repo, "mise.toml")
    assert_file(repo, "mise.lock")


def assert_version_pin_enforcement(repo: Path) -> None:
    """capability ``version-pin-enforcement``: policy + scanner scripts present."""
    assert_file(repo, "policy/versions.yml")
    assert_file(repo, "scripts/scan-version-pins.sh")
    assert_file(repo, "scripts/version-policy.sh")


def assert_branch_protection_policy(repo: Path) -> None:
    """capability ``branch-protection-policy``: machine-readable gate present."""
    assert_file(repo, "policy/branch-protection.yml")


def assert_drift_gate(repo: Path) -> None:
    """capability ``drift-gate``: CI hygiene job + PR template."""
    assert_contains(repo, ".github/workflows/ci.yml", "scan-version-pins.sh")
    assert_file(repo, ".github/pull_request_template.md")


def assert_in_ci_plugin_loading(repo: Path) -> None:
    """capability ``in-ci-plugin-loading``: claude.yml loads via plugin_marketplaces
    (an enabledPlugins block does NOT count — it no-ops in headless CI)."""
    assert_contains(repo, ".github/workflows/claude.yml", "plugin_marketplaces")


def assert_dependency_automation(repo: Path) -> None:
    """capability ``dependency-automation``: Dependabot + auto-merge workflow."""
    assert_file(repo, ".github/dependabot.yml")
    assert_file(repo, ".github/workflows/dependabot-auto-merge.yml")


# A *chosen* "Status: Accepted" — not the ADR template's enumeration line
# "Status: Proposed | Accepted | ...", which starts "Status: Proposed".
_ACCEPTED_ADR = re.compile(r"Status:\s*Accepted\b")


def assert_no_accepted_adr(repo: Path) -> None:
    """``/steer:adopt`` reverse-engineers ADRs as Proposed and must NEVER mint an
    Accepted ADR from inferred code (the adopt-no-adr-from-inference invariant).
    No Markdown file under ``spec/`` may carry a chosen ``Status: Accepted``."""
    spec = repo / "spec"
    offenders = [
        str(md.relative_to(repo))
        for md in spec.rglob("*.md")
        if any(_ACCEPTED_ADR.search(line) for line in md.read_text(encoding="utf-8").splitlines())
    ]
    assert not offenders, f"adopt produced Accepted ADR(s) from inference: {offenders}"
