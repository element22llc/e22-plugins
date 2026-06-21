"""End-to-end: re-run / lifecycle safety.

The steer skills are lifecycle-aware — re-running one, or running ``/steer:sync``
after a bootstrap, must never clobber user content or duplicate managed blocks.
That class of bug is the hardest to catch by eye, so we pin it: run a skill,
commit the result, run again, and assert the repo is byte-for-byte unchanged.

Each scenario is inherently TWO live skill runs (a first run to re-run against),
so the suite's per-`mise run e2e` cost/time roughly doubles with these added.
Skip-guarded on ``claude`` + a credential/seat like the other scenarios.
"""

from __future__ import annotations

import pytest

from . import asserts, gitutil
from .diagnostics import explain_on_failure
from .prompts import INIT, SYNC
from .run_steer import claude_available, have_credentials, run_skill, summarize_run

pytestmark = pytest.mark.e2e

_skip = pytest.mark.skipif(
    not claude_available() or not have_credentials(),
    reason="needs claude CLI + ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN / STEER_E2E_LOCAL",
)


@_skip
def test_init_is_rerun_safe(seed_repo):
    """init twice on the same repo: the second run hits init's greenfield-guard
    and must leave the already-bootstrapped repo untouched (no clobber, no
    duplicate HISTORY entry, no version churn)."""
    first = run_skill(seed_repo, INIT)
    summarize_run("/steer:init (1st)", first)
    assert not first.is_error, f"first init failed: {first.stderr[:1500]}"
    asserts.assert_spec_spine(seed_repo)

    baseline = gitutil.commit_all(seed_repo, "after first init")

    second = run_skill(seed_repo, INIT)
    summarize_run("/steer:init (2nd)", second)
    # The re-run may legitimately refuse (non-zero exit) — what matters is that it
    # changed nothing. So we assert on repo state, not on the second run's status.
    with explain_on_failure(seed_repo, second):
        gitutil.assert_unchanged(seed_repo, baseline)


@_skip
def test_sync_is_noop_when_current(seed_repo):
    """After init stamps the current plugin version, /steer:sync should find the
    repo already current and make no changes."""
    first = run_skill(seed_repo, INIT)
    summarize_run("/steer:init", first)
    assert not first.is_error, f"init failed: {first.stderr[:1500]}"

    baseline = gitutil.commit_all(seed_repo, "after init")

    sync = run_skill(seed_repo, SYNC)
    summarize_run("/steer:sync", sync)
    with explain_on_failure(seed_repo, sync):
        assert not sync.is_error, f"sync failed: {sync.stderr[:1500]}"
        gitutil.assert_unchanged(seed_repo, baseline)
