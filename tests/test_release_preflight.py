"""Tests for the computed pre-release preconditions (``scripts/release_preflight.py``).

The pure interpreters are pinned here: bullet counting, the docs-deploy
freshness rule (latest run must have succeeded *and* cover the newest docs
commit), the validator-compat rule, the routing-eval sweep rule (it must
postdate the last release, or the routing surface must be unchanged since, and
it must hold the floor), the audit-scope rule that sizes the judgment review to
the delta, and the report's worst-severity roll-up.
The ``gh``/``git`` plumbing is exercised once end-to-end against this repo in
``--offline --no-fetch`` mode so the wiring cannot silently break.
"""

from __future__ import annotations

import json
from datetime import datetime

import release_preflight as rp


def test_count_pending_fragments_counts_yaml_only(tmp_path):
    unreleased = tmp_path / "unreleased"
    unreleased.mkdir()
    (unreleased / "fixed-20260101-0000-a.yaml").write_text("kind: Fixed\n", encoding="utf-8")
    (unreleased / "added-20260101-0001-b.yaml").write_text("kind: Added\n", encoding="utf-8")
    (unreleased / ".gitkeep").write_text("", encoding="utf-8")
    assert rp.count_pending_fragments(unreleased) == 2


def test_count_pending_fragments_is_zero_when_empty_and_none_when_missing(tmp_path):
    empty = tmp_path / "unreleased"
    empty.mkdir()
    assert rp.count_pending_fragments(empty) == 0
    assert rp.count_pending_fragments(tmp_path / "nope") is None


def _run(conclusion="success", status="completed", sha="deploy0000", rid=1):
    return {"conclusion": conclusion, "status": status, "headSha": sha, "databaseId": rid}


def test_docs_freshness_ok_when_latest_succeeded_and_covers_docs_head():
    check = rp.docs_freshness([_run()], "docs000000", lambda a, b: True)
    assert check.status == "ok"


def test_docs_freshness_blocks_on_failed_or_cancelled_latest_run():
    for conclusion in ("failure", "cancelled"):
        check = rp.docs_freshness([_run(conclusion)], None, lambda a, b: True)
        assert check.status == "blocker"
        assert conclusion in check.detail


def test_docs_freshness_blocks_when_docs_commit_is_newer_than_deploy():
    check = rp.docs_freshness([_run()], "docs000000", lambda a, b: False)
    assert check.status == "blocker"
    assert "newer than" in check.detail


def test_docs_freshness_warns_while_a_deploy_is_running_or_when_no_runs():
    assert rp.docs_freshness([_run(None, "in_progress")], None, lambda a, b: True).status == "warn"
    assert rp.docs_freshness([], None, lambda a, b: True).status == "warn"


def test_validator_compat_is_high_not_blocker_on_failure_and_warn_when_unverified():
    ok = rp.validator_compat(
        [{"name": "plugin-quality"}, {"name": "validator-compat", "conclusion": "success"}]
    )
    assert ok.status == "ok"
    bad = rp.validator_compat([{"name": "validator-compat", "conclusion": "failure"}])
    assert bad.status == "high"
    assert rp.validator_compat(None).status == "warn"
    assert rp.validator_compat([{"name": "plugin-quality"}]).status == "warn"


def _sweep(started="2026-11-16T16:59:30.816Z", **below):
    return {"started": started, "cases": 31, "runs": 3, "score": 0.974, "below": below}


def _at(iso):
    return datetime.fromisoformat(iso)


def test_eval_sweep_is_stale_when_it_started_before_the_last_release():
    # The v7.24.0 pair: 16:59Z is before 13:21-05:00, which a string compare gets backwards.
    check = rp.eval_sweep([_sweep()], "v7.24.0", _at("2026-11-16T13:21:23-05:00"))
    assert check.status == "warn"
    assert "predates v7.24.0" in check.detail
    fresh = rp.eval_sweep([_sweep()], "v7.23.0", _at("2026-11-12T12:53:18-05:00"))
    assert fresh.status == "ok"
    assert "v7.23.0" in fresh.detail


