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
    # positional default (feature-id) -> not subcommand-leading
    assert f("[feature-id | approve <feature-id> | validate [feature-id]]") is False
    # `<op>` sublayer -> not subcommand-leading
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
    assert f("Complete - no action required (L7)") == "Complete"
    assert f("Required before initial production") == "Required before initial production"


def test_deprecated_next_action_regex():
    rx = check_standards._DEPRECATED_NEXT_ACTION
    assert rx.search("Required before production")  # the removed category
    assert not rx.search("Required before production release")  # the new one
    assert not rx.search("Required before initial production")


# --- check 10: enumeration-drift guard ---


def test_sessionstart_hook_basenames_matches_hooks_json():
    """The parser pins the live SessionStart roster (3 registrations since the
    session-checks.sh consolidation - the five checks it orchestrates are no
    longer registered individually)."""
    names = check_standards._sessionstart_hook_basenames()
    assert "inject-standards.sh" in names
    assert "session-checks.sh" in names
    assert "orient-session.sh" in names
    assert "surface-faults.sh" not in names  # orchestrated, not registered
    assert len(names) == 3  # bump if a SessionStart hook is added/removed


def test_session_subchecks_parses_the_orchestrator_roster():
    """The sub-checks are gated too: hooks.json names only `session-checks.sh`, so
    deriving the CROSS-SURFACE.md roster from registration alone left every child
    unenforced - the orchestrator tells authors to update that roster."""
    subs = check_standards._session_subchecks()
    assert "surface-faults.sh" in subs
    assert "check-worktree-trust.sh" in subs
    # The orchestrator itself is not one of its own children.
    assert "session-checks.sh" not in subs
    assert len(subs) == 6  # bump when a session sub-check is added/removed


def test_live_subcheck_roster_is_in_cross_surface():
    """Every sub-check the shipped orchestrator runs is named in CROSS-SURFACE.md."""
    subs = check_standards._session_subchecks()
    assert subs, "parser returned nothing - the roster gate would silently pass"
    text = check_standards.CROSS_SURFACE.read_text(encoding="utf-8")
    for name in sorted(subs):
        assert name in text, f"CROSS-SURFACE.md roster omits {name}"


def test_token_present_respects_word_boundary():
    f = check_standards._token_present
    assert f("spec-scaffold", "uses spec-scaffold here")
    # `spec` must NOT be satisfied by `spec-scaffold`
    assert not f("spec", "only spec-scaffold is mentioned")
    assert f("spec", "the spec is ready")


def _patch_enum_sources(monkeypatch, tmp_path: Path, *, rules, claude, cross, subchecks=()):
    """Point the guard's file/dir globals at temp fixtures.

    `subchecks` stubs the session-checks.sh roster; it defaults to empty so a test
    that does not care about it isn't measured against the real orchestrator.
    """
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
    monkeypatch.setattr(check_standards, "_session_subchecks", lambda: set(subchecks))


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


def test_enumeration_drift_catches_missing_subcheck(monkeypatch, tmp_path: Path):
    """An orchestrated sub-check missing from the roster is reported, and named as
    orchestrated rather than registered so the fix is unambiguous."""
    _patch_enum_sources(
        monkeypatch,
        tmp_path,
        rules=["00-a"],
        claude="skills/ alpha (no commands/",
        cross="(1 files)\ninject-standards.sh\ncheck-graduation.sh",
        subchecks=["check-graduation.sh", "check-newthing.sh"],
    )
    monkeypatch.setattr(
        check_standards, "_sessionstart_hook_basenames", lambda: {"inject-standards.sh"}
    )
    errors: list[str] = []
    check_standards.check_enumeration_drift(errors, {"alpha"})
    joined = "\n".join(errors)
    assert "check-newthing.sh" in joined
    assert "orchestrated by session-checks.sh" in joined
    assert "check-graduation.sh" not in joined  # already in the roster


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
    # (a) invokes a script, grant present and matching -> clean
    _write_skill(
        skills,
        "granted",
        "allowed-tools:\n  - Bash(sh *scripts/scan-prereqs.sh*)\n",
        'Run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-prereqs.sh" .`',
    )
    # (b) invokes a script but no grant covers it -> error
    _write_skill(
        skills,
        "ungranted",
        "allowed-tools:\n  - Bash(git status *)\n",
        'Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" auto x y --apply`',
    )
    # (c) invokes a script but declares no allowed-tools at all -> error
    _write_skill(
        skills,
        "toolless",
        "",
        'Run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" a b`',
    )
    # (d) runs no plugin script -> never flagged (even with no allowed-tools)
    _write_skill(skills, "prose", "", "This skill just talks about `mise run dev:setup`.")
    # (e) run step lives in a secondary body file (PROCEDURE.md), grants only in
    #     SKILL.md - must still be scanned (the adopt #266 regression).
    _write_skill(
        skills,
        "factored",
        "allowed-tools:\n  - Bash(git status *)\n",
        "See PROCEDURE.md.",
        extra={"PROCEDURE.md": 'Run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" x`'},
    )
    # (f) grant names the script but under the WRONG interpreter -> not covered.
    _write_skill(
        skills,
        "wronginterp",
        "allowed-tools:\n  - Bash(sh *scripts/scaffold_reconcile.py*)\n",
        'Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" x`',
    )
    # (g) target-repo script (no ${CLAUDE_PLUGIN_ROOT}) -> never a plugin grant.
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
    # No closing frontmatter fence -> parse_frontmatter returns (None, error).
    (d / "SKILL.md").write_text(
        'name: broken\nRun `sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" x`\n',
        encoding="utf-8",
    )
    monkeypatch.setattr(check_standards, "SKILLS_DIR", skills)
    errors: list[str] = []
    check_standards.check_skill_script_grants(errors)  # must not raise
    assert any("broken" in e for e in errors)


