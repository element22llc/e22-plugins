"""Tests for scripts/check_plugin.py.

The real plugin must pass cleanly, and each validator must catch its violation
on a synthetic minimal plugin built in a tmp dir.
"""

from __future__ import annotations

import json
from pathlib import Path

import check_plugin
from conftest import REPO_ROOT

REAL_PLUGIN = REPO_ROOT / "plugins" / "e22-standards"


def _make_plugin(tmp_path: Path) -> Path:
    """Build a minimal, valid plugin tree and return its root."""
    root = tmp_path / "plugin"
    (root / ".claude-plugin").mkdir(parents=True)
    (root / ".claude-plugin" / "plugin.json").write_text(
        json.dumps({"name": "demo", "version": "0.1.0"}), encoding="utf-8"
    )
    skill_dir = root / "skills" / "demo-skill"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\n"
        "name: demo-skill\n"
        "description: A demo skill.\n"
        "when_to_use: Use when demonstrating.\n"
        "---\n\n# Demo\n",
        encoding="utf-8",
    )
    cmd_dir = root / "commands"
    cmd_dir.mkdir(parents=True)
    (cmd_dir / "demo-skill.md").write_text(
        "---\ndescription: Run the demo skill.\n---\n\nRun demo-skill.\n",
        encoding="utf-8",
    )
    (root / "rules").mkdir(parents=True)
    return root


# --- frontmatter parsing -------------------------------------------------


def test_parse_frontmatter_valid():
    fm, err = check_plugin.parse_frontmatter("---\nname: x\ndescription: y\n---\nbody")
    assert err is None
    assert fm == {"name": "x", "description": "y"}


def test_parse_frontmatter_missing():
    fm, err = check_plugin.parse_frontmatter("# no frontmatter\n")
    assert fm is None and err is not None


def test_parse_frontmatter_unterminated():
    fm, err = check_plugin.parse_frontmatter("---\nname: x\nno closing fence\n")
    assert fm is None and "unterminated" in err


def test_parse_frontmatter_not_mapping():
    fm, err = check_plugin.parse_frontmatter("---\n- just\n- a list\n---\n")
    assert fm is None and "not a mapping" in err


# --- whole-plugin checks on a synthetic tree -----------------------------


def test_minimal_plugin_is_clean(tmp_path: Path):
    assert check_plugin.run_checks(_make_plugin(tmp_path)) == []


def test_missing_when_to_use_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: demo-skill\ndescription: A demo skill.\n---\n\n# Demo\n",
        encoding="utf-8",
    )
    errors = check_plugin.run_checks(root)
    assert any("when_to_use" in e for e in errors)


def test_skill_name_mismatch_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: wrong-name\ndescription: d\nwhen_to_use: w\n---\n",
        encoding="utf-8",
    )
    errors = check_plugin.run_checks(root)
    assert any("does not match" in e for e in errors)


def test_placeholder_detected(tmp_path: Path):
    root = _make_plugin(tmp_path)
    (root / "rules" / "00-x.md").write_text("# Rule\n\nTODO: finish this.\n", encoding="utf-8")
    errors = check_plugin.run_checks(root)
    assert any("TODO" in e for e in errors)


def test_broken_link_detected(tmp_path: Path):
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: demo-skill\ndescription: d\nwhen_to_use: w\n---\n\n"
        "See [missing](./does-not-exist.md).\n",
        encoding="utf-8",
    )
    errors = check_plugin.run_checks(root)
    assert any("broken relative link" in e for e in errors)


def test_external_and_var_links_are_skipped(tmp_path: Path):
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: demo-skill\ndescription: d\nwhen_to_use: w\n---\n\n"
        "[web](https://example.com) [runtime](${CLAUDE_PLUGIN_ROOT}/x.md) [a](#anchor)\n",
        encoding="utf-8",
    )
    assert check_plugin.run_checks(root) == []


def test_command_without_skill_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    (root / "commands" / "orphan.md").write_text(
        "---\ndescription: Orphan command.\n---\n\nRun orphan.\n", encoding="utf-8"
    )
    errors = check_plugin.run_checks(root)
    assert any("has no matching skill" in e for e in errors)


def test_missing_plugin_json_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    (root / ".claude-plugin" / "plugin.json").unlink()
    errors = check_plugin.run_checks(root)
    assert any("plugin.json is missing" in e for e in errors)


# --- integration: the real plugin is clean -------------------------------


def test_real_plugin_passes():
    assert check_plugin.run_checks(REAL_PLUGIN) == []
