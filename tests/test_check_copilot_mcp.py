"""Tests for the Copilot/VS Code MCP generator + sync gate.

``gen_copilot_mcp.py`` renders ``plugins/steer/templates/scaffold/vscode/mcp.json``
(VS Code's ``servers`` schema) from ``plugins/steer/.mcp.json`` (Claude's
``mcpServers``), dropping the GitHub PAT header that VS Code's own sign-in
replaces. The gate byte-compares the committed mirror against a fresh render.
The real plugin's mirror must already be in sync.
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


def test_render_drops_github_pat_for_vscode_sign_in(tmp_path: Path):
    src = tmp_path / ".mcp.json"
    src.write_text(_claude({"github": _gh("${user_config.github_pat}"), "markitdown": MARKITDOWN}))
    out = gen_copilot_mcp.render(src)
    assert "// Generated from the steer plugin's .mcp.json" in out
    # Unlike the four artifacts under templates/github/, this one is NOT steer-managed
    # in the consumer repo: `/steer:sync`'s agent-surface-current capability does not
    # cover `.vscode/`, and the scaffold MANIFEST tells the consumer to merge it
    # additively and drop unused servers. So the header must say the consumer owns it
    # and must NOT claim a refresh path - asserted here so it cannot regress to the
    # "do not edit by hand" / "refresh with /steer:sync" wording it carried before.
    assert "You own this copy" in out
    assert "/steer:sync never rewrites .vscode/" in out
    assert "do not edit by hand" not in out
    # VS Code's Copilot harness does not forward a server that needs a
    # ${input:...} prompt, so the PAT header is dropped and VS Code signs in to
    # GitHub itself. Claude's userConfig reference must not survive either.
    servers = json.loads(
        "\n".join(ln for ln in out.splitlines() if not ln.lstrip().startswith("//"))
    )["servers"]
    assert servers["github"] == GITHUB
    assert servers["markitdown"] == MARKITDOWN
    assert "${input:" not in out
    assert "${user_config.github_pat}" not in out
    assert '"inputs"' not in out


def test_render_keeps_other_headers(tmp_path: Path):
    src = tmp_path / ".mcp.json"
    gh = _gh("${user_config.github_pat}")
    gh["headers"]["X-MCP-Toolsets"] = "issues"
    src.write_text(_claude({"github": gh}))
    out = gen_copilot_mcp.render(src)
    assert '"X-MCP-Toolsets": "issues"' in out
    assert "Authorization" not in out


def test_render_passes_through_unmapped_placeholder(tmp_path: Path):
    # A placeholder outside VSCODE_SIGN_IN is carried through unchanged. Covers both
    # placeholder shapes the regex accepts: a bare env var and a dotted user-config reference.
    src = tmp_path / ".mcp.json"
    src.write_text(_claude({"svc": {"command": "x", "args": ["${OTHER}", "${user_config.other}"]}}))
    out = gen_copilot_mcp.render(src)
    assert "${OTHER}" in out
    assert "${user_config.other}" in out


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
    assert "${input:" not in (REPO_ROOT / check_copilot_mcp.VSCODE_MCP).read_text()
