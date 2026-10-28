#!/usr/bin/env python3
"""Sync gate: the committed Copilot MCP configs must match the Claude one.

``gen_copilot_mcp.py`` renders two copies from the plugin's
``plugins/steer/.claude-plugin/mcp.json`` (the single source of truth): the VS
Code scaffold ``plugins/steer/templates/scaffold/vscode/mcp.json`` and the
Copilot CLI's ``plugins/steer/.github/mcp.json``. Both are committed (so
``/steer:init`` can install the first without running Python in the consumer
repo, and the CLI reads the second from the installed plugin), which means they
go stale the moment a server is added, removed, or retargeted on the Claude
side. This check regenerates in-memory and byte-compares against each committed
file, failing the build on any drift.

It also fails when a plugin-root ``.mcp.json`` exists: the Copilot CLI loads
that file ahead of the Copilot manifest's ``mcpServers``, so a Claude config
there would reach the CLI with a token placeholder it cannot resolve.

Run from the repo root::

    uv run python scripts/check_copilot_mcp.py

Exit status is 0 when in sync, 1 on drift (fix with ``mise run gen:copilot``).
"""

from __future__ import annotations

import sys

from gen_copilot_mcp import CLAUDE_MCP, COPILOT_CLI_MCP, VSCODE_MCP, render, render_cli


def main() -> int:
    if not CLAUDE_MCP.is_file():
        print(f"check_copilot_mcp: source not found: {CLAUDE_MCP}", file=sys.stderr)
        return 1
    root_mcp = CLAUDE_MCP.parent.parent / ".mcp.json"
    if root_mcp.exists():
        print(
            f"check_copilot_mcp: {root_mcp} must not exist - the Copilot CLI loads it "
            f"ahead of {COPILOT_CLI_MCP}; keep Claude's servers in {CLAUDE_MCP}.",
            file=sys.stderr,
        )
        return 1

    failed = False
    renders = ((VSCODE_MCP, render(CLAUDE_MCP)), (COPILOT_CLI_MCP, render_cli(CLAUDE_MCP)))
    for out, expected in renders:
        if not out.is_file():
            print(f"check_copilot_mcp: missing {out} - run 'mise run gen:copilot'", file=sys.stderr)
            failed = True
        elif out.read_text(encoding="utf-8") != expected:
            print(
                f"check_copilot_mcp: {out} is out of sync with {CLAUDE_MCP} - "
                f"run 'mise run gen:copilot' to regenerate.",
                file=sys.stderr,
            )
            failed = True
    if failed:
        return 1

    print("check_copilot_mcp: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