def test_eval_sweep_is_owed_again_only_when_the_routing_surface_moved():
    stale = ([_sweep()], "v7.24.0", _at("2026-11-16T13:21:23-05:00"))
    untouched = rp.eval_sweep(*stale, surface=[])
    assert untouched.status == "ok"
    assert "owes no sweep" in untouched.detail
    moved = rp.eval_sweep(*stale, surface=["rules/00-router.md", "skills/work"])
    assert moved.status == "warn"
    assert "owes a sweep" in moved.detail
    assert "rules/00-router.md, skills/work" in moved.detail
    # A sweep newer than the last release is owed again too, once the surface moves after it.
    fresh = ([_sweep()], "v7.23.0", _at("2026-11-12T12:53:18-05:00"))
    assert rp.eval_sweep(*fresh, surface=["skills/work"]).status == "warn"
    unknown = rp.eval_sweep(*stale, surface=None)
    assert unknown.status == "warn"
    assert "not verified" in unknown.detail
    many = rp.eval_sweep(*stale, surface=[f"skills/s{i}" for i in range(7)])
    assert "skills/s3, +3 more" in many.detail


def test_routing_surface_is_the_router_rule_and_skill_frontmatter_only():
    old = {
        "plugins/steer/skills/work/SKILL.md": "---\ndescription: a\n---\nbody one\n",
        "plugins/steer/skills/spec/SKILL.md": "---\ndescription: a\n---\nbody\n",
    }
    new = {
        "plugins/steer/skills/work/SKILL.md": "---\ndescription: a\n---\nbody two\n",
        "plugins/steer/skills/spec/SKILL.md": "---\ndescription: b\n---\nbody\n",
        "plugins/steer/skills/fresh/SKILL.md": "---\ndescription: new\n---\n",
    }
    files = [
        *new,
        "plugins/steer/rules/00-router.md",
        "plugins/steer/rules/45-delivery.md",
        "plugins/steer/skills/work/modes/drive.md",
        "plugins/steer/templates/agents/skills/steer-spec/SKILL.md",
    ]
    assert rp.routing_surface(files, old.get, new.get) == [
        "skills/spec",
        "skills/fresh",
        "rules/00-router.md",
    ]
    assert rp.routing_surface(files[:1], old.get, new.get) == []


def test_check_evals_measures_the_surface_from_the_sweep_not_the_last_release(
    tmp_path, monkeypatch
):
    # Cut N moved the surface and skipped its sweep; at cut N+1 the delta since
    # the last release is quiet, and the sweep is still owed.
    monkeypatch.setattr(rp, "EVAL_LEDGER", tmp_path / "ledger.jsonl")
    (tmp_path / "ledger.jsonl").write_text(json.dumps(_sweep()), encoding="utf-8")
    asked = []

    def since(ref):
        asked.append(ref)
        return ["rules/00-router.md"] if ref == "sweep-sha" else []

    monkeypatch.setattr(rp, "sweep_commit", lambda started: "sweep-sha")
    monkeypatch.setattr(rp, "routing_surface_since", since)
    check = rp.check_evals("HEAD")
    assert asked == ["sweep-sha"]
    assert check.status == "warn"
    assert "owes a sweep" in check.detail


def test_sweep_commit_is_the_newest_commit_at_the_sweep_start():
    head = rp._git("rev-parse", "HEAD").stdout.strip()
    assert rp.sweep_commit(_at("2999-01-01T00:00:00Z")) == head
    assert rp.sweep_commit(_at("2000-01-01T00:00:00Z")) is None


def _delta(paths, lines_each=10):
    return [(f"plugins/steer/skills/s{i}/SKILL.md", lines_each) for i in range(paths)]


