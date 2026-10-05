"""Tests for scripts/check_eval_env.py."""

from __future__ import annotations

import json
from pathlib import Path

import check_eval_env as cee


def _env(tmp_path: Path, **extra: str) -> dict[str, str]:
    return {"CLAUDE_CONFIG_DIR": str(tmp_path), **extra}


def _settings(tmp_path: Path, name: str, data: object) -> None:
    (tmp_path / name).write_text(json.dumps(data), encoding="utf-8")


def test_clean_environment_passes(tmp_path: Path) -> None:
    _settings(tmp_path, "settings.json", {"env": {"ENABLE_TOOL_SEARCH": "true"}})
    assert cee.main(_env(tmp_path)) == 0


def test_shell_variable_fails(tmp_path: Path, capsys) -> None:
    assert cee.main(_env(tmp_path, ANTHROPIC_BASE_URL="http://127.0.0.1:8787")) == 1
    assert "shell environment" in capsys.readouterr().err


def test_user_settings_env_fails(tmp_path: Path, capsys) -> None:
    _settings(tmp_path, "settings.json", {"env": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8787"}})
    assert cee.main(_env(tmp_path)) == 1
    assert "settings.json env" in capsys.readouterr().err


def test_local_settings_env_fails(tmp_path: Path) -> None:
    _settings(tmp_path, "settings.local.json", {"env": {"ANTHROPIC_BASE_URL": "http://proxy"}})
    assert cee.main(_env(tmp_path)) == 1


def test_override_allows_a_trusted_gateway(tmp_path: Path) -> None:
    env = _env(tmp_path, ANTHROPIC_BASE_URL="https://gateway", STEER_EVALS_ALLOW_BASE_URL="1")
    assert cee.main(env) == 0


def test_unreadable_settings_are_ignored(tmp_path: Path) -> None:
    (tmp_path / "settings.json").write_text("{not json", encoding="utf-8")
    _settings(tmp_path, "settings.local.json", ["not", "a", "dict"])
    assert cee.main(_env(tmp_path)) == 0
