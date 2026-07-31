"""Tests for scripts/check_plugin.py.

The real plugin must pass cleanly, and each validator must catch its violation
on a synthetic minimal plugin built in a tmp dir.
"""

from __future__ import annotations

import json
from pathlib import Path

import check_plugin
from conftest import REPO_ROOT

REAL_PLUGIN = REPO_ROOT / "plugins" / "steer"


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


def test_description_over_listing_cap_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    # description + when_to_use combined exceeds the skill-listing cap.
    over = "x" * (check_plugin.SKILL_LISTING_CHAR_CAP + 1)
    skill.write_text(
        f"---\nname: demo-skill\ndescription: {over}\nwhen_to_use: w\n---\n",
        encoding="utf-8",
    )
    errors = check_plugin.run_checks(root)
    assert any("skill-listing cap" in e for e in errors)


def test_description_at_listing_cap_passes(tmp_path: Path):
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    # Exactly at the cap (description + when_to_use) is allowed.
    desc = "x" * (check_plugin.SKILL_LISTING_CHAR_CAP - 1)
    skill.write_text(
        f"---\nname: demo-skill\ndescription: {desc}\nwhen_to_use: w\n---\n\n# Demo\n",
        encoding="utf-8",
    )
    assert check_plugin.run_checks(root) == []


def test_unquoted_scalar_with_comment_marker_fails(tmp_path: Path):
    """A plain scalar containing ' #' is silently truncated by YAML — the real
    `work` skill shipped this way, losing 471 of 546 chars of trigger text."""
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: demo-skill\ndescription: A demo skill.\n"
        'when_to_use: Use when asked ("work on #123") and for --hotfix too.\n'
        "---\n\n# Demo\n",
        encoding="utf-8",
    )
    errors = check_plugin.run_checks(root)
    assert any("silently discards the rest" in e for e in errors)


def test_block_scalar_with_comment_marker_passes(tmp_path: Path):
    """A '>-' folded block treats '#' as literal content — the sanctioned fix."""
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: demo-skill\ndescription: A demo skill.\n"
        'when_to_use: >-\n  Use when asked ("work on #123") and for --hotfix too.\n'
        "---\n\n# Demo\n",
        encoding="utf-8",
    )
    assert check_plugin.run_checks(root) == []


def test_quoted_scalar_with_comment_marker_passes(tmp_path: Path):
    """Quoting is the other sanctioned fix; '#' inside quotes is content."""
    root = _make_plugin(tmp_path)
    skill = root / "skills" / "demo-skill" / "SKILL.md"
    skill.write_text(
        "---\nname: demo-skill\ndescription: A demo skill.\n"
        "when_to_use: \"Use when asked ('work on #123') and for --hotfix too.\"\n"
        "---\n\n# Demo\n",
        encoding="utf-8",
    )
    assert check_plugin.run_checks(root) == []


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


def test_missing_plugin_json_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    (root / ".claude-plugin" / "plugin.json").unlink()
    errors = check_plugin.run_checks(root)
    assert any("plugin.json is missing" in e for e in errors)


# --- Copilot manifest version sync ---------------------------------------


def _add_copilot_plugin_manifest(root: Path, version: str) -> Path:
    manifest = root / ".github" / "plugin" / "plugin.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        json.dumps({"name": "demo", "version": version, "skills": "skills/"}),
        encoding="utf-8",
    )
    return manifest


def test_copilot_manifest_version_match_is_clean(tmp_path: Path):
    root = _make_plugin(tmp_path)  # source-of-truth version is 0.1.0
    _add_copilot_plugin_manifest(root, "0.1.0")
    assert check_plugin.run_checks(root) == []


def test_copilot_manifest_version_drift_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)  # source-of-truth version is 0.1.0
    _add_copilot_plugin_manifest(root, "0.0.9")
    errors = check_plugin.run_checks(root)
    assert any("Copilot manifest drifted" in e for e in errors)


# --- integration: the real plugin is clean -------------------------------


def test_real_plugin_passes():
    assert check_plugin.run_checks(REAL_PLUGIN) == []


# --- migration-ledger version keys ---------------------------------------


def _write_ledger(root: Path, *headings: str) -> None:
    ref = root / "templates" / "reference"
    ref.mkdir(parents=True, exist_ok=True)
    body = "# Ledger\n\n## Entries\n\n"
    for heading in headings:
        body += f"{heading}\n\n- **What & why:** a transform.\n\n"
    (ref / "MIGRATIONS.md").write_text(body, encoding="utf-8")


def test_migration_versions_real_plugin_clean():
    errors: list[str] = []
    check_plugin.check_migration_versions(REAL_PLUGIN, errors)
    assert errors == []


def test_migration_versions_accepts_unreleased_heading(tmp_path: Path):
    """`[Unreleased]` is the authoring state — an entry lands before its release."""
    root = _make_plugin(tmp_path)
    _write_ledger(root, "### [Unreleased] — a pending transform")
    errors: list[str] = []
    check_plugin.check_migration_versions(root, errors)
    assert errors == []


def test_migration_versions_accepts_released_and_older(tmp_path: Path):
    root = _make_plugin(tmp_path)  # plugin.json version is 0.1.0
    _write_ledger(root, "### v0.1.0 — the current release", "### v0.0.9 — an older one")
    errors: list[str] = []
    check_plugin.check_migration_versions(root, errors)
    assert errors == []


def test_migration_versions_rejects_guessed_next_version(tmp_path: Path):
    """A heading ahead of plugin.json is a guess about a release that has not happened.

    Keyed below the release it really ships in, the entry reads as "at or below the
    stamp" for every repo stamped in between, so /steer:sync SKIPS it silently.
    """
    root = _make_plugin(tmp_path)  # 0.1.0
    _write_ledger(root, "### v0.2.0 — a guessed next minor")
    errors: list[str] = []
    check_plugin.check_migration_versions(root, errors)
    assert len(errors) == 1
    assert "guessed next version" in errors[0]
    assert "[Unreleased]" in errors[0]


def test_migration_versions_rejects_guessed_major_and_patch(tmp_path: Path):
    root = _make_plugin(tmp_path)  # 0.1.0
    _write_ledger(root, "### v1.0.0 — guessed major", "### v0.1.1 — guessed patch")
    errors: list[str] = []
    check_plugin.check_migration_versions(root, errors)
    assert len(errors) == 2


def test_migration_versions_ignores_entry_template_placeholder(tmp_path: Path):
    """The ledger's own copy-me template carries a literal `vX.Y.Z`, not a version."""
    root = _make_plugin(tmp_path)
    _write_ledger(root, "### vX.Y.Z — <one-line what>")
    errors: list[str] = []
    check_plugin.check_migration_versions(root, errors)
    assert errors == []


def test_migration_versions_no_ledger_is_silent(tmp_path: Path):
    root = _make_plugin(tmp_path)
    errors: list[str] = []
    check_plugin.check_migration_versions(root, errors)
    assert errors == []