def _write_wf(root: Path, body: str) -> None:
    wf = root / "templates" / "github" / "workflows"
    wf.mkdir(parents=True, exist_ok=True)
    (wf / "dependabot-auto-merge.yml").write_text(body, encoding="utf-8")


_WF_WITH_SCOPES = """on: pull_request

permissions:
  contents: write
  pull-requests: write
  checks: read
  statuses: read

jobs:
  m:
    steps:
      - run: gh pr checks "$PR_URL" --watch --required --fail-fast
"""


_WF_WITHOUT_GH_PR_CHECKS = """on: push

permissions:
  contents: read

jobs:
  m:
    steps:
      - run: echo hi
"""


def test_gh_pr_checks_scopes_accepts_declared_scopes(monkeypatch, tmp_path: Path):
    _write_wf(tmp_path, _WF_WITH_SCOPES)
    monkeypatch.setattr(check_standards, "PLUGIN_ROOT", tmp_path)
    errors: list[str] = []
    check_standards.check_gh_pr_checks_scopes(errors)
    assert errors == []


def test_gh_pr_checks_scopes_catches_the_566_regression(monkeypatch, tmp_path: Path):
    """The pre-fix permissions block - the one that failed on the first Dependabot PR."""
    _write_wf(tmp_path, _WF_WITH_SCOPES.replace("  checks: read\n  statuses: read\n", ""))
    monkeypatch.setattr(check_standards, "PLUGIN_ROOT", tmp_path)
    errors: list[str] = []
    check_standards.check_gh_pr_checks_scopes(errors)
    assert len(errors) == 2
    assert any("`checks: read`" in e for e in errors)
    assert any("`statuses: read`" in e for e in errors)


def test_gh_pr_checks_scopes_ignores_workflows_that_do_not_run_it(monkeypatch, tmp_path: Path):
    _write_wf(tmp_path, _WF_WITHOUT_GH_PR_CHECKS)
    monkeypatch.setattr(check_standards, "PLUGIN_ROOT", tmp_path)
    errors: list[str] = []
    check_standards.check_gh_pr_checks_scopes(errors)
    assert errors == []


def test_parse_modes_defaults_owner_to_the_mode_name():
    f = check_standards._parse_modes
    assert f("init,adopt,sync") == {"init": "init", "adopt": "adopt", "sync": "sync"}
    assert f("default,capabilities=help") == {"default": "default", "capabilities": "help"}
    assert f("this-week, feature=explain") == {"this-week": "this-week", "feature": "explain"}


def _reachability_fixture(tmp_path: Path) -> tuple[Path, Path]:
    """A miniature v7 surface: two front doors, one absorbed skill, one gateway,
    one rule-reached skill - enough for every verdict check 14 can reach."""
    skills = tmp_path / "skills"
    skills.mkdir()
    _write_skill(skills, "setup", "", "<!-- steer:modes init,protect -->")
    _write_skill(skills, "status", "", "<!-- steer:modes this-week,feature=explain -->")
    for name in ("init", "protect", "explain", "gateway", "ruled"):
        _write_skill(skills, name, "user-invocable: false\n", "internal")
    rules = tmp_path / "rules"
    rules.mkdir()
    (rules / "53-automation.md").write_text(
        "Scaffold loops with `/steer:ruled`.\n", encoding="utf-8"
    )
    return skills, rules


