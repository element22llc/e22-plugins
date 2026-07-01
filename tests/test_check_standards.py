"""Tests for scripts/check_standards.py."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_standards  # noqa: E402


def test_real_standards_pass():
    """The live plugin satisfies every standards-consistency check."""
    errors: list[str] = []
    check_standards.run_checks(errors)
    assert errors == [], "\n".join(errors)


def test_registry_loads_expected_keys():
    errors: list[str] = []
    reg = check_standards.load_registry(errors)
    assert errors == []
    for key in ("feature_status", "question_status", "issue_state", "next_action", "adr_status"):
        assert reg.get(key), f"registry missing {key}"
    assert "cancelled" in reg["issue_state"]
    assert "draft" in reg["feature_status"]
    assert "proposed" not in reg["feature_status"]


def test_is_subcommand_leading():
    f = check_standards._is_subcommand_leading
    assert f("[start | resume | status | finish] [#issue ...]") is True
    assert f("[capture | triage | brainstorm] [#issue | feature-id]") is True
    # positional default (feature-id) → not subcommand-leading
    assert f("[feature-id | approve <feature-id> | validate [feature-id]]") is False
    # `<op>` sublayer → not subcommand-leading
    assert f("[issue <op> | pull | push] [#issue | feature-id]") is False
    assert f("[idea or product description]") is False


def test_hint_subcommands():
    f = check_standards._hint_subcommands
    assert f("[start | resume | status | finish] [#issue ...]") == {
        "start",
        "resume",
        "status",
        "finish",
    }
    # placeholders (feature-id) excluded; `approve <feature-id>` keeps the verb
    assert f("[feature-id | approve <feature-id> | validate [feature-id | --all]]") == {
        "approve",
        "validate",
    }
    # free-text placeholder yields no subcommands
    assert f("[idea or product description]") == set()


def test_strip_category():
    f = check_standards._strip_category
    assert f("Blocking now (L2)") == "Blocking now"
    assert f("Complete — no action required (L7)") == "Complete"
    assert f("Required before initial production") == "Required before initial production"


def test_deprecated_next_action_regex():
    rx = check_standards._DEPRECATED_NEXT_ACTION
    assert rx.search("Required before production")  # the removed category
    assert not rx.search("Required before production release")  # the new one
    assert not rx.search("Required before initial production")


# --- check 10: enumeration-drift guard ---


def test_sessionstart_hook_basenames_matches_hooks_json():
    """The parser pins the live SessionStart roster (7 hooks)."""
    names = check_standards._sessionstart_hook_basenames()
    assert "surface-faults.sh" in names
    assert "inject-standards.sh" in names
    assert "check-graduation.sh" in names
    assert len(names) == 7  # bump if a SessionStart hook is added/removed


def test_token_present_respects_word_boundary():
    f = check_standards._token_present
    assert f("spec-scaffold", "uses spec-scaffold here")
    # `spec` must NOT be satisfied by `spec-scaffold`
    assert not f("spec", "only spec-scaffold is mentioned")
    assert f("spec", "the spec is ready")


def _patch_enum_sources(monkeypatch, tmp_path: Path, *, rules, claude, cross):
    """Point the guard's file/dir globals at temp fixtures."""
    rules_dir = tmp_path / "rules"
    rules_dir.mkdir()
    for stem in rules:
        (rules_dir / f"{stem}.md").write_text("x", encoding="utf-8")
    claude_md = tmp_path / "CLAUDE.md"
    claude_md.write_text(claude, encoding="utf-8")
    cross_md = tmp_path / "CROSS-SURFACE.md"
    cross_md.write_text(cross, encoding="utf-8")
    monkeypatch.setattr(check_standards, "RULES_DIR", rules_dir)
    monkeypatch.setattr(check_standards, "CLAUDE_MD", claude_md)
    monkeypatch.setattr(check_standards, "CROSS_SURFACE", cross_md)


def test_enumeration_drift_clean(monkeypatch, tmp_path: Path):
    _patch_enum_sources(
        monkeypatch,
        tmp_path,
        rules=["00-a", "10-b"],
        claude="skills/ alpha, beta (no commands/",
        cross="(2 files)\ninject-standards.sh",
    )
    monkeypatch.setattr(
        check_standards, "_sessionstart_hook_basenames", lambda: {"inject-standards.sh"}
    )
    errors: list[str] = []
    check_standards.check_enumeration_drift(errors, {"alpha", "beta"})
    assert errors == []


def test_enumeration_drift_catches_each_surface(monkeypatch, tmp_path: Path):
    # The /steer:standards rule enumeration was removed (#276); the guard still
    # covers the CLAUDE.md skills/ list and the CROSS-SURFACE.md rule count + hook
    # roster.
    _patch_enum_sources(
        monkeypatch,
        tmp_path,
        rules=["00-a", "10-b"],
        claude="skills/ alpha (no commands/",  # missing beta
        cross="(1 files)\n",  # wrong count + missing hook
    )
    monkeypatch.setattr(
        check_standards, "_sessionstart_hook_basenames", lambda: {"inject-standards.sh"}
    )
    errors: list[str] = []
    check_standards.check_enumeration_drift(errors, {"alpha", "beta"})
    joined = "\n".join(errors)
    assert "CLAUDE.md" in joined and "beta" in joined
    assert "(1 files)" in joined  # count mismatch reported
    assert "inject-standards.sh" in joined  # missing hook reported
