"""Run shell commands steer's skills tell the agent to run, under sh and zsh.

The agent runs them in the user's shell, often zsh, whose default nomatch aborts
a command when an unquoted glob matches nothing (#1034). check_standards scans
fenced blocks for that; these commands sit in prose or need their output checked.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_standards  # noqa: E402

SKILLS = Path(__file__).resolve().parent.parent / "plugins/steer/skills"
SUBCOMMANDS = (SKILLS / "work/modes/subcommands.md").read_text(encoding="utf-8")
QUESTIONS = (SKILLS / "questions/SKILL.md").read_text(encoding="utf-8")

SHELLS = [
    "sh",
    pytest.param(
        "zsh", marks=pytest.mark.skipif(shutil.which("zsh") is None, reason="zsh not installed")
    ),
]


def _span(text: str, prefix: str) -> str:
    found = re.findall(r"`(" + re.escape(prefix) + r"[^`]*)`", text)
    assert len(found) == 1, f"expected one span starting {prefix!r}"
    return found[0]


LEARNINGS = _span(SUBCOMMANDS, "if [ -d spec/learnings ]").replace("<terms>", "auth|login")
TRANSCRIPT = _span(SUBCOMMANDS, 'find "${CLAUDE_CONFIG_DIR').replace("<id>", "abc")
GATHER = re.search(r"```sh\n(.*?'\^### Q-'.*?)```", QUESTIONS, re.S).group(1)


def _run(shell: str, cmd: str, cwd: Path, env: dict[str, str] | None = None):
    args = [shell, "-f", "-c", cmd] if shell == "zsh" else [shell, "-c", cmd]
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, env=env)


@pytest.mark.parametrize("cmd", [LEARNINGS, TRANSCRIPT])
def test_prose_commands_carry_no_unquoted_glob(cmd):
    assert check_standards.unquoted_globs(cmd) == []


@pytest.mark.parametrize("shell", SHELLS)
def test_learnings_grep_is_a_no_op_without_the_directory(tmp_path, shell):
    out = _run(shell, LEARNINGS, tmp_path)
    assert (out.returncode, out.stdout, out.stderr) == (0, "", "")


@pytest.mark.parametrize("shell", SHELLS)
def test_learnings_grep_lists_matching_markdown(tmp_path, shell):
    learnings = tmp_path / "spec/learnings"
    learnings.mkdir(parents=True)
    (learnings / "auth-cookie.md").write_text("---\narea: apps/web/auth\n---\n", encoding="utf-8")
    (learnings / "reports.md").write_text("---\narea: packages/reports\n---\n", encoding="utf-8")
    (learnings / "notes.txt").write_text("area: auth\n", encoding="utf-8")
    out = _run(shell, LEARNINGS, tmp_path)
    assert (out.stdout.split(), out.stderr) == (["spec/learnings/auth-cookie.md"], "")


@pytest.mark.parametrize("shell", SHELLS)
def test_learnings_grep_on_an_empty_directory(tmp_path, shell):
    (tmp_path / "spec/learnings").mkdir(parents=True)
    out = _run(shell, LEARNINGS, tmp_path)
    assert (out.stdout, out.stderr) == ("", "")


@pytest.mark.parametrize("shell", SHELLS)
def test_transcript_lookup(tmp_path, shell):
    env = {**os.environ, "CLAUDE_CONFIG_DIR": str(tmp_path)}
    (tmp_path / "projects/repo").mkdir(parents=True)
    out = _run(shell, TRANSCRIPT, tmp_path, env)
    assert (out.stdout, out.stderr) == ("", "")
    (tmp_path / "projects/repo/abc.jsonl").write_text("{}\n", encoding="utf-8")
    out = _run(shell, TRANSCRIPT, tmp_path, env)
    assert out.stdout.strip() == f"{tmp_path}/projects/repo/abc.jsonl"


@pytest.mark.parametrize("shell", SHELLS)
def test_transcript_lookup_defaults_to_home_claude(tmp_path, shell):
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_CONFIG_DIR"}
    env["HOME"] = str(tmp_path)
    (tmp_path / ".claude/projects/repo").mkdir(parents=True)
    (tmp_path / ".claude/projects/repo/abc.jsonl").write_text("{}\n", encoding="utf-8")
    out = _run(shell, TRANSCRIPT, tmp_path, env)
    assert out.stdout.strip() == f"{tmp_path}/.claude/projects/repo/abc.jsonl"


Q_BLOCK = "## Open questions\n\n### Q-001 - {}\n- status: open\n"


@pytest.mark.parametrize("shell", SHELLS)
def test_gather_keeps_vision_questions_without_features(tmp_path, shell):
    (tmp_path / "spec").mkdir()
    (tmp_path / "spec/vision.md").write_text(Q_BLOCK.format("pricing"), encoding="utf-8")
    out = _run(shell, GATHER, tmp_path)
    assert "spec/vision.md:3:### Q-001 - pricing" in out.stdout
    assert out.stderr == ""


@pytest.mark.parametrize("shell", SHELLS)
def test_gather_reads_each_feature_intent(tmp_path, shell):
    feature = tmp_path / "spec/features/login"
    feature.mkdir(parents=True)
    (feature / "intent.md").write_text(Q_BLOCK.format("sso"), encoding="utf-8")
    (feature / "contract.md").write_text(Q_BLOCK.format("not-intent"), encoding="utf-8")
    out = _run(shell, GATHER, tmp_path)
    assert "spec/features/login/intent.md:3:### Q-001 - sso" in out.stdout
    assert "not-intent" not in out.stdout
