#!/usr/bin/env python3
"""Meta-gate: every Copilot generator/gate must be wired into the dev loop.

The Copilot surface stays maintainable only if every artifact is *generated* from
a Claude source and *gated* for drift — never hand-maintained in parallel. This
check enforces the wiring half of that invariant so a new
``scripts/gen_copilot_*.py`` or ``scripts/check_copilot_*.py`` can't be added and
then silently left out of the build:

* every ``scripts/gen_*.py`` for a non-Claude surface is invoked by the
  ``gen:copilot`` mise task (so one command regenerates the whole surface); and
* every matching ``scripts/check_*.py`` is invoked by the ``plugin-check`` mise
  task (so every drift gate runs in ``mise run check`` / CI).

The globs cover two families: ``*_copilot_*`` (artifacts only GitHub Copilot
reads — instructions, custom agents, the VS Code MCP mirror, the hook manifest)
and ``*_agent_*`` (the cross-tool ``.agents/skills`` tree that Copilot, Cursor,
Gemini CLI and Codex all read). Both are generated-from-Claude-source, so both
need the same wiring guarantee.

It does not re-verify artifact contents — the individual ``check_copilot_*`` gates
do that. It guards against the failure mode of adding a mirror with a gate but no
generator (or a generator no one runs), which is how the surface drifted back to
hand-maintenance before.

Run from the repo root::

    uv run python scripts/check_copilot_symmetry.py

Exit status is 0 when everything is wired, 1 otherwise.
"""

from __future__ import annotations

import sys
import tomllib
from pathlib import Path

SCRIPTS_DIR = Path("scripts")
MISE_TOML = Path("mise.toml")

# Script-name suffixes that mark a non-Claude surface generator/gate pair.
SURFACE_GLOBS = ("copilot_*.py", "agent_*.py")


def _task_run(data: dict, task: str) -> list[str]:
    """The ``run`` commands of a mise task, as a list (string tasks are wrapped)."""
    run = data.get("tasks", {}).get(task, {}).get("run", [])
    if isinstance(run, str):
        return [run]
    return [str(r) for r in run]


def main() -> int:
    if not MISE_TOML.is_file():
        print(f"check_copilot_symmetry: {MISE_TOML} not found", file=sys.stderr)
        return 1
    if not SCRIPTS_DIR.is_dir():
        print(f"check_copilot_symmetry: {SCRIPTS_DIR} not found", file=sys.stderr)
        return 1

    data = tomllib.loads(MISE_TOML.read_text(encoding="utf-8"))
    gen_cmds = " \n".join(_task_run(data, "gen:copilot"))
    check_cmds = " \n".join(_task_run(data, "plugin-check"))

    problems: list[str] = []
    gen_scripts = sorted(
        {p for pattern in SURFACE_GLOBS for p in SCRIPTS_DIR.glob(f"gen_{pattern}")}
    )
    check_scripts = sorted(
        {p for pattern in SURFACE_GLOBS for p in SCRIPTS_DIR.glob(f"check_{pattern}")}
    )
    for script in gen_scripts:
        if script.name not in gen_cmds:
            problems.append(f"{script.name} is not invoked by the 'gen:copilot' mise task")
    for script in check_scripts:
        if script.name == "check_copilot_symmetry.py":
            continue  # this file — checked by being in plugin-check to run at all
        if script.name not in check_cmds:
            problems.append(f"{script.name} is not invoked by the 'plugin-check' mise task")

    if problems:
        print(
            "check_copilot_symmetry: surface generators/gates not fully wired:",
            file=sys.stderr,
        )
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print("check_copilot_symmetry: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
