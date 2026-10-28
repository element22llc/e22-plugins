"""Tests for the Copilot MCP generator + sync gate.

``gen_copilot_mcp.py`` renders ``plugins/steer/templates/scaffold/vscode/mcp.json``
(VS Code's ``servers`` schema) and ``plugins/steer/.github/mcp.json`` (the
Copilot CLI's ``mcpServers``) from ``plugins/steer/.claude-plugin/mcp.json``,
dropping the GitHub PAT header that each Copilot host's own sign-in replaces.
The gate byte-compares both committed copies against a fresh render, and refuses
a plugin-root ``.mcp.json``, which the CLI would load instead. The real plugin's
copies must already be in sync.
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
    src = tmp_path / "mcp.json"
    src.write_text(_claude({"github": _gh("${user_config.github_pat}"), "markitdown": MARKITDOWN}))
    out = gen_copilot_mcp.render(src)
    assert "// Generated from the steer plugin's MCP config" in out
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
    src = tmp_path / "mcp.json"
    gh = _gh("${user_config.github_pat}")
    gh["headers"]["X-MCP-Toolsets"] = "issues"
    src.write_text(_claude({"github": gh}))
    out = gen_copilot_mcp.render(src)
    assert '"X-MCP-Toolsets": "issues"' in out
    assert "Authorization" not in out


def test_render_passes_through_unmapped_placeholder(tmp_path: Path):
    # A placeholder outside SIGN_IN is carried through unchanged. Covers both
    # placeholder shapes the regex accepts: a bare env var and a dotted user-config reference.
    src = tmp_path / "mcp.json"
    src.write_text(_claude({"svc": {"command": "x", "args": ["${OTHER}", "${user_config.other}"]}}))
    out = gen_copilot_mcp.render(src)
    assert "${OTHER}" in out
    assert "${user_config.other}" in out


def test_render_cli_is_strict_json_without_the_pat(tmp_path: Path):
    src = tmp_path / "mcp.json"
    gh = _gh("${user_config.github_pat}")
    gh["headers"]["X-MCP-Toolsets"] = "issues"
    src.write_text(_claude({"github": gh, "markitdown": MARKITDOWN}))
    servers = json.loads(gen_copilot_mcp.render_cli(src))["mcpServers"]
    assert servers["github"] == {**GITHUB, "headers": {"X-MCP-Toolsets": "issues"}}
    assert servers["markitdown"] == MARKITDOWN


def _gate(tmp_path: Path, monkeypatch) -> Path:
    src = tmp_path / ".claude-plugin" / "mcp.json"
    src.parent.mkdir()
    src.write_text(_claude({"github": _gh("${user_config.github_pat}"), "markitdown": MARKITDOWN}))
    vscode = tmp_path / "vscode-mcp.json"
    cli = tmp_path / ".github" / "mcp.json"
    cli.parent.mkdir()
    vscode.write_text(gen_copilot_mcp.render(src), encoding="utf-8")
    cli.write_text(gen_copilot_mcp.render_cli(src), encoding="utf-8")
    monkeypatch.setattr(check_copilot_mcp, "CLAUDE_MCP", src)
    monkeypatch.setattr(check_copilot_mcp, "VSCODE_MCP", vscode)
    monkeypatch.setattr(check_copilot_mcp, "COPILOT_CLI_MCP", cli)
    return tmp_path


def test_gate_ok_then_drift(tmp_path: Path, monkeypatch):
    root = _gate(tmp_path, monkeypatch)
    assert check_copilot_mcp.main() == 0
    vscode = root / "vscode-mcp.json"
    vscode.write_text(vscode.read_text() + "  // tampered\n", encoding="utf-8")
    assert check_copilot_mcp.main() == 1


def test_gate_catches_cli_drift(tmp_path: Path, monkeypatch):
    root = _gate(tmp_path, monkeypatch)
    (root / ".github" / "mcp.json").write_text("{}\n", encoding="utf-8")
    assert check_copilot_mcp.main() == 1


def test_gate_rejects_a_plugin_root_mcp_json(tmp_path: Path, monkeypatch):
    # The Copilot CLI loads a plugin-root .mcp.json ahead of the manifest's
    # mcpServers, so a Claude config there reaches it with an unresolvable PAT.
    root = _gate(tmp_path, monkeypatch)
    (root / ".mcp.json").write_text("{}", encoding="utf-8")
    assert check_copilot_mcp.main() == 1


def test_real_plugin_in_sync(monkeypatch):
    from conftest import REPO_ROOT

    for name in ("CLAUDE_MCP", "VSCODE_MCP", "COPILOT_CLI_MCP"):
        monkeypatch.setattr(check_copilot_mcp, name, REPO_ROOT / getattr(check_copilot_mcp, name))
    assert check_copilot_mcp.main() == 0
    assert "${input:" not in (REPO_ROOT / check_copilot_mcp.VSCODE_MCP).read_text()
    assert "${user_config." not in (REPO_ROOT / check_copilot_mcp.COPILOT_CLI_MCP).read_text()
