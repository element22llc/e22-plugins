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

Cost/runaway control: ``--max-budget-usd`` (API-billing only; this CLI has no
``--max-turns``) plus a hard ``subprocess`` wall-clock ``timeout``.

Running locally on a subscription seat (no API charge)::

    claude /login            # once, if not already logged in
    unset ANTHROPIC_API_KEY  # else Claude Code bills the API, not the seat
    STEER_E2E_LOCAL=1 mise run e2e

In CI the suite authenticates via the ``ANTHROPIC_API_KEY`` secret instead.
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

# Per-run dollar ceiling and per-scenario wall-clock cap. The timeout is the real
# fail-fast guard: on a hang it kills the run in minutes instead of letting the
# job burn to its ceiling. It must clear the *heaviest* scenario, not the median:
# `init` on a greenfield repo installs the full scaffold, instantiates the whole
# spec spine, writes the first ADR, and runs a real `mise install` + cross-platform
# `mise lock` — measured at 40+ turns / ~$5 on Opus, several minutes of wall-clock
# that rides close to the old 8-min cap and intermittently blew past it. 12 min
# gives that scenario genuine headroom while still failing a true hang fast.
# Override via env in CI if needed.
DEFAULT_BUDGET_USD = os.environ.get("STEER_E2E_BUDGET_USD", "2.00")
DEFAULT_TIMEOUT_S = int(os.environ.get("STEER_E2E_TIMEOUT", "720"))

# Default to the account model (Opus on this org) — it converges in the fewest turns
# and stays bounded. A cheaper model is NOT cheaper here: Sonnet/Haiku take many more turns
# on these long, instruction-dense skills, and because --max-budget-usd is a fixed
# *dollar* cap, a ~5x-cheaper model buys ~5x more runtime before the cap bites — so
# the run balloons to 15+ min and may not converge (measured: a Sonnet dispatch hung
# past 15 min and was cancelled). Set STEER_E2E_MODEL to experiment; "" = account default.
DEFAULT_MODEL = os.environ.get("STEER_E2E_MODEL", "")


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
    model: str | None = None


def claude_available() -> bool:
    """The ``claude`` CLI is on PATH."""
    return shutil.which("claude") is not None


def have_credentials() -> bool:
    """Whether a headless run can authenticate.

    - ``ANTHROPIC_API_KEY`` — API billing (what CI uses).
    - ``CLAUDE_CODE_OAUTH_TOKEN`` — a long-lived token (e.g. ``claude setup-token``).
    - ``STEER_E2E_LOCAL=1`` — trust an interactive ``claude`` login on this machine,
      so a logged-in dev can run the suite on their subscription **seat** without
      any API key. A subscription login sets no env var, so this opt-in is how the
      gate knows to run. To bill the seat (not the API), do NOT set
      ``ANTHROPIC_API_KEY`` in that shell — Claude Code prefers the key when present.
    """
    return bool(
        os.environ.get("ANTHROPIC_API_KEY")
        or os.environ.get("CLAUDE_CODE_OAUTH_TOKEN")
        or os.environ.get("STEER_E2E_LOCAL")
    )


def summarize_run(label: str, run: SkillRun) -> None:
    """Surface a run's turns/cost. Prints (visible locally via ``pytest -rP``)
    and, in CI, appends a line to the GitHub step summary so spend is recorded
    on green runs too (pytest swallows stdout when a test passes)."""
    print(f"\n[e2e] {label}: model={run.model} turns={run.num_turns} cost_usd={run.cost_usd}")
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(
                f"- `{label}` — model: `{run.model}`, turns: {run.num_turns}, "
                f"cost: ${run.cost_usd}\n"
            )


def run_skill(
    repo: Path,
    prompt: str,
    *,
    budget_usd: str | None = None,
    timeout_s: int | None = None,
    plugin_dir: Path = PLUGIN_DIR,
    model: str | None = None,
) -> SkillRun:
    """Run ``claude -p <prompt>`` inside ``repo`` with the local plugin loaded,
    permissions bypassed (ephemeral sandbox), and JSON output. Returns the
    parsed result; never raises on a non-zero exit — the caller asserts on
    ``is_error`` so it can surface ``stderr``.

    ``model`` defaults to ``DEFAULT_MODEL`` (account default = Opus here,
    env-overridable). Pass an empty string to omit ``--model``."""
    chosen_model = DEFAULT_MODEL if model is None else model
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
    ]
    # --max-budget-usd is an API-dollar cap; meaningful only under API-key billing.
    # On a subscription seat there is no per-call dollar cost, so skip it (and rely
    # on the wall-clock timeout) to avoid a no-op or a rejected flag.
    if os.environ.get("ANTHROPIC_API_KEY"):
        cmd += ["--max-budget-usd", str(budget_usd or DEFAULT_BUDGET_USD)]
    if chosen_model:
        cmd += ["--model", chosen_model]
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
        model=chosen_model or "account-default",
    )
