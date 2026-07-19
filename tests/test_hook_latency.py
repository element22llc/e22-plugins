"""Latency budget for the steer SessionStart hook chain.

Every hook in hooks.json's SessionStart matchers runs, sequentially, at every
session start in every managed repo — their combined wall time is startup
latency every user pays. This test runs the full startup chain against a
minimal managed-repo fixture and fails when it exceeds the budget.

The budget is deliberately generous (baseline ~200 ms on a dev container vs a
2 s default ceiling): it is not a benchmark, it is a tripwire for a hook that
grows a network call, a repo-wide scan, or an interpreter spawn. Override via
STEER_HOOK_LATENCY_BUDGET_MS for unusually slow or fast environments.

Kept in the pytest tier (not hooks/tests/run.sh) because POSIX sh has no
portable sub-second clock — `date +%s%N` is GNU-only. The sh suite remains the
behavioral gate; this file only budgets wall time.
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
# Every SessionStart hook registered in hooks.json for the `startup` source,
# in registration order. test_chain_matches_hooks_json pins this list to the
# manifest so a newly registered hook cannot dodge the budget.
STARTUP_CHAIN = [
    "inject-standards.sh",
    "check-template-drift.sh",
    "check-open-questions.sh",
    "check-unmanaged-repo.sh",
    "surface-faults.sh",
    "check-graduation.sh",
    "orient-session.sh",
]


def _budget_ms() -> int:
    return int(os.environ.get("STEER_HOOK_LATENCY_BUDGET_MS", DEFAULT_BUDGET_MS))


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


def test_chain_matches_hooks_json():
    """The budgeted chain must cover every registered SessionStart hook."""
    manifest = json.loads((HOOKS / "hooks.json").read_text(encoding="utf-8"))
    registered = []
    for matcher_block in manifest["hooks"]["SessionStart"]:
        for hook in matcher_block["hooks"]:
            registered.append(Path(hook["command"].split('"')[1]).name)
    assert registered == STARTUP_CHAIN, (
        "hooks.json SessionStart chain changed — update STARTUP_CHAIN so the "
        "latency budget keeps covering every registered hook."
    )


@pytest.mark.skipif(shutil.which("sh") is None, reason="POSIX sh unavailable")
def test_session_start_chain_within_budget(tmp_path: Path):
    repo = _managed_repo(tmp_path)
    stdin = _session_stdin(repo)
    env = dict(os.environ, CLAUDE_PLUGIN_ROOT=str(PLUGIN.resolve()))

    timings = []
    start = time.monotonic()
    for name in STARTUP_CHAIN:
        t0 = time.monotonic()
        proc = subprocess.run(
            ["sh", str(HOOKS / name)],
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
    budget = _budget_ms()
    assert total_ms <= budget, (
        f"SessionStart chain took {total_ms:.0f} ms, over the {budget} ms budget "
        f"— a hook grew expensive work every session pays for. Breakdown: {breakdown}"
    )
