"""Tests for scripts/check_changelog.py - the release invariant + behaviour gate.

The release/fragment validators run against hermetic `.changes/` fixtures
(monkeypatched module paths); the ``--base`` behaviour gate runs against real
throwaway git repos so the three-dot diff, the two-dot fallback, and the
fail-open path are exercised for real.
"""

from __future__ import annotations

import ast
import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_changelog  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


# --- fixtures ---------------------------------------------------------------

CHANGIE_CONFIG = """\
kinds:
  - label: Added
    auto: minor
  - label: Fixed
    auto: patch
"""

FRAGMENT = """\
kind: Fixed
time: 2026-01-01T00:00:00.000000-05:00
custom:
  Slug: a-pending-change
body: '- **Fixed: a pending change.** detail.'
"""


def _changes_tree(root: Path, versions: dict[str, str], fragments: dict[str, str] | None = None):
    """Lay out `.changes/` + the assembled CHANGELOG.md for `versions`."""
    changes = root / ".changes"
    (changes / "unreleased").mkdir(parents=True, exist_ok=True)
    for version, body in versions.items():
        (changes / f"v{version}.md").write_text(f"## {version}\n\n{body}\n", encoding="utf-8")
    for name, text in (fragments or {}).items():
        (changes / "unreleased" / name).write_text(text, encoding="utf-8")
    ordered = sorted(versions, key=check_changelog._semver, reverse=True)
    assembled = "# Changelog\n\n" + "\n".join(f"## {v}\n\n{versions[v]}\n" for v in ordered)
    (root / "CHANGELOG.md").write_text(assembled, encoding="utf-8")
    return changes


def _write_fixture(
    monkeypatch,
    tmp_path: Path,
    versions: dict[str, str],
    version: str | None = "3.12.0",
    fragments: dict[str, str] | None = None,
):
    """Point the module's paths at tmp fixtures."""
    changes = _changes_tree(tmp_path, versions, fragments)
    plugin_json = tmp_path / "plugin.json"
    if version is not None:
        plugin_json.write_text(json.dumps({"name": "steer", "version": version}), encoding="utf-8")
    config = tmp_path / ".changie.yaml"
    config.write_text(CHANGIE_CONFIG, encoding="utf-8")
    monkeypatch.setattr(check_changelog, "CHANGELOG", tmp_path / "CHANGELOG.md")
    monkeypatch.setattr(check_changelog, "PLUGIN_JSON", plugin_json)
    monkeypatch.setattr(check_changelog, "CHANGES_DIR", changes)
    monkeypatch.setattr(check_changelog, "UNRELEASED_DIR", changes / "unreleased")
    monkeypatch.setattr(check_changelog, "CHANGIE_CONFIG", config)


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True)


@pytest.fixture
def git_repo(tmp_path: Path, monkeypatch) -> Path:
    """A real git repo laid out like the marketplace, cwd pinned inside it."""
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q", "-b", "main")
    _git(repo, "config", "user.email", "t@example.com")
    _git(repo, "config", "user.name", "t")
    _changes_tree(repo, {"3.12.0": "- released change"})
    plugin_json = repo / "plugins/steer/.claude-plugin/plugin.json"
    plugin_json.parent.mkdir(parents=True)
    plugin_json.write_text(json.dumps({"name": "steer", "version": "3.12.0"}), encoding="utf-8")
    skill = repo / "plugins/steer/skills/demo/SKILL.md"
    skill.parent.mkdir(parents=True)
    skill.write_text("---\nname: demo\n---\nbody\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", "base")
    monkeypatch.chdir(repo)
    return repo


# --- release validator on the live repo --------------------------------------


def test_real_repo_passes(monkeypatch):
    monkeypatch.chdir(REPO_ROOT)
    assert check_changelog.main([]) == 0


# --- release validator -------------------------------------------------------


def test_version_files_are_sorted_by_semver_not_lexically(monkeypatch, tmp_path: Path):
    _write_fixture(
        monkeypatch, tmp_path, {"3.9.0": "- a", "3.16.0": "- b", "3.24.0": "- c"}, version="3.24.0"
    )
    assert check_changelog.version_files() == ["3.24.0", "3.16.0", "3.9.0"]


