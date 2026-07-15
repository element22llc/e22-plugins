"""Tests for the Copilot custom-agent generator + sync gate.

The generator turns each steer subagent (``plugins/steer/agents/*.md``) into a VS
Code custom-agent file (``.github/agents/<name>.agent.md``); the gate fails when
the committed artifacts drift from the subagents. The real plugin's artifacts must
already be in sync.
"""

from __future__ import annotations

from pathlib import Path

import check_copilot_agents
import gen_copilot_agents
from conftest import REPO_ROOT


def _make_agent(agents_dir: Path, name: str, *, tools: str = "Read, Grep, Glob") -> None:
    agents_dir.mkdir(parents=True, exist_ok=True)
    fm = [
        "---",
        f"name: {name}",
        f"description: Does {name} review.",
        f"tools: {tools}",
        "model: inherit",
        "---",
        "",
        f"# {name}",
        "",
        f"You are the {name}. Invoked by /steer:audit to check one slice.",
    ]
    (agents_dir / f"{name}.md").write_text("\n".join(fm), encoding="utf-8")


def test_renders_agent_with_mapped_tools_and_rewritten_refs(tmp_path: Path):
    agents = tmp_path / "agents"
    _make_agent(agents, "steer-reviewer")
    text = gen_copilot_agents.render_all(agents)["steer-reviewer.agent.md"]
    # Read/Grep/Glob map to Copilot read-only tool sets; no edit/run tools leak in.
    assert "codebase" in text
    assert "search" in text
    assert "editFiles" not in text
    assert "runCommands" not in text
    # model: inherit is dropped (agent inherits the picker's model).
    assert "model:" not in text.split("---")[1]
    # /steer: cross-references are rewritten to the /steer- prompt names.
    assert "/steer-audit" in text
    assert "/steer:audit" not in text


def test_gate_detects_drift(tmp_path: Path, monkeypatch):
    agents = tmp_path / "agents"
    out = tmp_path / "out"
    _make_agent(agents, "steer-reviewer")
    gen_copilot_agents.main(["--write", "--agents-dir", str(agents), "--out-dir", str(out)])
    monkeypatch.setattr(check_copilot_agents, "AGENTS_DIR", agents)
    monkeypatch.setattr(check_copilot_agents, "OUT_DIR", out)
    assert check_copilot_agents.main() == 0
    # Mutate a committed artifact → drift detected.
    (out / "steer-reviewer.agent.md").write_text("tampered\n", encoding="utf-8")
    assert check_copilot_agents.main() == 1


def test_real_plugin_agents_in_sync():
    """The committed artifacts must match the plugin's subagents."""
    monkey_root = REPO_ROOT
    expected = gen_copilot_agents.render_all(monkey_root / gen_copilot_agents.AGENTS_DIR)
    out_dir = monkey_root / gen_copilot_agents.OUT_DIR
    committed = {p.name: p.read_text(encoding="utf-8") for p in out_dir.glob("*.agent.md")}
    assert committed == expected
