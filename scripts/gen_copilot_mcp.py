#!/usr/bin/env python3
"""Generate the VS Code MCP scaffold from the plugin's ``.mcp.json``.

steer wires its MCP servers into Claude Code via ``plugins/steer/.mcp.json``
(the ``mcpServers`` key). Copilot in VS Code does **not** read that file, so the
scaffold ships ``plugins/steer/templates/scaffold/vscode/mcp.json`` (VS Code's
``servers`` key) mirroring the same servers — see
``docs/concepts/copilot-support.md`` → "MCP servers in VS Code".

This script renders that mirror from the single source of truth (``.mcp.json``)
so the two never diverge; ``check_copilot_mcp.py`` fails the build if the
committed mirror drifts. The one sanctioned difference is authentication: Claude
uses an env-var placeholder (``${GITHUB_PAT}``) while VS Code uses a prompted
input (``${input:github_pat}``) with a matching ``inputs`` block. That mapping
lives in ``AUTH_INPUTS`` below — the MCP analog of ``gen_copilot_agents.py``'s
``_TOOL_MAP``. Any ``${...}`` placeholder without an ``AUTH_INPUTS`` entry is
carried through unchanged.

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

# Map each env-var auth placeholder used on the Claude side to the VS Code
# prompted-input it becomes, plus the ``inputs`` entry that declares it. Keys are
# the env-var names as they appear inside ``${...}`` in ``.mcp.json``; the value's
# ``id`` is what ``${input:<id>}`` references. Insertion order of the dict fields
# is preserved in the emitted JSON (type, id, description, password).
AUTH_INPUTS: dict[str, dict[str, Any]] = {
    "GITHUB_PAT": {
        "type": "promptString",
        "id": "github_pat",
        "description": (
            "GitHub personal access token for the GitHub MCP server (repo + issues scope)"
        ),
        "password": True,
    },
}

_PLACEHOLDER = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")

# JSONC header injected inside the top-level object (2-space indented). The first
# lines mark the file generated; the rest is the standing guidance for consumers.
HEADER_COMMENT = [
    "// Generated from the steer plugin's .mcp.json — do not edit by hand.",
    "// Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step).",
    "//",
    "// Model Context Protocol servers for GitHub Copilot in VS Code (Chat + Agent",
    "// mode) and Visual Studio. Mirrors the servers the steer plugin wires into",
    "// Claude Code (plugins/steer/.mcp.json) so a Copilot teammate gets the same",
    "// tooling: the GitHub MCP server that /steer:tracker-sync is built around,",
    "// markitdown for reading PO source docs (docx/pptx/xlsx/pdf), and context7 for",
    '// up-to-date library docs. VS Code uses the "servers" key (not "mcpServers").',
    "//",
    "// The GitHub server authenticates with a fine-grained PAT prompted once and",
    "// stored by VS Code's secret storage. Remove any server you do not use.",
]


def _referenced_env_vars(obj: Any) -> list[str]:
    """Env-var placeholder names in first-appearance order across all strings."""
    found: list[str] = []

    def walk(value: Any) -> None:
        if isinstance(value, dict):
            for v in value.values():
                walk(v)
        elif isinstance(value, list):
            for v in value:
                walk(v)
        elif isinstance(value, str):
            for name in _PLACEHOLDER.findall(value):
                if name not in found:
                    found.append(name)

    walk(obj)
    return found


def _to_vscode(obj: Any) -> Any:
    """Rewrite ``${ENV}`` auth placeholders to ``${input:<id>}`` where mapped."""
    if isinstance(obj, dict):
        return {k: _to_vscode(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_to_vscode(v) for v in obj]
    if isinstance(obj, str):

        def repl(match: re.Match[str]) -> str:
            var = match.group(1)
            spec = AUTH_INPUTS.get(var)
            return f"${{input:{spec['id']}}}" if spec else match.group(0)

        return _PLACEHOLDER.sub(repl, obj)
    return obj


def render(src: Path = CLAUDE_MCP) -> str:
    """Return the full VS Code ``mcp.json`` text (JSONC, single trailing newline)."""
    servers = json.loads(src.read_text(encoding="utf-8")).get("mcpServers", {})
    inputs = [dict(AUTH_INPUTS[var]) for var in _referenced_env_vars(servers) if var in AUTH_INPUTS]

    doc: dict[str, Any] = {}
    if inputs:
        doc["inputs"] = inputs
    doc["servers"] = _to_vscode(servers)

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
