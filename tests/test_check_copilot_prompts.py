"""Tests for the Copilot prompt-file generator + sync gate.

The generator turns each user-invocable skill into a VS Code prompt file; the
gate fails when the committed artifacts drift from the skills. The real plugin's
artifacts must already be in sync.
"""

from __future__ import annotations

from pathlib import Path

import check_copilot_prompts
import gen_copilot_prompts
from conftest import REPO_ROOT


def _make_skill(
    skills_dir: Path, name: str, *, user_invocable: bool = True, hint: str = ""
) -> None:
    d = skills_dir / name
    d.mkdir(parents=True)
    fm = [
        "---",
        f"name: {name}",
        f"description: Does {name} things.",
        f"when_to_use: Use for {name}.",
    ]
    if hint:
        fm.append(f'argument-hint: "{hint}"')
    if not user_invocable:
        fm.append("user-invocable: false")
    fm += ["---", "", f"# {name}", ""]
    (d / "SKILL.md").write_text("\n".join(fm), encoding="utf-8")


def test_skips_internal_skills(tmp_path: Path):
    skills = tmp_path / "skills"
    _make_skill(skills, "alpha")
    _make_skill(skills, "internal", user_invocable=False)
    artifacts = gen_copilot_prompts.render_all(skills)
    assert set(artifacts) == {"steer-alpha.prompt.md"}


def test_capsule_has_mode_and_intent(tmp_path: Path):
    skills = tmp_path / "skills"
    _make_skill(skills, "alpha", hint="[x | y]")
    text = gen_copilot_prompts.render_all(skills)["steer-alpha.prompt.md"]
    assert text.startswith("---\nmode: agent\n")
    assert "/steer:alpha" in text
    assert "**Arguments.** [x | y]" in text
    assert ".github/copilot-instructions.md" in text


def test_gate_detects_drift(tmp_path: Path, monkeypatch):
    skills = tmp_path / "skills"
    out = tmp_path / "prompts"
    _make_skill(skills, "alpha")
    gen_copilot_prompts.main(["--write", "--skills-dir", str(skills), "--out-dir", str(out)])
    # Point the gate's module-level paths at the temp tree, then mutate an artifact.
    monkeypatch.setattr(check_copilot_prompts, "SKILLS_DIR", skills)
    monkeypatch.setattr(check_copilot_prompts, "PROMPTS_DIR", out)
    assert check_copilot_prompts.main() == 0
    (out / "steer-alpha.prompt.md").write_text("tampered\n", encoding="utf-8")
    assert check_copilot_prompts.main() == 1


def test_real_plugin_prompts_in_sync():
    # The committed artifacts under templates/github/prompts must match skills/.
    import os

    cwd = Path.cwd()
    os.chdir(REPO_ROOT)
    try:
        assert check_copilot_prompts.main() == 0
    finally:
        os.chdir(cwd)
