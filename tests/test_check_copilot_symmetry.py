"""Tests for the Copilot symmetry meta-gate.

The gate asserts every ``scripts/gen_copilot_*.py`` is wired into the
``gen:copilot`` mise task and every ``scripts/check_copilot_*.py`` into
``plugin-check``. The real repo must satisfy it; a synthetic unwired script must
trip it.
"""

from __future__ import annotations

from pathlib import Path

import check_copilot_symmetry


def test_real_repo_symmetric(monkeypatch):
    from conftest import REPO_ROOT

    monkeypatch.chdir(REPO_ROOT)
    assert check_copilot_symmetry.main() == 0


def test_unwired_generator_fails(tmp_path: Path, monkeypatch):
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    # A generator that no task references.
    (scripts / "gen_copilot_orphan.py").write_text("# orphan\n", encoding="utf-8")
    mise = tmp_path / "mise.toml"
    mise.write_text(
        '[tasks."gen:copilot"]\nrun = []\n[tasks.plugin-check]\nrun = []\n',
        encoding="utf-8",
    )
    monkeypatch.setattr(check_copilot_symmetry, "SCRIPTS_DIR", scripts)
    monkeypatch.setattr(check_copilot_symmetry, "MISE_TOML", mise)
    assert check_copilot_symmetry.main() == 1


def test_wired_generator_passes(tmp_path: Path, monkeypatch):
    scripts = tmp_path / "scripts"
    scripts.mkdir()
    (scripts / "gen_copilot_orphan.py").write_text("# orphan\n", encoding="utf-8")
    mise = tmp_path / "mise.toml"
    mise.write_text(
        '[tasks."gen:copilot"]\n'
        'run = ["uv run python scripts/gen_copilot_orphan.py --write"]\n'
        "[tasks.plugin-check]\nrun = []\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(check_copilot_symmetry, "SCRIPTS_DIR", scripts)
    monkeypatch.setattr(check_copilot_symmetry, "MISE_TOML", mise)
    assert check_copilot_symmetry.main() == 0
