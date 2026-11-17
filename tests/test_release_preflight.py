"""Tests for the computed pre-release preconditions (``scripts/release_preflight.py``).

The pure interpreters are pinned here: bullet counting, the docs-deploy
freshness rule (latest run must have succeeded *and* cover the newest docs
commit), the validator-compat rule, the routing-eval sweep rule (it must
postdate the last release and hold the floor), and the report's worst-severity
roll-up.
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


def test_report_mode_always_exits_zero(capsys):
    assert rp.main(["--report", "--offline", "--no-fetch", "--caller", "audit-loop"]) == 0
    out = capsys.readouterr().out
    assert "preflight:" in out
