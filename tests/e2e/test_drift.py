"""End-to-end: ``/steer:audit spec`` is a read-only conformance audit.

The spec audit compares the as-built ``/spec`` against a tracker-spec export and *reports*
divergences — it never edits code/spec and never commits (``disallowed-tools``).
Its report is printed in the response, not written to a file (the optional
``DRIFT-REPORT.md`` write needs a follow-up confirmation a headless run can't give).

So this scenario centers on the property that matters: **drift mutates nothing**,
even under ``bypassPermissions`` (the robust, structural assertion). A second,
deliberately *lenient* check confirms the printed report actually engaged with the
seeded divergence (the as-built ``phone`` column / XLSX the tracker never asked for)
and closed with the mandatory ``## Recommended next actions`` block — prose, so
kept generous to avoid flaking on wording.
"""

from __future__ import annotations

import pytest

from . import gitutil
from .conftest import DRIFT_SIGNALS
from .diagnostics import explain_on_failure
from .prompts import DRIFT
from .run_steer import claude_available, have_credentials, run_skill, summarize_run

pytestmark = pytest.mark.e2e


@pytest.mark.skipif(not claude_available(), reason="claude CLI not on PATH")
@pytest.mark.skipif(
    not have_credentials(),
    reason="no ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN / STEER_E2E_LOCAL",
)
def test_drift_is_read_only_and_reports_divergence(drift_repo):
    # The fixture already commits the seeded spine, so just capture that clean
    # baseline (a second commit would fail on a clean tree).
    baseline = gitutil.head(drift_repo)

    run = run_skill(drift_repo, DRIFT)
    summarize_run("/steer:audit spec", run)

    with explain_on_failure(drift_repo, run):
        assert not run.is_error, f"drift run failed: {run.stderr[:1500]}"

        # The core contract: read-only. Nothing edited, nothing committed — even
        # though we ran under bypassPermissions.
        gitutil.assert_unchanged(drift_repo, baseline)

        # Lenient: the printed report engaged with the audit. It must close with
        # the mandatory next-actions block, and name the seeded divergence.
        report = run.result.lower()
        assert "recommended next actions" in report, "drift report missing the next-actions block"
        assert any(sig in report for sig in DRIFT_SIGNALS), (
            f"drift report did not surface the seeded divergence {DRIFT_SIGNALS}"
        )
