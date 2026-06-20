#!/usr/bin/env python3
"""Sync gate: the committed Copilot prompt-file artifacts must match the skills.

``gen_copilot_prompts.py`` generates one
``plugins/steer/templates/github/prompts/steer-<name>.prompt.md`` per
user-invocable skill from ``plugins/steer/skills/*/SKILL.md``. Those artifacts are
committed (so ``/steer:init`` can install them without running Python in the
consumer repo), which means they can go stale the moment a skill's frontmatter
changes — or when a skill is added, removed, or made internal. This check
regenerates in-memory and compares the full set against the committed directory,
failing the build on any drift — the same single-source-of-truth discipline
``check_copilot_instructions.py`` applies to the rules artifact.

Run from the repo root::

    uv run python scripts/check_copilot_prompts.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_copilot_prompts import PROMPT_PREFIX, PROMPTS_DIR, SKILLS_DIR, render_all


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f"check_copilot_prompts: skills dir not found: {SKILLS_DIR}", file=sys.stderr)
        return 1
    if not PROMPTS_DIR.is_dir():
        print(
            f"check_copilot_prompts: missing {PROMPTS_DIR} — run 'mise run gen:copilot'",
            file=sys.stderr,
        )
        return 1

    expected = render_all(SKILLS_DIR)
    committed = {
        p.name: p.read_text(encoding="utf-8")
        for p in PROMPTS_DIR.glob(f"{PROMPT_PREFIX}*.prompt.md")
    }

    problems: list[str] = []
    for name in sorted(set(expected) - set(committed)):
        problems.append(f"missing artifact {name}")
    for name in sorted(set(committed) - set(expected)):
        problems.append(f"stale artifact {name} (skill removed or made internal)")
    for name in sorted(set(expected) & set(committed)):
        if committed[name] != expected[name]:
            problems.append(f"out-of-sync artifact {name}")

    if problems:
        print(
            f"check_copilot_prompts: {PROMPTS_DIR} is out of sync with {SKILLS_DIR}/ — "
            f"run 'mise run gen:copilot' to regenerate:",
            file=sys.stderr,
        )
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"check_copilot_prompts: OK ({len(expected)} prompt file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
