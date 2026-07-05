"""Tests for scripts/check_docs_impact.py — the PR docs-impact gate.

Covers the doc-bearing path classification (including the agents/ surface from
issue #330) and, against real throwaway git repos, the gate's diff semantics:
three-dot diff, two-dot fallback, and the fail-open path (issue #340 aligned it
with check_changelog.py instead of fail-closing on a missing merge base).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_docs_impact  # noqa: E402


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True, text=True)


@pytest.fixture
def git_repo(tmp_path: Path, monkeypatch) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-q", "-b", "main")
    _git(repo, "config", "user.email", "t@example.com")
    _git(repo, "config", "user.name", "t")
    skill = repo / "plugins/steer/skills/demo/SKILL.md"
    skill.parent.mkdir(parents=True)
    skill.write_text("---\nname: demo\n---\nbody\n", encoding="utf-8")
    docs = repo / "docs/index.md"
    docs.parent.mkdir(parents=True)
    docs.write_text("# docs\n", encoding="utf-8")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "-m", "base")
    monkeypatch.chdir(repo)
    return repo


# --- doc-bearing classification ----------------------------------------------


def test_is_doc_bearing_surfaces():
    f = check_docs_impact._is_doc_bearing
    assert f("plugins/steer/skills/spec/SKILL.md")
    assert f("plugins/steer/rules/10-x.md")
    assert f("plugins/steer/hooks/hooks.json")
    # issue #330: the docs site documents shipped subagents too
    assert f("plugins/steer/agents/steer-reviewer.md")
    # exemptions: tests and internal hook libraries have no documented surface
    assert not f("plugins/steer/hooks/tests/run.sh")
    assert not f("plugins/steer/hooks/lib/json.sh")
    # not part of the documented surface at all
    assert not f("plugins/steer/templates/spec/feature-intent.md")
    assert not f("scripts/check_docs_impact.py")


# --- gate behaviour against real git repos -------------------------------------


def test_gate_trips_on_doc_bearing_change_without_docs(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "skill change, no docs")
    errors: list[str] = []
    check_docs_impact.check_impact("main", errors)
    assert len(errors) == 1
    assert "no docs/ file was updated" in errors[0]


def test_gate_cleared_by_any_docs_change(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    (git_repo / "docs/index.md").write_text("# updated docs\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "skill + docs change")
    errors: list[str] = []
    check_docs_impact.check_impact("main", errors)
    assert errors == []


def test_gate_silent_on_non_doc_bearing_change(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "README.md").write_text("readme\n", encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "non-doc-bearing change")
    errors: list[str] = []
    check_docs_impact.check_impact("main", errors)
    assert errors == []


def test_gate_two_dot_fallback_without_merge_base(git_repo: Path):
    _git(git_repo, "checkout", "-q", "--orphan", "detached-history")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("orphan\n", encoding="utf-8")
    _git(git_repo, "add", "-A")
    _git(git_repo, "commit", "-qm", "orphan")
    changed = check_docs_impact._changed_files("main")
    assert changed is not None
    assert "plugins/steer/skills/demo/SKILL.md" in changed


def test_gate_fails_open_on_bad_base(git_repo: Path, capsys):
    """Post-#340: a missing base ref skips the gate with a note instead of
    fail-closing (mirrors check_changelog.py's semantics)."""
    errors: list[str] = []
    check_docs_impact.check_impact("no-such-ref", errors)
    assert errors == []
    assert "skipping docs-impact gate" in capsys.readouterr().out


def test_main_exit_codes(git_repo: Path):
    _git(git_repo, "checkout", "-q", "-b", "feat/x")
    (git_repo / "plugins/steer/skills/demo/SKILL.md").write_text("changed\n", encoding="utf-8")
    _git(git_repo, "commit", "-qam", "skill change")
    assert check_docs_impact.main(["--base", "main"]) == 1
    assert check_docs_impact.main([]) == 0  # no --base -> no gate
