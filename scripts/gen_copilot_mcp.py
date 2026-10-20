#!/usr/bin/env python3
"""Generate the VS Code MCP scaffold from the plugin's ``.mcp.json``.

steer wires its MCP servers into Claude Code via ``plugins/steer/.mcp.json``
(the ``mcpServers`` key). Copilot in VS Code does **not** read that file, so the
scaffold ships ``plugins/steer/templates/scaffold/vscode/mcp.json`` (VS Code's
``servers`` key) mirroring the same servers - see
``docs/concepts/copilot-support.md`` -> "MCP servers in VS Code".

This script renders that mirror from the single source of truth (``.mcp.json``)
so the two never diverge; ``check_copilot_mcp.py`` fails the build if the
committed mirror drifts. The one sanctioned difference is authentication: Claude
resolves the token from plugin user config (``${user_config.github_pat}``,
prompted at install and held in the macOS Keychain or
``~/.claude/.credentials.json``), while VS Code signs in to GitHub's remote MCP
server with its own GitHub account, so the mirror drops that header. It must
not become a ``${input:...}`` prompt: VS Code's Copilot harness does not forward
servers that need interactive input. ``VSCODE_SIGN_IN`` below lists the
placeholders dropped this way; any other ``${...}`` placeholder is carried
through unchanged.

The mirror is JSONC (it carries ``//`` comments and an ``inputs`` block); VS Code
tolerates both. Run from the repo root::

    uv run python scripts/gen_copilot_mcp.py            # print to stdout
    uv run python scripts/gen_copilot_mcp.py --write    # write the artifact
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

CLAUDE_MCP = Path("plugins/steer/.mcp.json")
VSCODE_MCP = Path("plugins/steer/templates/scaffold/vscode/mcp.json")

# Placeholders whose header VS Code replaces with its own sign-in. Keys are the
# names exactly as they appear inside ``${...}`` in ``.mcp.json``.
VSCODE_SIGN_IN = frozenset({"user_config.github_pat"})

# Matches ``${NAME}`` where NAME may be dotted, so both a bare env var
# (``${FOO}``) and a plugin user-config reference (``${user_config.foo}``)
# are recognized.
_PLACEHOLDER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_.]*)\}")

# JSONC header injected inside the top-level object (2-space indented). The first
# lines mark the file generated; the rest is the standing guidance for consumers.
#
# Unlike the four artifacts under templates/github/, this one is NOT steer-managed
# in the consumer repo: `/steer:sync`'s agent-surface-current capability does not
# cover `.vscode/` (see scan-capabilities.sh), and the scaffold MANIFEST tells the
# consumer to merge it additively and drop unused servers. So the header must not
# promise a refresh path, and must not forbid the hand-editing the install expects.
HEADER_COMMENT = [
    "// Generated from the steer plugin's .mcp.json: the MCP servers Claude Code gets,",
    "// mirrored for Copilot in VS Code. You own this copy: merge it additively and",
    "// drop servers you do not use; /steer:sync never rewrites .vscode/.",
    "// Plugin repo: regenerate with `mise run gen:copilot`.",
]


def _to_vscode(server: dict[str, Any]) -> dict[str, Any]:
    """Drop headers that carry a ``VSCODE_SIGN_IN`` placeholder."""
    headers = {
        k: v
        for k, v in server.get("headers", {}).items()
        if not set(_PLACEHOLDER.findall(v)) & VSCODE_SIGN_IN
    }
    out = {k: v for k, v in server.items() if k != "headers"}
    if headers:
        out["headers"] = headers
    return out


def render(src: Path = CLAUDE_MCP) -> str:
    """Return the full VS Code ``mcp.json`` text (JSONC, single trailing newline)."""
    servers = json.loads(src.read_text(encoding="utf-8")).get("mcpServers", {})
    doc = {"servers": {name: _to_vscode(server) for name, server in servers.items()}}

    lines = json.dumps(doc, indent=2).split("\n")
    commented = [lines[0]] + [f"  {c}" for c in HEADER_COMMENT] + lines[1:]
    return "\n".join(commented) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the VS Code MCP scaffold.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write the artifact to {VSCODE_MCP} (default: print to stdout).",
    )
    parser.add_argument(
        "--src",
        type=Path,
        default=CLAUDE_MCP,
        help=f"Source plugin .mcp.json (default: {CLAUDE_MCP}).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=VSCODE_MCP,
        help=f"Output path when --write is set (default: {VSCODE_MCP}).",
    )
    args = parser.parse_args(argv)

    if not args.src.is_file():
        print(f"gen_copilot_mcp: source not found: {args.src}", file=sys.stderr)
        return 1

    text = render(args.src)
    if args.write:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        print(f"gen_copilot_mcp: wrote {args.out} ({len(text)} bytes)")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
