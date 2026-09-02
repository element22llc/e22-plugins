"""Tests for the computed pre-release preconditions (``scripts/release_preflight.py``).

The pure interpreters are pinned here: bullet counting, the docs-deploy
freshness rule (latest run must have succeeded *and* cover the newest docs
commit), the validator-compat rule, and the report's worst-severity roll-up.
The ``gh``/``git`` plumbing is exercised once end-to-end against this repo in
``--offline --no-fetch`` mode so the wiring cannot silently break.
"""

from __future__ import annotations

import release_preflight as rp

CHANGELOG = """\
# Changelog

## steer

### [Unreleased]

- **Added:** one.
  continuation line, not a bullet
- **Fixed:** two.

### 6.0.0

- released bullet

## other

### [Unreleased]

- not steer's
"""


def test_count_unreleased_bullets_counts_only_steer_top_level_bullets():
    assert rp.count_unreleased_bullets(CHANGELOG) == 2


def test_count_unreleased_bullets_is_zero_when_empty_and_none_when_missing():
    empty = CHANGELOG.replace("- **Added:** one.\n  continuation line, not a bullet\n", "").replace(
        "- **Fixed:** two.\n", ""
    )
    assert rp.count_unreleased_bullets(empty) == 0
    assert rp.count_unreleased_bullets("## steer\n\n### 6.0.0\n\n- x\n") is None


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