def test_release_version_matches(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a", "3.11.2": "- b"})
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors == []


def test_release_version_mismatch(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a"}, version="3.13.0")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("!= newest version file" in e for e in errors)


def test_release_missing_plugin_json(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a"}, version=None)
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("missing" in e for e in errors)


def test_release_invalid_plugin_json(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a"})
    check_changelog.PLUGIN_JSON.write_text("{not json", encoding="utf-8")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("invalid JSON" in e for e in errors)


def test_release_missing_version_key(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a"})
    check_changelog.PLUGIN_JSON.write_text(json.dumps({"name": "steer"}), encoding="utf-8")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("missing version" in e for e in errors)


def test_release_no_version_files(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {})
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("no released" in e for e in errors)


def test_hand_edited_changelog_is_flagged(monkeypatch, tmp_path: Path):
    """CHANGELOG.md is generated: drift means the next merge would revert it."""
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a", "3.11.2": "- b"})
    changelog = check_changelog.CHANGELOG
    changelog.write_text(
        changelog.read_text(encoding="utf-8").replace("## 3.11.2", "## 3.11.3"), encoding="utf-8"
    )
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("out of sync" in e for e in errors)


# --- fragment validator ------------------------------------------------------


def test_valid_fragment_passes(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a"}, fragments={"fixed-x.yaml": FRAGMENT})
    errors: list[str] = []
    check_changelog.check_fragments(errors)
    assert errors == []


@pytest.mark.parametrize(
    ("mutation", "expected"),
    [
        ("kind: Nope\n", "is not one of"),
        ("body: ''\n", "empty body"),
        ("no-slug", "missing custom.Slug"),
    ],
)
def test_malformed_fragment_is_flagged(monkeypatch, tmp_path: Path, mutation: str, expected: str):
    if mutation == "no-slug":
        text = FRAGMENT.replace("custom:\n  Slug: a-pending-change\n", "")
    elif mutation.startswith("kind:"):
        text = FRAGMENT.replace("kind: Fixed\n", mutation)
    else:
        text = FRAGMENT.replace("body: '- **Fixed: a pending change.** detail.'\n", mutation)
    _write_fixture(monkeypatch, tmp_path, {"3.12.0": "- a"}, fragments={"bad.yaml": text})
    errors: list[str] = []
    check_changelog.check_fragments(errors)
    assert any(expected in e for e in errors), errors


def test_unparseable_fragment_is_flagged(monkeypatch, tmp_path: Path):
    _write_fixture(
        monkeypatch, tmp_path, {"3.12.0": "- a"}, fragments={"bad.yaml": "kind: [unclosed\n"}
    )
    errors: list[str] = []
    check_changelog.check_fragments(errors)
    assert any("invalid YAML" in e for e in errors)


# --- behaviour path classification -----------------------------------------------


def test_is_behaviour_classification():
    f = check_changelog._is_behaviour
    assert f("plugins/steer/skills/spec/SKILL.md")
    assert f("plugins/steer/rules/10-x.md")
    assert f("plugins/steer/scripts/scan-prereqs.sh")
    # all three version-bearing manifests count
    assert f("plugins/steer/.claude-plugin/plugin.json")
    assert f("plugins/steer/.github/plugin/plugin.json")
    assert f(".github/plugin/marketplace.json")
    # tests are exempt wherever they live under the plugin
    assert not f("plugins/steer/hooks/tests/run.sh")
    # repo-level infrastructure is not plugin behaviour
    assert not f("scripts/check_changelog.py")
    # ...including the rest of the root .github/, which ships nothing
    assert not f(".github/workflows/plugin-quality.yml")
    assert not f(".github/pull_request_template.md")
    assert not f("CLAUDE.md")
    assert not f("docs/index.md")


def test_is_behaviour_covers_the_two_allowlist_regressions():
    """Both shipped surfaces an allowlist of directory prefixes used to miss."""
    f = check_changelog._is_behaviour
    # the MCP servers every consumer gets
    assert f("plugins/steer/.mcp.json")
    # the steer-reviewer subagent /steer:audit and /steer:work --reviewed invoke
    assert f("plugins/steer/agents/steer-reviewer.md")


def test_is_behaviour_is_deny_by_default_for_unknown_components():
    """A plugin component that does not exist yet is gated the day it lands."""
    f = check_changelog._is_behaviour
    for path in (
        "plugins/steer/monitors/build.json",
        "plugins/steer/output-styles/terse.md",
        "plugins/steer/bin/steer",
        "plugins/steer/.lsp.json",
    ):
        assert f(path), path


def test_exemptions_are_anchored_and_cannot_widen_to_the_plugin_root():
    f = check_changelog._is_behaviour
    # the exempt paths themselves
    assert not f("plugins/steer/README.md")
    assert not f("plugins/steer/evals/routing/case.yml")
    assert not f("plugins/steer/.claude/settings.json")
    # ...but no exemption leaks to a sibling that merely shares its prefix
    assert f("plugins/steer/README-SHIPPED.md")
    assert f("plugins/steer/evals-runtime/thing.md")
    assert f("plugins/steer/.claude-plugin/plugin.json")
    # a plugin-root file is behaviour, not swept up by an exemption
    assert f("plugins/steer/.mcp.json")
    # and the exemptions do not reach outside the plugin either
    assert not f("evals/x.yml")
    assert not f("README.md")


# --- _changed_files + behaviour gate against real git repos -----------------------


def _paths(changed) -> list[str]:
    return [p for _, p in changed]


def test_changed_files_three_dot(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "change skill")
    changed = check_changelog._changed_files("main")
    assert _paths(changed) == ["plugins/steer/skills/demo/SKILL.md"]
    assert changed[0][0].startswith("M")


def test_changed_files_two_dot_fallback_without_merge_base(git_repo: Path):
    # An orphan branch has NO merge base with main: the three-dot diff fails and
    # the gate must fall back to a plain two-dot diff instead of giving up.
    _git(git_repo, "checkout", "-q", "--orphan", "detached-history")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("orphan\n", encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "orphan")
    changed = check_changelog._changed_files("main")
    assert changed is not None
    assert "plugins/steer/skills/demo/SKILL.md" in _paths(changed)


def test_changed_files_fail_open_on_bad_ref(git_repo: Path):
    assert check_changelog._changed_files("no-such-ref") is None


def test_behaviour_gate_requires_a_fragment(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "change skill without a fragment")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert len(errors) == 1
    assert "changelog fragment must be added" in errors[0]
    assert "plugins/steer/skills/demo/SKILL.md" in errors[0]


def test_behaviour_gate_satisfied_by_an_added_fragment(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    (git_repo / ".changes/unreleased/fixed-20260101-0000-demo.yaml").write_text(
        FRAGMENT, encoding="utf-8"
    )
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "change skill + fragment")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert errors == []


def test_behaviour_gate_satisfied_by_a_release_cut(git_repo: Path):
    """A release cut empties `unreleased/`, so the version file is its record."""
    frag = git_repo / ".changes/unreleased/fixed-20260101-0000-demo.yaml"
    frag.write_text(FRAGMENT, encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "pending fragment")
    _git(git_repo, "checkout", "-q", "-b", "chore/release-9.9.9")
    # What `changie batch` + `merge` leave behind: the fragment is gone, a version
    # file is added, and the version-bearing manifests moved.
    frag.unlink()
    (git_repo / ".changes/v9.9.9.md").write_text("## 9.9.9\n\n- entry\n", encoding="utf-8")
    (git_repo / "plugins/steer/.claude-plugin/plugin.json").write_text(
        '{"name": "steer", "version": "9.9.9"}\n', encoding="utf-8"
    )
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "chore(release): steer 9.9.9")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert errors == []


def test_behaviour_gate_ignores_a_non_version_file_under_changes(git_repo: Path):
    """Only a `vX.Y.Z.md` counts as a cut - not any file dropped in `.changes/`."""
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    (git_repo / ".changes/notes.md").write_text("scratch\n", encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "change skill + a stray .changes file")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert len(errors) == 1
    assert "changelog fragment must be added" in errors[0]


def test_behaviour_gate_rejects_editing_someone_elses_pending_fragment(git_repo: Path):
    """Amending an existing fragment is not recording THIS change."""
    frag = git_repo / ".changes/unreleased/fixed-20260101-0000-demo.yaml"
    frag.write_text(FRAGMENT, encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "pre-existing fragment")
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    frag.write_text(FRAGMENT.replace("detail.", "edited detail."), encoding="utf-8")
    _git(git_repo, "commit", "-qam", "change skill + edit an existing fragment")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert len(errors) == 1
    assert "changelog fragment must be added" in errors[0]


def test_behaviour_gate_tests_exempt(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    hook_test = git_repo / "plugins/steer/hooks/tests/run.sh"
    hook_test.parent.mkdir(parents=True)
    hook_test.write_text("echo test\n", encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "test-only change")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert errors == []


def test_behaviour_gate_fails_open_when_diff_impossible(git_repo: Path, capsys):
    errors: list[str] = []
    check_changelog.check_behaviour_gate("no-such-ref", errors)
    assert errors == []
    assert "skipping behaviour gate" in capsys.readouterr().out


def test_main_with_base_flags_missing_entry(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "behaviour change")
    assert check_changelog.main(["--base", "main"]) == 1
    assert check_changelog.main([]) == 0  # release validator alone stays green


# --- syntax portability (issue #329) ------------------------------------------------


def test_scripts_parse_on_pre_314_grammar():
    """Every validation script must stay runnable on stock 3.9-3.13 interpreters
    (they carry python3 shebangs). feature_version rejects 3.14-only syntax such
    as PEP 758 un-parenthesized `except A, B:` clauses."""
    for script in sorted((REPO_ROOT / "scripts").glob("*.py")):
        src = script.read_text(encoding="utf-8")
        try:
            ast.parse(src, filename=str(script), feature_version=(3, 10))
        except SyntaxError as exc:  # pragma: no cover - failure message only
            raise AssertionError(f"{script.name} uses post-3.10 syntax: {exc}") from exc
