"""Scaffold mise tasks must parse the same under sh and cmd.exe (#671).

mise runs an inline ``run`` through cmd.exe on Windows, so POSIX-only syntax in
one breaks every Windows contributor: ``${VAR:?msg}`` is passed through literally,
a trailing ``\\`` is not a line continuation, and single quotes are not quoting.
Anything that needs those belongs in a script the task invokes.
"""

from __future__ import annotations

import re
import tomllib

import pytest
from conftest import REPO_ROOT

SCAFFOLD = REPO_ROOT / "plugins" / "steer" / "templates" / "scaffold"
_POSIX_ONLY = re.compile(r"\$\{|\$[A-Za-z_]|\\\n|'|\n")


def _runs() -> list[tuple[str, str, str]]:
    out = []
    for path in sorted(SCAFFOLD.rglob("mise.toml")):
        tasks = tomllib.loads(path.read_text(encoding="utf-8")).get("tasks", {})
        for name, task in tasks.items():
            run = task.get("run")
            for line in [run] if isinstance(run, str) else run or []:
                out.append((str(path.relative_to(SCAFFOLD)), name, line.strip()))
    return out


@pytest.mark.parametrize(("path", "task", "run"), _runs())
def test_inline_run_is_cmd_safe(path: str, task: str, run: str) -> None:
    assert not _POSIX_ONLY.search(run), f"{path} [tasks.{task!r}] uses POSIX-only syntax: {run!r}"


def test_changelog_new_delegates_to_its_script() -> None:
    tasks = tomllib.loads((SCAFFOLD / "mise.toml").read_text(encoding="utf-8"))["tasks"]
    assert tasks["changelog:new"]["run"] == "node scripts/changelog-new.mjs"
    assert (SCAFFOLD / "scripts" / "changelog-new.mjs").is_file()
