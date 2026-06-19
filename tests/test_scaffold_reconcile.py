"""Tests for plugins/steer/scripts/scaffold-reconcile.py.

The helper performs additive, never-clobber merges of the non-Markdown scaffold
files (JSON + gitignore). The contract under test: existing values/lines are
never overwritten or removed, template-only content is added, check mode is
read-only, and an unparseable existing JSON file is refused (exit 3) rather than
clobbered. The module name has a hyphen and lives outside scripts/, so it is
loaded by path.
"""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

from conftest import REPO_ROOT

_SRC = REPO_ROOT / "plugins" / "steer" / "scripts" / "scaffold-reconcile.py"
_spec = importlib.util.spec_from_file_location("scaffold_reconcile", _SRC)
assert _spec and _spec.loader
sr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sr)


# --- JSON merge -----------------------------------------------------------


def test_json_apply_preserves_custom_and_adds_template(tmp_path: Path):
    existing = tmp_path / "settings.json"
    existing.write_text(
        json.dumps(
            {
                "permissions": {"allow": ["Bash(my-custom:*)"]},
                "enabledPlugins": {"my-team-plugin@somewhere": True},
            }
        ),
        encoding="utf-8",
    )
    template = tmp_path / "template.json"
    template.write_text(
        json.dumps(
            {
                "permissions": {
                    "allow": ["Bash(git add:*)"],
                    "deny": ["Bash(git push*--force*)"],
                },
                "enabledPlugins": {"security-guidance@claude-plugins-official": True},
            }
        ),
        encoding="utf-8",
    )

    rc = sr.main(["json", str(existing), str(template), "--apply"])
    assert rc == 0

    merged = json.loads(existing.read_text(encoding="utf-8"))
    # Custom entries preserved (never clobbered).
    assert "Bash(my-custom:*)" in merged["permissions"]["allow"]
    assert merged["enabledPlugins"]["my-team-plugin@somewhere"] is True
    # Template entries added.
    assert "Bash(git add:*)" in merged["permissions"]["allow"]
    assert merged["permissions"]["deny"] == ["Bash(git push*--force*)"]
    assert merged["enabledPlugins"]["security-guidance@claude-plugins-official"] is True


def test_json_never_overwrites_existing_scalar(tmp_path: Path):
    existing = tmp_path / "a.json"
    existing.write_text(json.dumps({"autoUpdate": False}), encoding="utf-8")
    template = tmp_path / "t.json"
    template.write_text(json.dumps({"autoUpdate": True}), encoding="utf-8")

    assert sr.main(["json", str(existing), str(template), "--apply"]) == 0
    assert json.loads(existing.read_text(encoding="utf-8"))["autoUpdate"] is False


def test_json_check_mode_is_read_only(tmp_path: Path, capsys):
    existing = tmp_path / "a.json"
    existing.write_text(json.dumps({"keep": 1}), encoding="utf-8")
    template = tmp_path / "t.json"
    template.write_text(json.dumps({"keep": 1, "add": 2}), encoding="utf-8")

    before = existing.read_text(encoding="utf-8")
    rc = sr.main(["json", str(existing), str(template)])
    out = capsys.readouterr().out
    assert rc == 0
    assert "add" in out  # delta reported
    assert existing.read_text(encoding="utf-8") == before  # not modified


def test_json_in_sync_is_silent(tmp_path: Path, capsys):
    existing = tmp_path / "a.json"
    template = tmp_path / "t.json"
    payload = json.dumps({"x": [1, 2], "y": {"z": 3}})
    existing.write_text(payload, encoding="utf-8")
    template.write_text(payload, encoding="utf-8")

    rc = sr.main(["json", str(existing), str(template)])
    assert rc == 0
    assert capsys.readouterr().out == ""


def test_invalid_existing_json_exits_3_without_clobber(tmp_path: Path):
    existing = tmp_path / "a.json"
    existing.write_text("{ not json", encoding="utf-8")
    template = tmp_path / "t.json"
    template.write_text(json.dumps({"a": 1}), encoding="utf-8")

    before = existing.read_text(encoding="utf-8")
    assert sr.main(["json", str(existing), str(template), "--apply"]) == 3
    assert existing.read_text(encoding="utf-8") == before


# --- gitignore merge ------------------------------------------------------


def test_gitignore_appends_missing_preserves_custom(tmp_path: Path):
    existing = tmp_path / ".gitignore"
    existing.write_text("node_modules/\n/my/custom/path\n", encoding="utf-8")
    template = tmp_path / "gitignore"
    template.write_text("# Dependencies\nnode_modules/\n.venv/\n", encoding="utf-8")

    assert sr.main(["gitignore", str(existing), str(template), "--apply"]) == 0
    lines = existing.read_text(encoding="utf-8").splitlines()
    assert "/my/custom/path" in lines  # preserved
    assert ".venv/" in lines  # added
    assert lines.count("node_modules/") == 1  # not duplicated


def test_gitignore_in_sync_is_silent(tmp_path: Path, capsys):
    existing = tmp_path / ".gitignore"
    existing.write_text("node_modules/\n.venv/\n", encoding="utf-8")
    template = tmp_path / "gitignore"
    template.write_text("node_modules/\n.venv/\n", encoding="utf-8")

    assert sr.main(["gitignore", str(existing), str(template)]) == 0
    assert capsys.readouterr().out == ""


# --- argument handling ----------------------------------------------------


def test_auto_infers_kind(tmp_path: Path):
    existing = tmp_path / ".gitignore"
    existing.write_text("a/\n", encoding="utf-8")
    template = tmp_path / "gitignore"
    template.write_text("a/\nb/\n", encoding="utf-8")
    assert sr.main(["auto", str(existing), str(template), "--apply"]) == 0
    assert "b/" in existing.read_text(encoding="utf-8").splitlines()


def test_auto_infers_worktreeinclude_as_line_based(tmp_path: Path):
    # .worktreeinclude is the same line-based ignore format as .gitignore, so
    # `auto` must route it through the additive line merge.
    existing = tmp_path / ".worktreeinclude"
    existing.write_text(".env\n", encoding="utf-8")
    template = tmp_path / "worktreeinclude"
    template.write_text(".env\n.env.local\n", encoding="utf-8")
    assert sr.main(["auto", str(existing), str(template), "--apply"]) == 0
    lines = existing.read_text(encoding="utf-8").splitlines()
    assert ".env.local" in lines  # added
    assert lines.count(".env") == 1  # not duplicated


def test_usage_error_on_bad_args(tmp_path: Path):
    assert sr.main(["json", "only-one-arg"]) == 2


def test_missing_template_exits_3(tmp_path: Path):
    existing = tmp_path / "a.json"
    existing.write_text("{}", encoding="utf-8")
    assert sr.main(["json", str(existing), str(tmp_path / "nope.json")]) == 3
