#!/usr/bin/env python3
"""Sync gate: the committed Copilot custom-agent artifacts must match the subagents.

``gen_copilot_agents.py`` generates one
``plugins/steer/templates/github/agents/<name>.agent.md`` per steer subagent in
``plugins/steer/agents/*.md``. Those artifacts are committed (so ``/steer:init``
can install them without running Python in the consumer repo), which means they
can go stale the moment a subagent's frontmatter or body changes — or when a
subagent is added or removed. This check regenerates in-memory and compares the
full set against the committed directory, failing the build on any drift — the
same single-source-of-truth discipline the other ``check_copilot_*`` gates apply.

Run from the repo root::

    uv run python scripts/check_copilot_agents.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_copilot_agents import AGENTS_DIR, OUT_DIR, render_all


def main() -> int:
    if not AGENTS_DIR.is_dir():
        print(f"check_copilot_agents: agents dir not found: {AGENTS_DIR}", file=sys.stderr)
        return 1
    if not OUT_DIR.is_dir():
        print(
            f"check_copilot_agents: missing {OUT_DIR} — run 'mise run gen:copilot'",
            file=sys.stderr,
        )
        return 1

    expected = render_all(AGENTS_DIR)
    committed = {p.name: p.read_text(encoding="utf-8") for p in OUT_DIR.glob("*.agent.md")}

    problems: list[str] = []
    for name in sorted(set(expected) - set(committed)):
        problems.append(f"missing artifact {name}")
    for name in sorted(set(committed) - set(expected)):
        problems.append(f"stale artifact {name} (subagent removed or renamed)")
    for name in sorted(set(expected) & set(committed)):
        if committed[name] != expected[name]:
            problems.append(f"out-of-sync artifact {name}")

    if problems:
        print(
            f"check_copilot_agents: {OUT_DIR} is out of sync with {AGENTS_DIR}/ — "
            f"run 'mise run gen:copilot' to regenerate:",
            file=sys.stderr,
        )
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"check_copilot_agents: OK ({len(expected)} agent file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
