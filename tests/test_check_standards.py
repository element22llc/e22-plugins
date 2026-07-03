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


def test_enumeration_drift_skill_count_and_buckets_clean(monkeypatch, tmp_path: Path):
    # CROSS-SURFACE.md carries a **Skills** (N) count and a §5 PO/Engineer bucket
    # partition; both must agree with the skills on disk.
    _patch_enum_sources(
        monkeypatch,
        tmp_path,
        rules=["00-a", "10-b"],
        claude="skills/ alpha, beta (no commands/",
        cross=(
            "(2 files)\n"
            "**Skills** (2)\n"
            "- **PO-appropriate:** `alpha`.\n"
            "- **Engineer-oriented (noise for POs):** `beta`.\n\n"
            "inject-standards.sh\n"
        ),
    )
    monkeypatch.setattr(
        check_standards, "_sessionstart_hook_basenames", lambda: {"inject-standards.sh"}
    )
    errors: list[str] = []
    check_standards.check_enumeration_drift(errors, {"alpha", "beta"})
    assert errors == []


def test_enumeration_drift_catches_skill_count_and_bucket_faults(monkeypatch, tmp_path: Path):
    # Wrong count, an omitted skill, a bucket naming a non-skill, and a skill in
    # both buckets are each reported. This is the drift that shipped as "22" when
    # /steer:help (the 23rd skill) landed.
    _patch_enum_sources(
        monkeypatch,
        tmp_path,
        rules=["00-a", "10-b"],
        claude="skills/ alpha, beta, gamma (no commands/",
        cross=(
            "(2 files)\n"  # rule count OK
            "**Skills** (2)\n"  # WRONG: disk has 3
            "- **PO-appropriate:** `alpha`, `beta`.\n"
            "- **Engineer-oriented (noise):** `beta`, `delta`.\n\n"  # beta overlaps, delta unknown
            "inject-standards.sh\n"  # hook OK
        ),
    )
    monkeypatch.setattr(
        check_standards, "_sessionstart_hook_basenames", lambda: {"inject-standards.sh"}
    )
    errors: list[str] = []
    check_standards.check_enumeration_drift(errors, {"alpha", "beta", "gamma"})
    joined = "\n".join(errors)
    assert "skill count says (2)" in joined  # count mismatch
    assert "gamma" in joined  # omitted skill
    assert "delta" in joined  # non-skill named
    assert "both PO-appropriate" in joined  # overlap


def _write_skill(
    skills_dir: Path, name: str, frontmatter: str, body: str, *, extra: dict[str, str] | None = None
) -> None:
    d = skills_dir / name
    d.mkdir(parents=True)
    (d / "SKILL.md").write_text(f"---\nname: {name}\n{frontmatter}---\n{body}\n", encoding="utf-8")
    for fname, content in (extra or {}).items():
        (d / fname).write_text(content, encoding="utf-8")


def test_skill_script_grants_flags_uncovered_and_missing(monkeypatch, tmp_path: Path):
    skills = tmp_path / "skills"
    skills.mkdir()
    # (a) invokes a script, grant present and matching → clean
    _write_skill(
        skills,
        "granted",
        "allowed-tools:\n  - Bash(sh *scripts/scan-prereqs.sh*)\n",
        'Run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-prereqs.sh" .`',
    )
    # (b) invokes a script but no grant covers it → error
    _write_skill(
        skills,
        "ungranted",
        "allowed-tools:\n  - Bash(git status *)\n",
        'Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" auto x y --apply`',
    )
    # (c) invokes a script but declares no allowed-tools at all → error
    _write_skill(
        skills,
        "toolless",
        "",
        'Run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" a b`',
    )
    # (d) runs no plugin script → never flagged (even with no allowed-tools)
    _write_skill(skills, "prose", "", "This skill just talks about `mise run dev:setup`.")
    # (e) run step lives in a secondary body file (PROCEDURE.md), grants only in
    #     SKILL.md — must still be scanned (the adopt #266 regression).
    _write_skill(
        skills,
        "factored",
        "allowed-tools:\n  - Bash(git status *)\n",
        "See PROCEDURE.md.",
        extra={"PROCEDURE.md": 'Run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" x`'},
    )
    # (f) grant names the script but under the WRONG interpreter → not covered.
    _write_skill(
        skills,
        "wronginterp",
        "allowed-tools:\n  - Bash(sh *scripts/scaffold_reconcile.py*)\n",
        'Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" x`',
    )
    # (g) target-repo script (no ${CLAUDE_PLUGIN_ROOT}) → never a plugin grant.
    _write_skill(skills, "targetrepo", "", "Run `sh scripts/setup.sh` in the product repo.")

    monkeypatch.setattr(check_standards, "SKILLS_DIR", skills)
    errors: list[str] = []
    check_standards.check_skill_script_grants(errors)
    joined = "\n".join(errors)

    assert "skills/granted/SKILL.md" not in joined
    assert "skills/prose/SKILL.md" not in joined
    assert "skills/targetrepo/SKILL.md" not in joined
    assert "skills/ungranted/SKILL.md" in joined and "scaffold_reconcile.py" in joined
    assert "skills/toolless/SKILL.md" in joined and "template-reconcile.sh" in joined
    assert "skills/factored/SKILL.md" in joined and "template-reconcile.sh" in joined
    assert "skills/wronginterp/SKILL.md" in joined
    assert len(errors) == 4


def test_skill_script_grants_survives_malformed_frontmatter(monkeypatch, tmp_path: Path):
    """A script-running skill with unparseable frontmatter must not crash the check."""
    skills = tmp_path / "skills"
    skills.mkdir()
    d = skills / "broken"
    d.mkdir()
    # No closing frontmatter fence → parse_frontmatter returns (None, error).
    (d / "SKILL.md").write_text(
        'name: broken\nRun `sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" x`\n',
        encoding="utf-8",
    )
    monkeypatch.setattr(check_standards, "SKILLS_DIR", skills)
    errors: list[str] = []
    check_standards.check_skill_script_grants(errors)  # must not raise
    assert any("broken" in e for e in errors)
