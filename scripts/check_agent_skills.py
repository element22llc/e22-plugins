#!/usr/bin/env python3
"""Sync gate: the committed ``.agents/skills`` tree must match ``skills/``.

``gen_agent_skills.py`` renders ``plugins/steer/templates/agents/skills/`` from
the authored ``plugins/steer/skills/`` (the single source of truth). That tree is
committed so ``/steer:init`` / ``/steer:adopt`` can install it without running
Python in the consumer repo, which means it goes stale the moment a skill body,
supporting file, or frontmatter field changes on the Claude side.

This check regenerates in-memory and compares path-for-path and byte-for-byte,
failing the build on any drift — the same single-source-of-truth discipline the
Copilot artifacts get. It reports **added, removed and changed** paths separately,
so a renamed or deleted skill is as loud as an edited one.

Run from the repo root::

    uv run python scripts/check_agent_skills.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_agent_skills import OUT_DIR, SKILLS_DIR, build


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f"check_agent_skills: source not found: {SKILLS_DIR}", file=sys.stderr)
        return 1
    if not OUT_DIR.is_dir():
        print(
            f"check_agent_skills: missing {OUT_DIR} — run 'mise run gen:copilot'",
            file=sys.stderr,
        )
        return 1

    expected = build(SKILLS_DIR)
    committed = {p.relative_to(OUT_DIR): p for p in OUT_DIR.rglob("*") if p.is_file()}

    missing = sorted(set(expected) - set(committed))
    extra = sorted(set(committed) - set(expected))
    changed = sorted(
        rel
        for rel in set(expected) & set(committed)
        if committed[rel].read_text(encoding="utf-8") != expected[rel]
    )

    if not (missing or extra or changed):
        print(f"check_agent_skills: OK ({len(expected)} files)")
        return 0

    print(
        f"check_agent_skills: {OUT_DIR} is out of sync with {SKILLS_DIR} — "
        f"run 'mise run gen:copilot' to regenerate.",
        file=sys.stderr,
    )
    for label, paths in (("missing", missing), ("unexpected", extra), ("changed", changed)):
        for rel in paths[:10]:
            print(f"  - {label}: {rel}", file=sys.stderr)
        if len(paths) > 10:
            print(f"  - ... and {len(paths) - 10} more {label}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
