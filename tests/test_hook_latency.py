"""Latency budgets for the steer hooks that run on the session's hot paths.

SessionStart: every hook in hooks.json's SessionStart matchers runs at every
session start in every managed repo - their combined wall time is startup
latency every user pays. The chain runs against a minimal managed-repo fixture
and fails when it exceeds its budget.

PreToolUse / PostToolUse: these run on every matching tool call - a long
session makes hundreds of Bash calls and writes - so each command's
non-matching fast path is budgeted on its own. It is timed as the best of a few
runs, so a loaded machine slows the median, not the verdict.

The budgets are deliberately generous: not a benchmark, a tripwire for a hook
that grows a network call, a repo-wide scan, or an interpreter spawn. Override
via STEER_HOOK_LATENCY_BUDGET_MS (SessionStart chain) and
STEER_HOOK_CALL_BUDGET_MS (each per-call hook) for unusually slow or fast
environments.

Kept in the pytest tier (not hooks/tests/run.sh) because POSIX sh has no
portable sub-second clock - `date +%s%N` is GNU-only. The sh suite remains the
behavioral gate, and it counts the fast path's jq spawns deterministically
(cases/lib-json.sh); this file only budgets wall time.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest
from conftest import REPO_ROOT

PLUGIN = REPO_ROOT / "plugins" / "steer"
HOOKS = PLUGIN / "hooks"

DEFAULT_BUDGET_MS = 2000
DEFAULT_CALL_BUDGET_MS = 1000
CALL_RUNS = 5
# Every SessionStart hook SCRIPT registered in hooks.json for the `startup`
# source, in first-registration order. test_chain_matches_hooks_json pins this
# list to the manifest so a newly registered hook cannot dodge the budget.
# session-checks.sh is the consolidated orchestrator - timing it times every
# check it runs. inject-standards.sh is registered several times (once per part
# of the ruleset, `<k> <N>`); the budget runs every registered command, so the
# parts are paid for as the runtime pays for them - sequentially here, which is
# the pessimistic case (the runtime starts them in parallel).
STARTUP_CHAIN = [
    "inject-standards.sh",
    "session-checks.sh",
    "orient-session.sh",
]
# The tool whose non-matching call times each per-call hook's fast path.
# test_per_call_hooks_match_hooks_json pins the keys to the manifest.
PER_CALL_TOOL = {
    "check-version-pins.sh": "Write",
    "check-write-nudges.sh": "Write",
    "check-bash-actions.sh": "Bash",
    "format-on-write.sh": "Write",
    "check-comment-density.sh": "Write",
}
PER_CALL_EVENTS = ("PreToolUse", "PostToolUse")


def _registered_commands(event: str) -> list[tuple[str, list[str]]]:
    """(script name, args) for every `event` command in hooks.json, in order."""
    manifest = json.loads((HOOKS / "hooks.json").read_text(encoding="utf-8"))
    commands: list[tuple[str, list[str]]] = []
    for matcher_block in manifest["hooks"][event]:
        for hook in matcher_block["hooks"]:
            _, path, rest = hook["command"].split('"', 2)
            commands.append((Path(path).name, rest.split()))
    return commands


def _budget_ms() -> int:
    return int(os.environ.get("STEER_HOOK_LATENCY_BUDGET_MS", DEFAULT_BUDGET_MS))


def _call_budget_ms() -> int:
    return int(os.environ.get("STEER_HOOK_CALL_BUDGET_MS", DEFAULT_CALL_BUDGET_MS))


def _env() -> dict[str, str]:
    return dict(os.environ, CLAUDE_PLUGIN_ROOT=str(PLUGIN.resolve()))


def _managed_repo(tmp_path: Path) -> Path:
    """Minimal managed repo (version-stamped spec spine) so hooks take their
    normal steady-state path rather than an early unmanaged-repo exit."""
    repo = tmp_path / "repo"
    (repo / "spec").mkdir(parents=True)
    (repo / ".git").write_text("", encoding="utf-8")
    (repo / "spec" / ".version").write_text("1.0.0\n", encoding="utf-8")
    for name in ("vision.md", "users.md", "glossary.md", "tracker.md", "HISTORY.md"):
        (repo / "spec" / name).write_text("x\n", encoding="utf-8")
    return repo


def _session_stdin(repo: Path) -> str:
    return json.dumps(
        {"session_id": "latency-test", "cwd": str(repo), "hook_event_name": "SessionStart"}
    )


def _tool_stdin(repo: Path, event: str, tool: str) -> str:
    """A call no check acts on: `ls` for Bash, a plain-text file for writes."""
    if tool == "Bash":
        tool_input = {"command": "ls -la", "description": "List files"}
    else:
        target = repo / "notes.txt"
        target.write_text("hello\n", encoding="utf-8")
        tool_input = {"file_path": str(target), "content": "hello\n"}
    return json.dumps(
        {
            "session_id": "latency-test",
            "cwd": str(repo),
            "hook_event_name": event,
            "tool_name": tool,
            "tool_input": tool_input,
        }
    )


def test_chain_matches_hooks_json():
    """The budgeted chain must cover every registered SessionStart hook."""
    registered = list(dict.fromkeys(name for name, _ in _registered_commands("SessionStart")))
    assert registered == STARTUP_CHAIN, (
        "hooks.json SessionStart chain changed - update STARTUP_CHAIN so the "
        "latency budget keeps covering every registered hook."
    )


@pytest.mark.skipif(shutil.which("sh") is None, reason="POSIX sh unavailable")
def test_session_start_chain_within_budget(tmp_path: Path):
    repo = _managed_repo(tmp_path)
    stdin = _session_stdin(repo)
    env = _env()

    timings = []
    start = time.monotonic()
    for name, args in _registered_commands("SessionStart"):
        t0 = time.monotonic()
        proc = subprocess.run(
            ["sh", str(HOOKS / name), *args],
            input=stdin,
            capture_output=True,
            text=True,
            env=env,
            cwd=str(repo),
            timeout=30,
        )
        timings.append((name, (time.monotonic() - t0) * 1000, proc.returncode))
    total_ms = (time.monotonic() - start) * 1000

    breakdown = ", ".join(f"{n}={ms:.0f}ms(rc{rc})" for n, ms, rc in timings)
    assert all(rc == 0 for _, _, rc in timings), breakdown
    budget = _budget_ms()
    assert total_ms <= budget, (
        f"SessionStart chain took {total_ms:.0f} ms, over the {budget} ms budget "
        f"- a hook grew expensive work every session pays for. Breakdown: {breakdown}"
    )


def _per_call_commands() -> list[tuple[str, str, list[str]]]:
    return [(event, *cmd) for event in PER_CALL_EVENTS for cmd in _registered_commands(event)]


def test_per_call_hooks_match_hooks_json():
    """Every registered PreToolUse / PostToolUse script has a fast-path payload."""
    registered = {name for _, name, _ in _per_call_commands()}
    assert registered == set(PER_CALL_TOOL), (
        "hooks.json PreToolUse/PostToolUse hooks changed - update PER_CALL_TOOL so "
        "the per-call latency budget keeps covering every registered hook."
    )


@pytest.mark.skipif(shutil.which("sh") is None, reason="POSIX sh unavailable")
@pytest.mark.parametrize(
    ("event", "name", "args"),
    _per_call_commands(),
    ids=[f"{event}:{name}" for event, name, _ in _per_call_commands()],
)
def test_per_call_fast_path_within_budget(tmp_path: Path, event: str, name: str, args: list[str]):
    repo = _managed_repo(tmp_path)
    stdin = _tool_stdin(repo, event, PER_CALL_TOOL[name])
    env = _env()

    timings = []
    for _ in range(CALL_RUNS):
        t0 = time.monotonic()
        proc = subprocess.run(
            ["sh", str(HOOKS / name), *args],
            input=stdin,
            capture_output=True,
            text=True,
            env=env,
            cwd=str(repo),
            timeout=30,
        )
        timings.append((time.monotonic() - t0) * 1000)
        assert proc.returncode == 0 and not proc.stdout, (
            f"{name} acted on a call it should ignore (rc {proc.returncode}): {proc.stdout}"
        )

    best_ms = min(timings)
    budget = _call_budget_ms()
    assert best_ms <= budget, (
        f"{event} {name} fast path took {best_ms:.0f} ms at best of {CALL_RUNS}, over "
        f"the {budget} ms per-call budget - every matching tool call pays this. "
        f"Runs: {', '.join(f'{ms:.0f}' for ms in timings)} ms"
    )


# Large Bash commands the merge gate must still deny. A PreToolUse hook that
# outlasts its timeout lets the command run, so each must finish well inside it.
LARGE_MERGES = {
    "long-line": "echo " + "word " * 80000 + "; gh pr merge 5",
    "many-lines": "".join(f"echo hi {i}\n" for i in range(30000)) + "gh pr merge 5",
    "long-quote": 'echo "' + "word " * 80000 + '"; gh pr merge 5',
    "many-heredocs": "cat <<EOF\nx\nEOF\n" * 25000 + "gh pr merge 5",
    "over-the-cap": "echo " + "word " * 120000 + '; sh -c "gh pr merge 5"',
}


def _hook_timeout_s(script: str) -> int:
    manifest = json.loads((HOOKS / "hooks.json").read_text(encoding="utf-8"))
    for blocks in manifest["hooks"].values():
        for block in blocks:
            for hook in block["hooks"]:
                if f"/{script}" in hook["command"]:
                    return hook["timeout"]
    raise AssertionError(f"{script} is not registered in hooks.json")


@pytest.mark.skipif(shutil.which("sh") is None, reason="POSIX sh unavailable")
@pytest.mark.parametrize("shape", list(LARGE_MERGES))
def test_merge_gate_denies_large_command_inside_timeout(tmp_path: Path, shape: str):
    stdin = json.dumps(
        {
            "session_id": "latency-test",
            "cwd": str(tmp_path),
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {"command": LARGE_MERGES[shape]},
        }
    )
    limit_s = _hook_timeout_s("check-bash-actions.sh") / 2
    t0 = time.monotonic()
    proc = subprocess.run(
        ["sh", str(HOOKS / "check-bash-actions.sh")],
        input=stdin,
        capture_output=True,
        text=True,
        env=_env(),
        cwd=str(tmp_path),
        timeout=60,
    )
    elapsed_s = time.monotonic() - t0
    assert '"permissionDecision":"deny"' in proc.stdout, (
        f"{shape} ({len(LARGE_MERGES[shape])} chars): merge not denied: {proc.stdout[:200]}"
    )
    assert elapsed_s <= limit_s, (
        f"{shape} ({len(LARGE_MERGES[shape])} chars) took {elapsed_s:.1f} s, over half the "
        f"hook's {limit_s * 2:.0f} s timeout - past the timeout the command runs ungated."
    )
