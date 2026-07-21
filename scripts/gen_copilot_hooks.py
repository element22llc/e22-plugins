#!/usr/bin/env python3
"""Generate the Copilot hook manifest from the plugin's ``hooks.json``.

steer's gate hooks run on Claude Code from ``plugins/steer/hooks/hooks.json``
(hard ``deny``) and on the Copilot CLI from
``plugins/steer/hooks/copilot-hooks.json`` (soft ``ask``). Copilot deliberately
ports only a **subset** of the hooks (see ``docs/concepts/copilot-support.md`` →
"Gate hooks on Copilot"), reshaped into Copilot's flat manifest schema:

* only the ``PreToolUse`` gates that can act as a blocking ``permissionDecision``
  are ported (the advisory SessionStart/Stop nudges have no Copilot analog);
* each shared ``.sh`` is invoked with ``STEER_HOOK_TARGET=copilot`` (so it emits
  Copilot's ``permissionDecision`` envelope) and made **fail-open** (``|| true``,
  since Copilot's ``preToolUse`` is fail-*closed*);
* Claude's ``{matcher, hooks:[{command, timeout}]}`` shape becomes Copilot's flat
  ``{type, matcher, bash, timeoutSec}``, and some matchers are simplified.

Which hooks port, and any matcher override, is declared in ``COPILOT_HOOKS``
below — the hook analog of ``gen_copilot_agents.py``'s ``_TOOL_MAP``. Everything
else (the command path, the timeout) is pulled from ``hooks.json`` so the two
sides cannot drift. The output is **strict JSON** (no comments): the Copilot CLI
hook parser is not documented to accept JSONC, so — unlike the VS Code
``mcp.json`` mirror — this file carries no header comment.

``check_copilot_hooks.py`` fails the build if the committed manifest drifts.
Run from the repo root::

    uv run python scripts/gen_copilot_hooks.py            # print to stdout
    uv run python scripts/gen_copilot_hooks.py --write    # write the artifact
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

HOOKS_JSON = Path("plugins/steer/hooks/hooks.json")
COPILOT_HOOKS_JSON = Path("plugins/steer/hooks/copilot-hooks.json")

_SCRIPT_RE = re.compile(r"hooks/([a-z0-9-]+\.sh)")

# (event, script basename, matcher override) triples steer ports to Copilot, in
# the order they should appear in the manifest. ``matcher=None`` keeps the Claude
# matcher; a string overrides it (Copilot's tool-matcher grammar differs — e.g.
# Claude gates Bash *and* issue MCP tools, Copilot just ``Bash``).
COPILOT_HOOKS: list[tuple[str, str, str | None]] = [
    ("PreToolUse", "check-version-pins.sh", None),
    ("PreToolUse", "check-bash-actions.sh", "Bash"),
]


def _find_claude_hook(data: dict, event: str, script: str) -> tuple[str, str, int | None]:
    """Return (matcher, command, timeout) for the ``script`` under ``event`` in
    hooks.json. Raises ``KeyError`` if the pairing is not wired on the Claude side
    — a signal the ``COPILOT_HOOKS`` selection references a hook that no longer
    exists (the generator fails loudly rather than emit a dead reference)."""
    for entry in data.get("hooks", {}).get(event, []):
        for hook in entry.get("hooks", []):
            command = hook.get("command", "")
            if script in _SCRIPT_RE.findall(command):
                return entry.get("matcher", ""), command, hook.get("timeout")
    raise KeyError(f"{script} not wired under {event} in {HOOKS_JSON}")


def render(src: Path = HOOKS_JSON) -> str:
    """Return the Copilot hook manifest text (strict JSON, single trailing newline)."""
    data = json.loads(src.read_text(encoding="utf-8"))

    events: dict[str, list[dict[str, Any]]] = {}
    for event, script, matcher_override in COPILOT_HOOKS:
        matcher, command, timeout = _find_claude_hook(data, event, script)
        hook: dict[str, Any] = {
            "type": "command",
            "matcher": matcher_override if matcher_override is not None else matcher,
            "bash": f"STEER_HOOK_TARGET=copilot {command} || true",
        }
        if timeout is not None:
            hook["timeoutSec"] = timeout
        events.setdefault(event, []).append(hook)

    doc = {"version": 1, "hooks": events}
    return json.dumps(doc, indent=2) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Copilot hook manifest.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write the artifact to {COPILOT_HOOKS_JSON} (default: print to stdout).",
    )
    parser.add_argument(
        "--src",
        type=Path,
        default=HOOKS_JSON,
        help=f"Source Claude hooks.json (default: {HOOKS_JSON}).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=COPILOT_HOOKS_JSON,
        help=f"Output path when --write is set (default: {COPILOT_HOOKS_JSON}).",
    )
    args = parser.parse_args(argv)

    if not args.src.is_file():
        print(f"gen_copilot_hooks: source not found: {args.src}", file=sys.stderr)
        return 1

    try:
        text = render(args.src)
    except KeyError as exc:
        print(f"gen_copilot_hooks: {exc}", file=sys.stderr)
        return 1

    if args.write:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        print(f"gen_copilot_hooks: wrote {args.out} ({len(text)} bytes)")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
