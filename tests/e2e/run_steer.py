"""Thin subprocess wrapper around a headless ``claude -p`` run.

Drives the working-tree ``steer`` plugin against a throwaway repo and parses the
``--output-format json`` result. Zero extra deps: it shells out to the pinned
``claude`` CLI that CI already installs (``STEER_CLAUDE_CODE_VERSION``).

Plugin-load mechanism: ``--plugin-dir <repo>/plugins/steer`` — a confirmed,
purpose-built CLI flag that loads the local checkout's plugin for the single
run, so the test exercises the *working-tree* version with no marketplace
download or auth. (Fallback if that ever regresses: write the temp repo a
``.claude/settings.json`` with ``extraKnownMarketplaces`` → ``{source: local,
path: <repo root>}`` + ``enabledPlugins: {"steer@e22-plugins": true}``.)

Cost/runaway control: ``--max-budget-usd`` (this CLI has no ``--max-turns``)
plus a hard ``subprocess`` wall-clock ``timeout``. Both are env-overridable.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

# tests/e2e/run_steer.py -> parents[2] is the repo (or worktree) root.
REPO_ROOT = Path(__file__).resolve().parents[2]
PLUGIN_DIR = REPO_ROOT / "plugins" / "steer"

# Per-run dollar ceiling and wall-clock cap. Tune from the first real run's
# reported cost (see test output). Override via env in CI if needed.
DEFAULT_BUDGET_USD = os.environ.get("STEER_E2E_BUDGET_USD", "2.00")
DEFAULT_TIMEOUT_S = int(os.environ.get("STEER_E2E_TIMEOUT", "1200"))


@dataclass
class SkillRun:
    returncode: int
    result: str
    is_error: bool
    cost_usd: float | None
    num_turns: int | None
    raw: dict | None
    stdout: str
    stderr: str


def claude_available() -> bool:
    """The ``claude`` CLI is on PATH."""
    return shutil.which("claude") is not None


def have_credentials() -> bool:
    """Some credential the headless run can authenticate with is present."""
    return bool(os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("CLAUDE_CODE_OAUTH_TOKEN"))


def run_skill(
    repo: Path,
    prompt: str,
    *,
    budget_usd: str | None = None,
    timeout_s: int | None = None,
    plugin_dir: Path = PLUGIN_DIR,
) -> SkillRun:
    """Run ``claude -p <prompt>`` inside ``repo`` with the local plugin loaded,
    permissions bypassed (ephemeral sandbox), and JSON output. Returns the
    parsed result; never raises on a non-zero exit — the caller asserts on
    ``is_error`` so it can surface ``stderr``."""
    cmd = [
        "claude",
        "-p",
        prompt,
        "--plugin-dir",
        str(plugin_dir),
        "--permission-mode",
        "bypassPermissions",
        "--output-format",
        "json",
        "--max-budget-usd",
        str(budget_usd or DEFAULT_BUDGET_USD),
    ]
    proc = subprocess.run(
        cmd,
        cwd=str(repo),
        capture_output=True,
        text=True,
        timeout=timeout_s or DEFAULT_TIMEOUT_S,
    )

    raw: dict | None = None
    result_text = proc.stdout
    is_error = proc.returncode != 0
    cost: float | None = None
    num_turns: int | None = None
    try:
        raw = json.loads(proc.stdout)
        if isinstance(raw, dict):
            result_text = raw.get("result", proc.stdout)
            is_error = bool(raw.get("is_error", is_error))
            cost = raw.get("total_cost_usd")
            num_turns = raw.get("num_turns")
    except json.JSONDecodeError:
        pass  # leave the raw stdout as the result; is_error reflects the exit code

    return SkillRun(
        returncode=proc.returncode,
        result=result_text,
        is_error=is_error,
        cost_usd=cost,
        num_turns=num_turns,
        raw=raw,
        stdout=proc.stdout,
        stderr=proc.stderr,
    )
