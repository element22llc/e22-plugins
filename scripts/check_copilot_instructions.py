#!/usr/bin/env python3
"""Sync gate: the committed Copilot instructions artifact must match the rules.

``gen_copilot_instructions.py`` generates
``plugins/steer/templates/github/copilot-instructions.md`` from
``plugins/steer/rules/*.md``. That artifact is committed (so ``/steer:init`` can
install it without running Python in the consumer repo), which means it can go
stale the moment a rule changes. This check regenerates in-memory and byte-compares
against the committed file, failing the build if they drift — the same
single-source-of-truth discipline ``check_standards.py`` applies to the scaffold's
verbatim policy copies.

Run from the repo root::

    uv run python scripts/check_copilot_instructions.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_copilot_instructions import (
    ARTIFACT,
    INSTRUCTIONS_DIR,
    RULES_DIR,
    render,
    render_scoped,
)


def main() -> int:
    if not RULES_DIR.is_dir():
        print(f"check_copilot_instructions: rules dir not found: {RULES_DIR}", file=sys.stderr)
        return 1
    if not ARTIFACT.is_file():
        print(
            f"check_copilot_instructions: missing {ARTIFACT} — run 'mise run gen:copilot'",
            file=sys.stderr,
        )
        return 1

    expected = render(RULES_DIR)
    actual = ARTIFACT.read_text(encoding="utf-8")
    if actual != expected:
        print(
            f"check_copilot_instructions: {ARTIFACT} is out of sync with "
            f"{RULES_DIR}/ — run 'mise run gen:copilot' to regenerate",
            file=sys.stderr,
        )
        return 1

    # Path-scoped instruction files (.github/instructions/*.instructions.md).
    expected_scoped = render_scoped(RULES_DIR)
    committed_scoped = {
        p.name: p.read_text(encoding="utf-8") for p in INSTRUCTIONS_DIR.glob("*.instructions.md")
    }
    problems: list[str] = []
    for name in sorted(set(expected_scoped) - set(committed_scoped)):
        problems.append(f"missing scoped instruction {name}")
    for name in sorted(set(committed_scoped) - set(expected_scoped)):
        problems.append(f"stale scoped instruction {name} (rule un-scoped or removed)")
    for name in sorted(set(expected_scoped) & set(committed_scoped)):
        if committed_scoped[name] != expected_scoped[name]:
            problems.append(f"out-of-sync scoped instruction {name}")
    if problems:
        print(
            f"check_copilot_instructions: {INSTRUCTIONS_DIR} is out of sync with "
            f"{RULES_DIR}/ — run 'mise run gen:copilot' to regenerate:",
            file=sys.stderr,
        )
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print("check_copilot_instructions: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
