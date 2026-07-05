"""Tests for scripts/check_changelog.py — the release invariant + behaviour gate.

The parsing/release checks run against hermetic CHANGELOG/plugin.json fixtures
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

GOOD_CHANGELOG = """\
# Changelog

House rule: keep the `### [Unreleased]` heading persistent.

## steer

### [Unreleased]

- pending change

### 3.12.0

- released change

### 3.11.2

- older change

## other-plugin

### 9.9.9

- unrelated section is never counted
"""


def _write_fixture(monkeypatch, tmp_path: Path, changelog: str, version: str | None = "3.12.0"):
    """Point the module's CHANGELOG/PLUGIN_JSON at tmp fixtures."""
    changelog_path = tmp_path / "CHANGELOG.md"
    changelog_path.write_text(changelog, encoding="utf-8")
    plugin_json = tmp_path / "plugin.json"
    if version is not None:
        plugin_json.write_text(json.dumps({"name": "steer", "version": version}), encoding="utf-8")
    monkeypatch.setattr(check_changelog, "CHANGELOG", changelog_path)
    monkeypatch.setattr(check_changelog, "PLUGIN_JSON", plugin_json)


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
    (repo / "CHANGELOG.md").write_text(GOOD_CHANGELOG, encoding="utf-8")
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


# --- heading parsing ----------------------------------------------------------


def test_heading_sequence_scoped_to_steer_section(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG)
    assert check_changelog.heading_sequence() == ["[Unreleased]", "3.12.0", "3.11.2"]


def test_heading_sequence_ignores_inline_prose_mention(monkeypatch, tmp_path: Path):
    # The house-rules bullet mentions `### [Unreleased]` inline — not a heading.
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG)
    assert check_changelog.heading_sequence().count("[Unreleased]") == 1


def test_heading_sequence_missing_changelog(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(check_changelog, "CHANGELOG", tmp_path / "nope.md")
    assert check_changelog.heading_sequence() == []


def test_released_headings_filters_semver(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG)
    assert check_changelog.released_headings() == ["3.12.0", "3.11.2"]


# --- check_unreleased ----------------------------------------------------------


def test_unreleased_single_first_is_clean(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG)
    errors: list[str] = []
    check_changelog.check_unreleased(errors)
    assert errors == []


def test_unreleased_duplicated_flagged(monkeypatch, tmp_path: Path):
    dup = GOOD_CHANGELOG.replace("### 3.11.2", "### [Unreleased]\n\n### 3.11.2")
    _write_fixture(monkeypatch, tmp_path, dup)
    errors: list[str] = []
    check_changelog.check_unreleased(errors)
    assert len(errors) == 1
    assert "appears 2 times" in errors[0]


def test_unreleased_not_first_flagged(monkeypatch, tmp_path: Path):
    swapped = GOOD_CHANGELOG.replace("### [Unreleased]\n\n- pending change\n\n", "")
    swapped = swapped.replace("### 3.11.2", "### [Unreleased]")
    _write_fixture(monkeypatch, tmp_path, swapped)
    errors: list[str] = []
    check_changelog.check_unreleased(errors)
    assert errors and "must be the first heading" in errors[0]


# --- check_release ---------------------------------------------------------------


def test_release_version_matches(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG, version="3.12.0")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors == []


def test_release_version_mismatch(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG, version="3.13.0")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors and "3.13.0 != newest released CHANGELOG heading 3.12.0" in errors[0]


def test_release_missing_plugin_json(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG, version=None)
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors and "missing" in errors[0]


def test_release_invalid_plugin_json(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG)
    check_changelog.PLUGIN_JSON.write_text("{not json", encoding="utf-8")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors and "invalid JSON" in errors[0]


def test_release_missing_version_key(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, GOOD_CHANGELOG)
    check_changelog.PLUGIN_JSON.write_text('{"name": "steer"}', encoding="utf-8")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors and "missing version" in errors[0]


def test_release_no_released_heading(monkeypatch, tmp_path: Path):
    _write_fixture(monkeypatch, tmp_path, "# Changelog\n\n## steer\n\n### [Unreleased]\n")
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert errors and "no released" in errors[0]


def test_release_non_descending_order(monkeypatch, tmp_path: Path):
    bad = GOOD_CHANGELOG.replace("### 3.11.2", "### 3.12.1")
    _write_fixture(monkeypatch, tmp_path, bad)
    errors: list[str] = []
    check_changelog.check_release(errors)
    assert any("not in descending order" in e for e in errors)


# --- behaviour path classification -----------------------------------------------


def test_is_behaviour_classification():
    f = check_changelog._is_behaviour
    assert f("plugins/steer/skills/spec/SKILL.md")
    assert f("plugins/steer/rules/10-x.md")
    assert f("plugins/steer/scripts/scan-prereqs.sh")
    assert f("plugins/steer/.claude-plugin/plugin.json")  # exact entry
    # tests are exempt wherever they live under the plugin
    assert not f("plugins/steer/hooks/tests/run.sh")
    # repo-level infrastructure is not plugin behaviour
    assert not f("scripts/check_changelog.py")
    assert not f("CLAUDE.md")
    assert not f("docs/index.md")


# --- _changed_files + behaviour gate against real git repos -----------------------


def test_changed_files_three_dot(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "change skill")
    changed = check_changelog._changed_files("main")
    assert changed == ["plugins/steer/skills/demo/SKILL.md"]


def test_changed_files_two_dot_fallback_without_merge_base(git_repo: Path):
    # An orphan branch has NO merge base with main: the three-dot diff fails and
    # the gate must fall back to a plain two-dot diff instead of giving up.
    _git(git_repo, "checkout", "-q", "--orphan", "detached-history")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("orphan\n", encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "orphan")
    changed = check_changelog._changed_files("main")
    assert changed is not None
    assert "plugins/steer/skills/demo/SKILL.md" in changed


def test_changed_files_fail_open_on_bad_ref(git_repo: Path):
    assert check_changelog._changed_files("no-such-ref") is None


def test_behaviour_gate_requires_changelog(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "change skill without changelog")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert len(errors) == 1
    assert "CHANGELOG.md must change" in errors[0]
    assert "plugins/steer/skills/demo/SKILL.md" in errors[0]


def test_behaviour_gate_satisfied_by_changelog_entry(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    changelog = git_repo / "CHANGELOG.md"
    text = changelog.read_text(encoding="utf-8")
    changelog.write_text(
        text.replace("- pending change", "- pending change\n- new"), encoding="utf-8"
    )
    _git(git_repo, "commit", "-qam", "change skill + changelog")
    errors: list[str] = []
    check_changelog.check_behaviour_gate("main", errors)
    assert errors == []


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
    """Every validation script must stay runnable on stock 3.9–3.13 interpreters
    (they carry python3 shebangs). feature_version rejects 3.14-only syntax such
    as PEP 758 un-parenthesized `except A, B:` clauses."""
    for script in sorted((REPO_ROOT / "scripts").glob("*.py")):
        src = script.read_text(encoding="utf-8")
        try:
            ast.parse(src, filename=str(script), feature_version=(3, 10))
        except SyntaxError as exc:  # pragma: no cover - failure message only
            raise AssertionError(f"{script.name} uses post-3.10 syntax: {exc}") from exc
