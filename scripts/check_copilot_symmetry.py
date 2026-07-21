#!/usr/bin/env python3
"""Meta-gate: every Copilot generator/gate must be wired into the dev loop.

The Copilot surface stays maintainable only if every artifact is *generated* from
a Claude source and *gated* for drift — never hand-maintained in parallel. This
check enforces the wiring half of that invariant so a new
``scripts/gen_copilot_*.py`` or ``scripts/check_copilot_*.py`` can't be added and
then silently left out of the build:

* every ``scripts/gen_copilot_*.py`` is invoked by the ``gen:copilot`` mise task
  (so ``mise run gen:copilot`` regenerates the whole Copilot surface); and
* every ``scripts/check_copilot_*.py`` is invoked by the ``plugin-check`` mise
  task (so every drift gate runs in ``mise run check`` / CI).

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
    for script in sorted(SCRIPTS_DIR.glob("gen_copilot_*.py")):
        if script.name not in gen_cmds:
            problems.append(f"{script.name} is not invoked by the 'gen:copilot' mise task")
    for script in sorted(SCRIPTS_DIR.glob("check_copilot_*.py")):
        if script.name == "check_copilot_symmetry.py":
            continue  # this file — checked by being in plugin-check to run at all
        if script.name not in check_cmds:
            problems.append(f"{script.name} is not invoked by the 'plugin-check' mise task")

    if problems:
        print("check_copilot_symmetry: Copilot generators/gates not fully wired:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print("check_copilot_symmetry: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
