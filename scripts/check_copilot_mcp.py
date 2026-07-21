#!/usr/bin/env python3
"""Parity gate: the VS Code MCP scaffold must mirror the plugin's MCP servers.

steer wires its MCP servers into Claude Code via ``plugins/steer/.mcp.json``
(the ``mcpServers`` key). Copilot in VS Code does **not** read that file, so the
scaffold ships ``plugins/steer/templates/scaffold/vscode/mcp.json`` (VS Code's
``servers`` key) mirroring the same servers — see
``docs/concepts/copilot-support.md`` → "MCP servers in VS Code". Unlike the
generated Copilot artifacts (instructions/prompts/agents), this mirror is
hand-maintained: nothing regenerates it, so adding, removing, or retargeting a
server on the Claude side can silently leave the VS Code side behind.

This check pins the two files together. Both must expose the **same set of
server names**, and each server's config must match once the authentication
placeholder is normalized — Claude uses an env var (``${GITHUB_PAT}``) while VS
Code uses a prompted input (``${input:github_pat}``), which is the one
sanctioned difference. The VS Code file is JSONC (it carries ``//`` comments and
an ``inputs`` block); both are tolerated.

Run from the repo root::

    uv run python scripts/check_copilot_mcp.py

Exit status is 0 when in sync, 1 on drift (fix the VS Code scaffold by hand).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

CLAUDE_MCP = Path("plugins/steer/.mcp.json")
VSCODE_MCP = Path("plugins/steer/templates/scaffold/vscode/mcp.json")


def _strip_jsonc(text: str) -> str:
    """Drop ``//`` line comments from JSONC, leaving ``//`` inside strings alone."""
    out: list[str] = []
    in_string = False
    escaped = False
    i = 0
    while i < len(text):
        ch = text[i]
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < len(text) and text[i + 1] == "/":
            # Skip to end of line.
            while i < len(text) and text[i] != "\n":
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _load_jsonc(path: Path) -> Any:
    return json.loads(_strip_jsonc(path.read_text(encoding="utf-8")))


def _normalize(value: Any) -> Any:
    """Collapse any ``${...}`` placeholder to a single sentinel so the env-var vs
    prompted-input auth difference does not read as drift, while structure
    (header names, the ``Bearer `` prefix, URLs, commands) is still compared."""
    if isinstance(value, dict):
        return {k: _normalize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_normalize(v) for v in value]
    if isinstance(value, str):
        return re.sub(r"\$\{[^}]*\}", "${VAR}", value)
    return value


def main() -> int:
    for path in (CLAUDE_MCP, VSCODE_MCP):
        if not path.is_file():
            print(f"check_copilot_mcp: file not found: {path}", file=sys.stderr)
            return 1

    try:
        claude = json.loads(CLAUDE_MCP.read_text(encoding="utf-8")).get("mcpServers", {})
    except json.JSONDecodeError as exc:
        print(f"check_copilot_mcp: invalid JSON in {CLAUDE_MCP} ({exc})", file=sys.stderr)
        return 1
    try:
        vscode = _load_jsonc(VSCODE_MCP).get("servers", {})
    except json.JSONDecodeError as exc:
        print(f"check_copilot_mcp: invalid JSON in {VSCODE_MCP} ({exc})", file=sys.stderr)
        return 1

    problems: list[str] = []
    for name in sorted(set(claude) - set(vscode)):
        problems.append(f"server '{name}' in {CLAUDE_MCP.name} is missing from {VSCODE_MCP.name}")
    for name in sorted(set(vscode) - set(claude)):
        problems.append(
            f"server '{name}' in {VSCODE_MCP.name} has no counterpart in {CLAUDE_MCP.name}"
        )
    for name in sorted(set(claude) & set(vscode)):
        if _normalize(claude[name]) != _normalize(vscode[name]):
            problems.append(f"server '{name}' config differs between the two files")

    if problems:
        print(
            f"check_copilot_mcp: {VSCODE_MCP} is out of sync with {CLAUDE_MCP} — "
            f"mirror the servers by hand (only the auth placeholder may differ):",
            file=sys.stderr,
        )
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1

    print(f"check_copilot_mcp: OK ({len(claude)} server(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