def _run_reachability(monkeypatch, skills: Path, rules: Path, **overrides) -> list[str]:
    monkeypatch.setattr(check_standards, "SKILLS_DIR", skills)
    monkeypatch.setattr(check_standards, "RULES_DIR", rules)
    monkeypatch.setattr(
        check_standards, "GATEWAY_SKILLS", overrides.get("gateways", {"gateway": "called by setup"})
    )
    monkeypatch.setattr(
        check_standards, "RULE_REACHED_SKILLS", overrides.get("ruled", {"ruled": "rule 53"})
    )
    # The MODEL_ONLY cross-check reads the real plugin script; point it at the
    # fixture's own copy so the two sets agree under the patched RULE_REACHED set.
    plugin = skills.parent
    (plugin / "scripts").mkdir(exist_ok=True)
    names = " ".join(sorted(overrides.get("ruled", {"ruled": ""})))
    (plugin / "scripts/scan-invocations.sh").write_text(
        f'MODEL_ONLY=" {overrides.get("model_only", names)} "\n', encoding="utf-8"
    )
    monkeypatch.setattr(check_standards, "PLUGIN_ROOT", plugin)
    errors: list[str] = []
    check_standards.check_internal_skill_reachability(errors, {d.name for d in skills.iterdir()})
    return errors


def test_reachability_clean_surface(monkeypatch, tmp_path: Path):
    skills, rules = _reachability_fixture(tmp_path)
    assert _run_reachability(monkeypatch, skills, rules) == []


def test_reachability_catches_a_stranded_skill(monkeypatch, tmp_path: Path):
    """An internal skill no marker names and no exemption covers is unreachable."""
    skills, rules = _reachability_fixture(tmp_path)
    _write_skill(skills, "orphan", "user-invocable: false\n", "nobody routes here")
    errors = _run_reachability(monkeypatch, skills, rules)
    assert len(errors) == 1
    assert "skills/orphan/SKILL.md" in errors[0] and "unreachable" in errors[0]


def test_reachability_catches_two_front_doors(monkeypatch, tmp_path: Path):
    skills, rules = _reachability_fixture(tmp_path)
    (skills / "setup/SKILL.md").write_text(
        "---\nname: setup\n---\n<!-- steer:modes init,protect,feature=explain -->\n",
        encoding="utf-8",
    )
    errors = _run_reachability(monkeypatch, skills, rules)
    assert len(errors) == 1
    assert "skills/explain/SKILL.md" in errors[0] and "['setup', 'status']" in errors[0]


def test_reachability_catches_a_stale_annotation(monkeypatch, tmp_path: Path):
    """`mode=owner` naming a public skill or no skill is a claim on nothing."""
    skills, rules = _reachability_fixture(tmp_path)
    (skills / "status/SKILL.md").write_text(
        "---\nname: status\n---\n<!-- steer:modes this-week,feature=setup -->\n", encoding="utf-8"
    )
    errors = _run_reachability(monkeypatch, skills, rules)
    joined = "\n".join(errors)
    assert "'feature=setup'" in joined  # the annotation itself
    assert "skills/explain/SKILL.md" in joined  # and explain is now stranded


def test_reachability_catches_double_classification(monkeypatch, tmp_path: Path):
    """A skill with a front door needs no exemption - carrying both hides a move."""
    skills, rules = _reachability_fixture(tmp_path)
    errors = _run_reachability(
        monkeypatch, skills, rules, gateways={"gateway": "called by setup", "init": "stale"}
    )
    assert len(errors) == 1
    assert "skills/init/SKILL.md" in errors[0] and "needs no exemption" in errors[0]


def test_reachability_requires_the_rule_to_name_its_skill(monkeypatch, tmp_path: Path):
    """The rule-reached exemption asserts its reason instead of recording it."""
    skills, rules = _reachability_fixture(tmp_path)
    (rules / "53-automation.md").write_text("The automation opt-in lives here.\n", encoding="utf-8")
    errors = _run_reachability(monkeypatch, skills, rules)
    assert len(errors) == 1
    assert "no rule names '/steer:ruled'" in errors[0]


def test_reachability_catches_model_only_drift(monkeypatch, tmp_path: Path):
    skills, rules = _reachability_fixture(tmp_path)
    errors = _run_reachability(monkeypatch, skills, rules, model_only="")
    assert len(errors) == 1
    assert "MODEL_ONLY" in errors[0]


def test_reachability_catches_an_exemption_on_a_public_skill(monkeypatch, tmp_path: Path):
    """An exemption naming a skill users can type is stale, not an exemption."""
    skills, rules = _reachability_fixture(tmp_path)
    errors = _run_reachability(
        monkeypatch, skills, rules, gateways={"gateway": "called by setup", "setup": "stale"}
    )
    assert len(errors) == 1
    assert "'setup' is exempted" in errors[0]
