"""Tests for the Copilot hook parity gate.

Copilot ports only a subset of steer's hooks, so this is a referential-integrity
+ contract gate, not full equality: every script the Copilot manifest invokes
must exist and be wired into hooks.json, and each Copilot hook must carry
``STEER_HOOK_TARGET=copilot`` and be fail-open (``|| true``). The real plugin
must satisfy all three.
"""

from __future__ import annotations

import json
from pathlib import Path

import check_copilot_hooks


def _claude_hooks(*scripts: str) -> str:
    entries = [
        {
            "matcher": "Bash",
            "hooks": [{"type": "command", "command": f'sh "${{CLAUDE_PLUGIN_ROOT}}/hooks/{s}"'}],
        }
        for s in scripts
    ]
    return json.dumps({"hooks": {"PreToolUse": entries}})


def _copilot_hooks(*specs: dict) -> str:
    entries = [
        {
            "type": "command",
            "matcher": "Bash",
            "bash": spec["bash"],
            "timeoutSec": 10,
        }
        for spec in specs
    ]
    return json.dumps({"version": 1, "hooks": {"PreToolUse": entries}})


def _bash(script: str, *, target: bool = True, fail_open: bool = True) -> dict:
    prefix = "STEER_HOOK_TARGET=copilot " if target else ""
    suffix = " || true" if fail_open else ""
    return {"bash": f'{prefix}sh "${{CLAUDE_PLUGIN_ROOT}}/hooks/{script}"{suffix}'}


def _point(monkeypatch, tmp_path: Path, claude: str, copilot: str, scripts: list[str]) -> None:
    hooks_dir = tmp_path / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)
    for s in scripts:
        (hooks_dir / s).write_text("#!/bin/sh\n", encoding="utf-8")
    (hooks_dir / "hooks.json").write_text(claude, encoding="utf-8")
    (hooks_dir / "copilot-hooks.json").write_text(copilot, encoding="utf-8")
    monkeypatch.setattr(check_copilot_hooks, "HOOKS_JSON", hooks_dir / "hooks.json")
    monkeypatch.setattr(check_copilot_hooks, "COPILOT_HOOKS_JSON", hooks_dir / "copilot-hooks.json")
    monkeypatch.setattr(check_copilot_hooks, "HOOKS_DIR", hooks_dir)


def test_in_sync(tmp_path, monkeypatch):
    _point(
        monkeypatch,
        tmp_path,
        _claude_hooks("check-version-pins.sh", "check-bash-actions.sh"),
        _copilot_hooks(_bash("check-version-pins.sh"), _bash("check-bash-actions.sh")),
        ["check-version-pins.sh", "check-bash-actions.sh"],
    )
    assert check_copilot_hooks.main() == 0


def test_script_not_in_claude_side_fails(tmp_path, monkeypatch):
    # Copilot points at a script the Claude hooks.json dropped/renamed.
    _point(
        monkeypatch,
        tmp_path,
        _claude_hooks("check-version-pins.sh"),
        _copilot_hooks(_bash("check-bash-actions.sh")),
        ["check-version-pins.sh", "check-bash-actions.sh"],
    )
    assert check_copilot_hooks.main() == 1


def test_script_file_absent_fails(tmp_path, monkeypatch):
    _point(
        monkeypatch,
        tmp_path,
        _claude_hooks("check-bash-actions.sh"),
        _copilot_hooks(_bash("check-bash-actions.sh")),
        [],  # no script file on disk
    )
    assert check_copilot_hooks.main() == 1


def test_missing_target_flag_fails(tmp_path, monkeypatch):
    _point(
        monkeypatch,
        tmp_path,
        _claude_hooks("check-bash-actions.sh"),
        _copilot_hooks(_bash("check-bash-actions.sh", target=False)),
        ["check-bash-actions.sh"],
    )
    assert check_copilot_hooks.main() == 1


def test_not_fail_open_fails(tmp_path, monkeypatch):
    _point(
        monkeypatch,
        tmp_path,
        _claude_hooks("check-bash-actions.sh"),
        _copilot_hooks(_bash("check-bash-actions.sh", fail_open=False)),
        ["check-bash-actions.sh"],
    )
    assert check_copilot_hooks.main() == 1


def test_real_plugin_in_sync(monkeypatch):
    from conftest import REPO_ROOT

    for attr in ("HOOKS_JSON", "COPILOT_HOOKS_JSON", "HOOKS_DIR"):
        monkeypatch.setattr(
            check_copilot_hooks, attr, REPO_ROOT / getattr(check_copilot_hooks, attr)
        )
    assert check_copilot_hooks.main() == 0
