"""Failure diagnostics for E2E scenarios.

When a structural assertion fails, the message alone ("expected file missing:
spec/vision.md") doesn't say what the skill actually produced or why. Wrapping a
scenario's assertions in ``explain_on_failure`` dumps the produced repo's file
tree plus the skill's own result/stderr on failure, so a red run is debuggable
without re-running the (slow, paid) skill.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .run_steer import SkillRun


def _tree(repo: Path, cap: int = 100) -> str:
    files = [
        str(p.relative_to(repo))
        for p in sorted(repo.rglob("*"))
        if p.is_file() and ".git" not in p.parts
    ]
    shown = "\n".join(files[:cap]) or "(no files)"
    if len(files) > cap:
        shown += f"\n... (+{len(files) - cap} more)"
    return shown


@contextmanager
def explain_on_failure(repo: Path, run: SkillRun | None = None) -> Iterator[None]:
    """On an assertion failure inside the block, print the produced repo tree and
    the skill's output, then re-raise so pytest still reports the failure."""
    try:
        yield
    except AssertionError:
        blocks = [f"\n--- e2e failure diagnostics: {repo} ---", _tree(repo)]
        if run is not None:
            blocks.append(f"\n[skill result]\n{run.result[:3000]}")
            if run.stderr.strip():
                blocks.append(f"\n[skill stderr]\n{run.stderr[:1500]}")
        print("\n".join(blocks))
        raise
