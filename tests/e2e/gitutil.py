"""Git helpers for idempotency / re-run-safety assertions.

The core idempotency primitive: commit the state a skill produced, run the skill
again, then assert NOTHING changed — no working-tree diff and no new commit. Any
clobber, duplicate managed block, or stray write shows up as a dirty tree or a
moved HEAD, so one assertion (`assert_unchanged`) covers the whole bug class.
"""

from __future__ import annotations

import subprocess
from pathlib import Path


def git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=str(repo), check=True, capture_output=True, text=True
    ).stdout


def commit_all(repo: Path, message: str) -> str:
    """Stage everything (incl. untracked) and commit; return the new HEAD sha."""
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", message)
    return head(repo)


def head(repo: Path) -> str:
    return git(repo, "rev-parse", "HEAD").strip()


def porcelain(repo: Path) -> str:
    """Working-tree status (empty string == clean, incl. no untracked files)."""
    return git(repo, "status", "--porcelain").strip()


def changed_paths(repo: Path) -> list[str]:
    """Repo-relative paths of every working-tree change (modified + untracked)."""
    paths = []
    for line in porcelain(repo).splitlines():
        # porcelain v1: 2 status cols then the path. Strip the 2 status chars and
        # any separating space(s) rather than slicing a fixed offset.
        p = line[2:].lstrip().strip('"')
        if " -> " in p:  # rename: keep the destination
            p = p.split(" -> ", 1)[1]
        paths.append(p)
    return paths


def assert_changes_confined_to(repo: Path, *prefixes: str) -> None:
    """Every working-tree change sits under one of ``prefixes`` (e.g. ``spec/``).
    Catches a skill that wrote outside its allowed area — e.g. spec, which must
    never touch code."""
    stray = [p for p in changed_paths(repo) if not p.startswith(prefixes)]
    assert not stray, f"writes escaped {prefixes}: {stray}"


def assert_unchanged(repo: Path, since_head: str) -> None:
    """The repo is byte-for-byte as it was at ``since_head``: clean working tree
    and HEAD not moved. This is the idempotency assertion — a re-run that
    clobbers, duplicates, or commits anything will trip one of the two checks."""
    dirty = porcelain(repo)
    assert not dirty, f"re-run mutated the working tree:\n{dirty}"
    now = head(repo)
    assert now == since_head, f"re-run created a commit: HEAD {since_head[:8]} -> {now[:8]}"
