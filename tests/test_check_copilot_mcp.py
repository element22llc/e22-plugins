"""Tests for the Copilot/VS Code MCP generator + sync gate.

``gen_copilot_mcp.py`` renders ``plugins/steer/templates/scaffold/vscode/mcp.json``
(VS Code's ``servers`` schema) from ``plugins/steer/.mcp.json`` (Claude's
``mcpServers``), translating the auth placeholder (plugin user config → prompted
input). The
gate byte-compares the committed mirror against a fresh render. The real plugin's
mirror must already be in sync.
"""

from __future__ import annotations

import json
from pathlib import Path

import check_copilot_mcp
import gen_copilot_mcp

GITHUB = {"type": "http", "url": "https://api.githubcopilot.com/mcp/"}
MARKITDOWN = {"command": "uvx", "args": ["markitdown-mcp"]}


def _claude(servers: dict) -> str:
    return json.dumps({"mcpServers": servers})


def _gh(auth: str) -> dict:
    return {**GITHUB, "headers": {"Authorization": f"Bearer {auth}"}}


def test_render_translates_github_pat(tmp_path: Path):
    src = tmp_path / ".mcp.json"
    src.write_text(_claude({"github": _gh("${user_config.github_pat}"), "markitdown": MARKITDOWN}))
    out = gen_copilot_mcp.render(src)
    assert "// Generated from the steer plugin's .mcp.json" in out
    # Unlike the four artifacts under templates/github/, this one is NOT steer-managed
    # in the consumer repo: `/steer:sync`'s agent-surface-current capability does not
    # cover `.vscode/`, and the scaffold MANIFEST tells the consumer to merge it
    # additively and drop unused servers. So the header must say the consumer owns it
    # and must NOT claim a refresh path — asserted here so it cannot regress to the
    # "do not edit by hand" / "refresh with /steer:sync" wording it carried before.
    assert "You own this copy" in out
    assert "/steer:sync never rewrites .vscode/" in out
    assert "do not edit by hand" not in out
    # The dotted user-config placeholder becomes a prompted input, with a matching
    # inputs block. VS Code has no notion of Claude's plugin userConfig, so the
    # reference must not survive into the mirror verbatim.
    assert "${input:github_pat}" in out
    assert "${user_config.github_pat}" not in out
    assert '"inputs"' in out
    assert '"servers"' in out


def test_render_passes_through_unmapped_placeholder(tmp_path: Path):
    # A placeholder with no AUTH_INPUTS entry is carried through unchanged, and no
    # inputs block is synthesized for it. Covers both placeholder shapes the
    # regex accepts: a bare env var and a dotted user-config reference.
    src = tmp_path / ".mcp.json"
    src.write_text(_claude({"svc": {"command": "x", "args": ["${OTHER}", "${user_config.other}"]}}))
    out = gen_copilot_mcp.render(src)
    assert "${OTHER}" in out
    assert "${user_config.other}" in out
    assert '"inputs"' not in out


def test_gate_ok_then_drift(tmp_path: Path, monkeypatch):
    src = tmp_path / ".mcp.json"
    dst = tmp_path / "mcp.json"
    src.write_text(_claude({"github": _gh("${user_config.github_pat}"), "markitdown": MARKITDOWN}))
    dst.write_text(gen_copilot_mcp.render(src), encoding="utf-8")
    monkeypatch.setattr(check_copilot_mcp, "CLAUDE_MCP", src)
    monkeypatch.setattr(check_copilot_mcp, "VSCODE_MCP", dst)
    assert check_copilot_mcp.main() == 0
    dst.write_text(dst.read_text() + "  // tampered\n", encoding="utf-8")
    assert check_copilot_mcp.main() == 1


def test_real_plugin_in_sync(monkeypatch):
    from conftest import REPO_ROOT

    monkeypatch.setattr(check_copilot_mcp, "CLAUDE_MCP", REPO_ROOT / check_copilot_mcp.CLAUDE_MCP)
    monkeypatch.setattr(check_copilot_mcp, "VSCODE_MCP", REPO_ROOT / check_copilot_mcp.VSCODE_MCP)
    assert check_copilot_mcp.main() == 0
