#!/usr/bin/env python3
"""Sync gate: the committed Copilot hook manifest must match ``hooks.json``.

``gen_copilot_hooks.py`` renders ``plugins/steer/hooks/copilot-hooks.json`` from
the plugin's ``plugins/steer/hooks/hooks.json`` (the single source of truth),
porting the documented ``PreToolUse`` subset into Copilot's flat schema with
``STEER_HOOK_TARGET=copilot`` and fail-open ``|| true``. This check regenerates
in-memory and byte-compares against the committed manifest, failing the build on
any drift — so renaming, dropping, or retiming a hook on the Claude side can no
longer silently leave the Copilot manifest behind.

Because the manifest is *generated* from ``hooks.json``, the referential
integrity the old parity gate asserted (every referenced script is wired on the
Claude side, carries the target flag, and is fail-open) now holds by
construction. We additionally verify each referenced script still exists on disk
— the one property regeneration alone can't guarantee, since ``hooks.json`` could
name a script that was deleted.

Run from the repo root::

    uv run python scripts/check_copilot_hooks.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_copilot_hooks import COPILOT_HOOKS, COPILOT_HOOKS_JSON, HOOKS_JSON, render

HOOKS_DIR = HOOKS_JSON.parent


def main() -> int:
    if not HOOKS_JSON.is_file():
        print(f"check_copilot_hooks: source not found: {HOOKS_JSON}", file=sys.stderr)
        return 1
    if not COPILOT_HOOKS_JSON.is_file():
        print(
            f"check_copilot_hooks: missing {COPILOT_HOOKS_JSON} — run 'mise run gen:copilot'",
            file=sys.stderr,
        )
        return 1

    problems: list[str] = []
    for _event, script, _matcher in COPILOT_HOOKS:
        if not (HOOKS_DIR / script).is_file():
            problems.append(f"referenced script '{script}' does not exist under {HOOKS_DIR}/")

    try:
        expected = render(HOOKS_JSON)
    except KeyError as exc:
        print(f"check_copilot_hooks: {exc}", file=sys.stderr)
        return 1
    committed = COPILOT_HOOKS_JSON.read_text(encoding="utf-8")
    if committed != expected:
        problems.append(
            f"{COPILOT_HOOKS_JSON.name} is out of sync with {HOOKS_JSON.name} "
            f"— run 'mise run gen:copilot' to regenerate"
        )

    if problems:
        print("check_copilot_hooks: drift detected:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print("check_copilot_hooks: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