def test_audit_scope_is_light_up_to_both_limits_and_full_past_either():
    at_limit = rp.audit_scope(_delta(rp.LIGHT_MAX_PATHS))
    assert at_limit.tier == "light"
    assert "within the light limit" in at_limit.reason
    too_many = rp.audit_scope(_delta(rp.LIGHT_MAX_PATHS + 1))
    assert too_many.tier == "full"
    assert f"{rp.LIGHT_MAX_PATHS + 1} path(s)" in too_many.reason
    too_long = rp.audit_scope(_delta(2, lines_each=rp.LIGHT_MAX_LINES))
    assert too_long.tier == "full"
    assert "exceeds" in too_long.reason


def test_audit_scope_goes_full_on_a_release_critical_path_or_when_forced():
    delta = [("CHANGELOG.md", 1), ("docs/index.md", 1)]
    critical = rp.audit_scope(delta, critical=frozenset({"CHANGELOG.md"}))
    assert critical.tier == "full"
    assert "CHANGELOG.md" in critical.reason
    assert rp.audit_scope(delta).tier == "light"
    forced = rp.audit_scope(delta, force_full=True)
    assert forced.tier == "full"
    assert "forced" in forced.reason


def test_audit_scope_drops_generated_mirrors_and_sizes_only_what_a_dimension_reads():
    mirrors = ("plugins/steer/templates/agents/skills/", "plugins/steer/templates/github/ci.md")
    delta = [
        (".changes/unreleased/fixed-1-a.yaml", 5000),
        ("plugins/steer/skills/work/SKILL.md", 12),
        ("docs/workflows/work.md", 3),
        ("scripts/release_preflight.py", 5000),
        ("tests/test_release_preflight.py", 5000),
        ("plugins/steer/templates/agents/skills/steer-work/SKILL.md", 5000),
        ("plugins/steer/templates/github/ci.md", 5000),
    ]
    scope = rp.audit_scope(delta, mirrors)
    assert scope.tier == "light"
    assert "2 path(s) / 15 line(s)" in scope.reason
    assert scope.omitted == 2
    # Unsized is not unreviewed: a changelog-coherence finding cites the
    # fragment, and tooling keeps its repo-tooling ceiling.
    assert scope.files == [path for path, _ in delta[:5]]


def test_generated_mirrors_come_from_the_generators_and_exist():
    mirrors = rp.generated_mirrors()
    assert len(mirrors) == 4
    for prefix in mirrors:
        assert (rp.REPO_ROOT / prefix).exists(), prefix


def test_eval_sweep_names_the_cases_under_the_floor_worst_first():
    # At three runs 0.8 is one missed `routed` grader; 0.87 lost `answer` and still routed.
    row = _sweep(**{"routes-a": 0.8, "routes-b": 0.67, "routes-c": 0.87})
    check = rp.eval_sweep([row], "v7.23.0", _at("2026-11-12T17:53:18Z"))
    assert check.status == "warn"
    assert "routes-b 0.67, routes-a 0.8" in check.detail
    assert "routes-c" not in check.detail
    assert rp.EVAL_RECHECK in check.detail
    assert "predates" not in check.detail
    assert "31 cases x 3 runs" in check.detail
    only_docked = rp.eval_sweep(
        [_sweep(**{"routes-c": 0.87})], "v7.23.0", _at("2026-11-12T17:53:18Z")
    )
    assert only_docked.status == "ok"


def test_eval_sweep_reads_the_newest_row_whatever_the_file_order():
    rows = [_sweep(**{"routes-a": 0.67}), _sweep(started="2026-11-12T16:33:44.029Z")]
    check = rp.eval_sweep(rows, "v7.23.0", _at("2026-11-12T17:53:18Z"))
    assert "routes-a 0.67" in check.detail


def test_eval_sweep_warns_when_it_cannot_judge():
    assert rp.eval_sweep([], "v7.24.0", _at("2026-11-16T18:21:23Z")).status == "warn"
    undated = rp.eval_sweep([_sweep()], None, None)
    assert undated.status == "warn"
    assert "not verified" in undated.detail


