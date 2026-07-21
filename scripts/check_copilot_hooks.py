#!/usr/bin/env python3
"""Parity gate: the Copilot hook manifest must stay wired to real, shared hooks.

steer's gate hooks run on Claude Code from ``plugins/steer/hooks/hooks.json``
(hard ``deny``) and on the Copilot CLI from
``plugins/steer/hooks/copilot-hooks.json`` (soft ``ask``). Copilot deliberately
ports only a **subset** of the hooks (see ``docs/concepts/copilot-support.md`` →
"Gate hooks on Copilot"), so this is *not* a full-equality check like the
generated Copilot artifacts. What it guards is referential integrity plus the
two contracts that keep the Copilot side correct:

* Every hook script the Copilot manifest invokes still **exists** on disk and is
  also wired into ``hooks.json`` — so renaming or dropping a script on the Claude
  side can't leave the Copilot manifest pointing at a dead path (a Copilot hook
  that references a missing script would silently no-op).
* Every Copilot hook invokes the shared script with ``STEER_HOOK_TARGET=copilot``
  — the flag that makes the shared ``.sh`` emit Copilot's ``permissionDecision``
  envelope instead of Claude's.
* Every Copilot hook is **fail-open** (``|| true``) — Copilot's ``preToolUse``
  hooks are fail-*closed*, so an un-guarded error would block the edit; steer
  hardens them to never block on error.

Run from the repo root::

    uv run python scripts/check_copilot_hooks.py

Exit status is 0 when in sync, 1 on drift.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HOOKS_JSON = Path("plugins/steer/hooks/hooks.json")
COPILOT_HOOKS_JSON = Path("plugins/steer/hooks/copilot-hooks.json")
HOOKS_DIR = Path("plugins/steer/hooks")

_SCRIPT_RE = re.compile(r"hooks/([a-z0-9-]+\.sh)")


def _claude_script_names() -> set[str]:
    """Every hook-script basename referenced anywhere in hooks.json."""
    data = json.loads(HOOKS_JSON.read_text(encoding="utf-8"))
    names: set[str] = set()
    for entries in data.get("hooks", {}).values():
        for entry in entries:
            for hook in entry.get("hooks", []):
                names.update(_SCRIPT_RE.findall(hook.get("command", "")))
    return names


def _copilot_hooks() -> list[dict]:
    """Flatten every hook entry in copilot-hooks.json across all events."""
    data = json.loads(COPILOT_HOOKS_JSON.read_text(encoding="utf-8"))
    hooks: list[dict] = []
    for entries in data.get("hooks", {}).values():
        hooks.extend(entries)
    return hooks


def main() -> int:
    for path in (HOOKS_JSON, COPILOT_HOOKS_JSON):
        if not path.is_file():
            print(f"check_copilot_hooks: file not found: {path}", file=sys.stderr)
            return 1

    try:
        claude_scripts = _claude_script_names()
        copilot_hooks = _copilot_hooks()
    except json.JSONDecodeError as exc:
        print(f"check_copilot_hooks: invalid JSON ({exc})", file=sys.stderr)
        return 1

    problems: list[str] = []
    for hook in copilot_hooks:
        cmd = hook.get("bash", "")
        scripts = _SCRIPT_RE.findall(cmd)
        if not scripts:
            problems.append(f"hook entry references no hooks/*.sh script: {cmd!r}")
            continue
        for script in scripts:
            if not (HOOKS_DIR / script).is_file():
                problems.append(f"script '{script}' does not exist under {HOOKS_DIR}/")
            elif script not in claude_scripts:
                problems.append(
                    f"script '{script}' is not wired into {HOOKS_JSON.name} "
                    f"(Copilot hook points at a script the Claude side dropped/renamed)"
                )
            if "STEER_HOOK_TARGET=copilot" not in cmd:
                problems.append(f"hook invoking '{script}' is missing STEER_HOOK_TARGET=copilot")
            if "|| true" not in cmd:
                problems.append(f"hook invoking '{script}' is not fail-open (missing '|| true')")

    if problems:
        print(
            f"check_copilot_hooks: {COPILOT_HOOKS_JSON} has drifted from {HOOKS_JSON}:",
            file=sys.stderr,
        )
        for problem in sorted(set(problems)):
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"check_copilot_hooks: OK ({len(copilot_hooks)} Copilot hook(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
