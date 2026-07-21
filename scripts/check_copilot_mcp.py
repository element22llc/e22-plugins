#!/usr/bin/env python3
"""Sync gate: the committed VS Code MCP scaffold must match ``.mcp.json``.

``gen_copilot_mcp.py`` renders ``plugins/steer/templates/scaffold/vscode/mcp.json``
from the plugin's ``plugins/steer/.mcp.json`` (the single source of truth). That
mirror is committed (so ``/steer:init`` can install it without running Python in
the consumer repo), which means it can go stale the moment a server is added,
removed, or retargeted on the Claude side. This check regenerates in-memory and
byte-compares against the committed file, failing the build on any drift — the
same single-source-of-truth discipline the other Copilot artifacts get.

Run from the repo root::

    uv run python scripts/check_copilot_mcp.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_copilot_mcp import CLAUDE_MCP, VSCODE_MCP, render


def main() -> int:
    if not CLAUDE_MCP.is_file():
        print(f"check_copilot_mcp: source not found: {CLAUDE_MCP}", file=sys.stderr)
        return 1
    if not VSCODE_MCP.is_file():
        print(
            f"check_copilot_mcp: missing {VSCODE_MCP} — run 'mise run gen:copilot'",
            file=sys.stderr,
        )
        return 1

    expected = render(CLAUDE_MCP)
    committed = VSCODE_MCP.read_text(encoding="utf-8")

    if committed != expected:
        print(
            f"check_copilot_mcp: {VSCODE_MCP} is out of sync with {CLAUDE_MCP} — "
            f"run 'mise run gen:copilot' to regenerate.",
            file=sys.stderr,
        )
        return 1

    print("check_copilot_mcp: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