def test_check_evals_degrades_to_warn_on_a_missing_or_malformed_ledger(tmp_path, monkeypatch):
    monkeypatch.setattr(rp, "EVAL_LEDGER", tmp_path / "ledger.jsonl")
    assert rp.check_evals(None).status == "warn"
    started = '"started": "2026-11-16T16:59:30.816Z"'
    for body in ("not json\n", f"{{{started}}}\n", f'{{{started}, "below": null}}\n'):
        (tmp_path / "ledger.jsonl").write_text(body, encoding="utf-8")
        check = rp.check_evals(None)
        assert check.status == "warn"
        assert "unreadable" in check.detail


def test_check_evals_dates_the_anchor_from_git(tmp_path, monkeypatch):
    monkeypatch.setattr(rp, "EVAL_LEDGER", tmp_path / "ledger.jsonl")
    for started, stale in (("2000-01-01T00:00:00Z", True), ("2999-01-01T00:00:00Z", False)):
        (tmp_path / "ledger.jsonl").write_text(json.dumps(_sweep(started)), encoding="utf-8")
        assert ("predates HEAD" in rp.check_evals("HEAD").detail) is stale


def test_worst_and_render_roll_up_severity():
    checks = [
        rp.Check("a", "ok", "fine"),
        rp.Check("b", "warn", "meh"),
        rp.Check("c", "high", "hmm"),
    ]
    assert rp.worst(checks) == "high"
    out = rp.render(checks, "v6.0.0")
    assert "worst = high" in out
    assert out.strip().endswith("LAST_RELEASE=v6.0.0")
    checks.append(rp.Check("d", "blocker", "stop"))
    assert rp.worst(checks) == "blocker"


def test_end_to_end_offline_run_against_this_repo_produces_every_check():
    checks, _anchor = rp.run_all("audit-loop", fetch=False, offline=True)
    ids = [c.id for c in checks]
    assert ids == [
        "tree-clean",
        "base-current",
        "unreleased",
        "manifests",
        "last-release",
        "delta",
        "ledger",
        "evals",
        "docs-deploy",
        "validator-compat",
    ]
    # Offline mode never claims the gh-backed checks passed.
    assert {c.status for c in checks if c.id in ("docs-deploy", "validator-compat")} == {"warn"}
    assert next(c for c in checks if c.id == "manifests").status == "ok"


def test_only_the_release_caller_gets_the_audit_scope_line():
    for caller, expected in (("release", True), ("quick-release", False)):
        checks, _anchor = rp.run_all(caller, fetch=False, offline=True)
        assert ("audit-scope" in [c.id for c in checks]) is expected


def test_plan_is_the_workflow_args_and_skips_both_scouts(capsys, monkeypatch):
    monkeypatch.setattr(rp, "resolve_anchor", lambda: ("HEAD", rp.Check("last-release", "ok", "")))
    monkeypatch.setattr(rp, "touched_ledger_rows", lambda: [{"id": "r1"}])
    assert rp.main(["--plan"]) == 0
    plan = json.loads(capsys.readouterr().out)
    # These three are what the workflow tests before it skips its delta scout.
    assert plan["lastRelease"] == "HEAD"
    assert plan["files"] == []
    assert isinstance(plan["unreleased"], str)
    assert plan["ledgerRows"] == [{"id": "r1"}]
    assert plan["tier"] == "light"
    assert rp.main(["--plan", "--full"]) == 0
    forced = json.loads(capsys.readouterr().out)
    assert forced["tier"] == "full"
    assert "forced" in forced["tierReason"]


def test_an_unreadable_delta_is_never_a_light_plan(capsys, monkeypatch):
    for anchor in (None, "no-such-ref"):
        monkeypatch.setattr(
            rp, "resolve_anchor", lambda a=anchor: (a, rp.Check("last-release", "high", ""))
        )
        assert rp.main(["--plan"]) == 1
        assert capsys.readouterr().out == ""
        assert rp.check_scope(anchor).status == "warn"


def test_report_mode_always_exits_zero(capsys):
    assert rp.main(["--report", "--offline", "--no-fetch", "--caller", "audit-loop"]) == 0
    out = capsys.readouterr().out
    assert "preflight:" in out
