#!/usr/bin/env python3
"""Generate the Copilot MCP configs from the plugin's Claude MCP config.

steer wires its MCP servers into Claude Code via
``plugins/steer/.claude-plugin/mcp.json`` (the ``mcpServers`` key, named by the
Claude manifest's ``mcpServers`` field). Two Copilot hosts need their own copy:

* **Copilot in VS Code** reads the consumer repo's ``.vscode/mcp.json``, so the
  scaffold ships ``plugins/steer/templates/scaffold/vscode/mcp.json`` (VS Code's
  ``servers`` key) - see ``docs/concepts/copilot-support.md`` -> "MCP servers in
  VS Code".
* **The Copilot CLI** loads a plugin-root ``.mcp.json`` ahead of any manifest
  field, so the Claude config must not live there: it would hand the CLI a
  ``${user_config.github_pat}`` it cannot resolve, and the GitHub server fails
  with "Authorization header is badly formatted". The CLI gets
  ``plugins/steer/.github/mcp.json`` instead, named by the Copilot manifest.

This script renders both from the single source of truth so they never diverge;
``check_copilot_mcp.py`` fails the build if either drifts. The one sanctioned
difference is authentication: Claude resolves the token from plugin user config
(prompted at install and held in the macOS Keychain or
``~/.claude/.credentials.json``), while both Copilot hosts sign in to GitHub's
remote MCP server with the user's own GitHub account, so the copies drop that
header. It must not become a ``${input:...}`` prompt: VS Code's Copilot harness
does not forward servers that need interactive input. ``SIGN_IN`` below lists
the placeholders dropped this way; any other ``${...}`` placeholder is carried
through unchanged.

The VS Code mirror is JSONC (it carries ``//`` comments); the CLI copy is strict
JSON. Run from the repo root::

    uv run python scripts/gen_copilot_mcp.py            # print both to stdout
    uv run python scripts/gen_copilot_mcp.py --write    # write the artifacts
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

CLAUDE_MCP = Path("plugins/steer/.claude-plugin/mcp.json")
VSCODE_MCP = Path("plugins/steer/templates/scaffold/vscode/mcp.json")
COPILOT_CLI_MCP = Path("plugins/steer/.github/mcp.json")

# Placeholders whose header the Copilot hosts replace with their own sign-in.
# Keys are the names exactly as they appear inside ``${...}`` in the source.
SIGN_IN = frozenset({"user_config.github_pat"})

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
    "// Generated from the steer plugin's MCP config: the MCP servers Claude Code gets,",
    "// mirrored for Copilot in VS Code. You own this copy: merge it additively and",
    "// drop servers you do not use; /steer:sync never rewrites .vscode/.",
    "// Plugin repo: regenerate with `mise run gen:copilot`.",
]


def _signed_in(server: dict[str, Any]) -> dict[str, Any]:
    """Drop headers that carry a ``SIGN_IN`` placeholder."""
    headers = {
        k: v
        for k, v in server.get("headers", {}).items()
        if not set(_PLACEHOLDER.findall(v)) & SIGN_IN
    }
    out = {k: v for k, v in server.items() if k != "headers"}
    if headers:
        out["headers"] = headers
    return out


def _servers(src: Path) -> dict[str, Any]:
    servers = json.loads(src.read_text(encoding="utf-8")).get("mcpServers", {})
    return {name: _signed_in(server) for name, server in servers.items()}


def render(src: Path = CLAUDE_MCP) -> str:
    """Return the VS Code ``mcp.json`` text (JSONC, single trailing newline)."""
    lines = json.dumps({"servers": _servers(src)}, indent=2).split("\n")
    commented = [lines[0]] + [f"  {c}" for c in HEADER_COMMENT] + lines[1:]
    return "\n".join(commented) + "\n"


def render_cli(src: Path = CLAUDE_MCP) -> str:
    """Return the Copilot CLI ``mcp.json`` text (strict JSON, trailing newline)."""
    return json.dumps({"mcpServers": _servers(src)}, indent=2) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Copilot MCP configs.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write {VSCODE_MCP} and {COPILOT_CLI_MCP} (default: print to stdout).",
    )
    parser.add_argument(
        "--src",
        type=Path,
        default=CLAUDE_MCP,
        help=f"Source Claude MCP config (default: {CLAUDE_MCP}).",
    )
    args = parser.parse_args(argv)

    if not args.src.is_file():
        print(f"gen_copilot_mcp: source not found: {args.src}", file=sys.stderr)
        return 1

    for out, text in ((VSCODE_MCP, render(args.src)), (COPILOT_CLI_MCP, render_cli(args.src))):
        if args.write:
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(text, encoding="utf-8")
            print(f"gen_copilot_mcp: wrote {out} ({len(text)} bytes)")
        else:
            sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
