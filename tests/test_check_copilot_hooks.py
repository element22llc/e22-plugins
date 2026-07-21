"""Tests for the Copilot hook generator + sync gate.

``gen_copilot_hooks.py`` renders ``plugins/steer/hooks/copilot-hooks.json`` from
``plugins/steer/hooks/hooks.json`` — porting the ``COPILOT_HOOKS`` subset into
Copilot's flat schema with ``STEER_HOOK_TARGET=copilot`` + fail-open ``|| true``.
The gate byte-compares the committed manifest against a fresh render and verifies
each referenced script exists on disk. The real plugin must be in sync.
"""

from __future__ import annotations

import json
from pathlib import Path

import check_copilot_hooks
import gen_copilot_hooks


def _claude_hooks(*scripts: str) -> str:
    """A hooks.json wiring each script under PreToolUse (bash-actions gets the
    broader Claude matcher so the generator's override is exercised)."""
    entries = []
    for s in scripts:
        matcher = "Bash|mcp__.*[Ii]ssue.*" if "bash-actions" in s else "Write|Edit"
        entries.append(
            {
                "matcher": matcher,
                "hooks": [
                    {
                        "type": "command",
                        "command": f'sh "${{CLAUDE_PLUGIN_ROOT}}/hooks/{s}"',
                        "timeout": 10,
                    }
                ],
            }
        )
    return json.dumps({"hooks": {"PreToolUse": entries}})


PORTED = ["check-version-pins.sh", "check-bash-actions.sh"]


def _point(monkeypatch, tmp_path: Path, claude: str, scripts: list[str]) -> Path:
    hooks_dir = tmp_path / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)
    for s in scripts:
        (hooks_dir / s).write_text("#!/bin/sh\n", encoding="utf-8")
    (hooks_dir / "hooks.json").write_text(claude, encoding="utf-8")
    monkeypatch.setattr(check_copilot_hooks, "HOOKS_JSON", hooks_dir / "hooks.json")
    monkeypatch.setattr(check_copilot_hooks, "COPILOT_HOOKS_JSON", hooks_dir / "copilot-hooks.json")
    monkeypatch.setattr(check_copilot_hooks, "HOOKS_DIR", hooks_dir)
    return hooks_dir


def test_render_shapes_copilot_manifest(tmp_path: Path):
    src = tmp_path / "hooks.json"
    src.write_text(_claude_hooks(*PORTED))
    doc = json.loads(gen_copilot_hooks.render(src))
    assert doc["version"] == 1
    hooks = doc["hooks"]["PreToolUse"]
    assert len(hooks) == 2
    pins, bash = hooks
    assert pins["matcher"] == "Write|Edit"  # no override
    assert bash["matcher"] == "Bash"  # override applied
    for h in hooks:
        assert h["bash"].startswith("STEER_HOOK_TARGET=copilot ")
        assert h["bash"].endswith("|| true")
        assert h["timeoutSec"] == 10


def test_gate_ok_then_drift(tmp_path: Path, monkeypatch):
    hooks_dir = _point(monkeypatch, tmp_path, _claude_hooks(*PORTED), PORTED)
    copilot = hooks_dir / "copilot-hooks.json"
    copilot.write_text(gen_copilot_hooks.render(hooks_dir / "hooks.json"), encoding="utf-8")
    assert check_copilot_hooks.main() == 0
    copilot.write_text(copilot.read_text().replace("Bash", "Bash|Tampered"), encoding="utf-8")
    assert check_copilot_hooks.main() == 1


def test_gate_missing_script_file_fails(tmp_path: Path, monkeypatch):
    # hooks.json wires both scripts (so render succeeds), but the .sh files are
    # absent on disk — the one property byte-equality alone can't catch.
    hooks_dir = _point(monkeypatch, tmp_path, _claude_hooks(*PORTED), [])
    (hooks_dir / "copilot-hooks.json").write_text(
        gen_copilot_hooks.render(hooks_dir / "hooks.json"), encoding="utf-8"
    )
    assert check_copilot_hooks.main() == 1


def test_gate_unwired_hook_fails(tmp_path: Path, monkeypatch):
    # hooks.json drops a script the COPILOT_HOOKS selection ports → render raises,
    # the gate reports it rather than crashing.
    hooks_dir = _point(monkeypatch, tmp_path, _claude_hooks("check-version-pins.sh"), PORTED)
    (hooks_dir / "copilot-hooks.json").write_text("{}", encoding="utf-8")
    assert check_copilot_hooks.main() == 1


def test_real_plugin_in_sync(monkeypatch):
    from conftest import REPO_ROOT

    for attr in ("HOOKS_JSON", "COPILOT_HOOKS_JSON", "HOOKS_DIR"):
        monkeypatch.setattr(
            check_copilot_hooks, attr, REPO_ROOT / getattr(check_copilot_hooks, attr)
        )
    assert check_copilot_hooks.main() == 0
