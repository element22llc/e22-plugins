"""Tests for the Copilot/VS Code MCP parity gate.

The gate pins ``plugins/steer/templates/scaffold/vscode/mcp.json`` (VS Code's
``servers`` schema) to ``plugins/steer/.mcp.json`` (Claude's ``mcpServers``): the
two must expose the same server set with matching configs, tolerating only the
auth-placeholder difference and JSONC comments. The real plugin must be in sync.
"""

from __future__ import annotations

import json
from pathlib import Path

import check_copilot_mcp

GITHUB = {"type": "http", "url": "https://api.githubcopilot.com/mcp/"}
MARKITDOWN = {"command": "uvx", "args": ["markitdown-mcp"]}
CONTEXT7 = {"type": "http", "url": "https://mcp.context7.com/mcp"}


def _claude(servers: dict) -> str:
    return json.dumps({"mcpServers": servers})


def _vscode(servers: dict, *, comment: bool = True) -> str:
    body = json.dumps({"inputs": [{"id": "github_pat"}], "servers": servers}, indent=2)
    return ("// VS Code MCP servers — mirrors .mcp.json.\n" + body) if comment else body


def _gh(auth: str) -> dict:
    return {**GITHUB, "headers": {"Authorization": f"Bearer {auth}"}}


def _point(monkeypatch, tmp_path: Path, claude: str, vscode: str) -> None:
    cpath, vpath = tmp_path / ".mcp.json", tmp_path / "mcp.json"
    cpath.write_text(claude, encoding="utf-8")
    vpath.write_text(vscode, encoding="utf-8")
    monkeypatch.setattr(check_copilot_mcp, "CLAUDE_MCP", cpath)
    monkeypatch.setattr(check_copilot_mcp, "VSCODE_MCP", vpath)


def test_in_sync_with_auth_placeholder_and_comments(tmp_path, monkeypatch):
    # Distinct auth placeholders (env var vs prompted input) + JSONC comment are OK.
    _point(
        monkeypatch,
        tmp_path,
        _claude({"github": _gh("${GITHUB_PAT}"), "markitdown": MARKITDOWN}),
        _vscode({"github": _gh("${input:github_pat}"), "markitdown": MARKITDOWN}),
    )
    assert check_copilot_mcp.main() == 0


def test_missing_server_fails(tmp_path, monkeypatch):
    _point(
        monkeypatch,
        tmp_path,
        _claude({"github": _gh("${GITHUB_PAT}"), "markitdown": MARKITDOWN}),
        _vscode({"github": _gh("${input:github_pat}")}),
    )
    assert check_copilot_mcp.main() == 1


def test_extra_server_fails(tmp_path, monkeypatch):
    _point(
        monkeypatch,
        tmp_path,
        _claude({"github": _gh("${GITHUB_PAT}")}),
        _vscode({"github": _gh("${input:github_pat}"), "context7": CONTEXT7}),
    )
    assert check_copilot_mcp.main() == 1


def test_config_difference_fails(tmp_path, monkeypatch):
    # A genuine (non-placeholder) difference — a changed URL — must be caught.
    _point(
        monkeypatch,
        tmp_path,
        _claude({"github": _gh("${GITHUB_PAT}")}),
        _vscode({"github": {**_gh("${input:github_pat}"), "url": "https://example.com/mcp/"}}),
    )
    assert check_copilot_mcp.main() == 1


def test_real_plugin_in_sync(monkeypatch):
    from conftest import REPO_ROOT

    monkeypatch.setattr(check_copilot_mcp, "CLAUDE_MCP", REPO_ROOT / check_copilot_mcp.CLAUDE_MCP)
    monkeypatch.setattr(check_copilot_mcp, "VSCODE_MCP", REPO_ROOT / check_copilot_mcp.VSCODE_MCP)
    assert check_copilot_mcp.main() == 0
