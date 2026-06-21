"""End-to-end: ``/steer:adopt`` against an existing app with no ``/spec``.

Beyond proving the harness generalizes past a single skill, this covers two
contracts that ``init`` cannot:

- **Additive, never-clobber sync** — adopt syncs the bundled scaffold into a repo
  that already has files; existing working code stays byte-identical and a
  custom ``.gitignore`` line survives the merge.
- **No Accepted ADR from inference** — adopt reverse-engineers intents as
  *Proposed* ADRs and must never ratify one from code (adopt-no-adr-from-inference).

Skip-guarded on ``claude`` + a credential, like the init scenario.
"""

from __future__ import annotations

import pytest

from . import asserts
from .diagnostics import explain_on_failure
from .prompts import ADOPT
from .run_steer import claude_available, have_credentials, run_skill, summarize_run

pytestmark = pytest.mark.e2e


@pytest.mark.skipif(not claude_available(), reason="claude CLI not on PATH")
@pytest.mark.skipif(
    not have_credentials(),
    reason="no ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN / STEER_E2E_LOCAL",
)
def test_adopt_existing(existing_app_repo):
    app = existing_app_repo
    # adopt is the heaviest skill — it reverse-engineers the app, instantiates the
    # spine, syncs the scaffold, AND triages productionization, so it runs well past
    # the default per-scenario timeout (a live run hit the 480s cap still working).
    # Give it generous headroom; the default still fail-fasts the lighter skills.
    run = run_skill(app.repo, ADOPT, timeout_s=1200)
    summarize_run("/steer:adopt", run)

    with explain_on_failure(app.repo, run):
        assert not run.is_error, f"claude run reported an error (rc={run.returncode})."

        # Spine reverse-engineered + version-stamped.
        asserts.assert_spec_spine(app.repo)

        # The invariant: no Accepted ADR minted from inferred code.
        asserts.assert_no_accepted_adr(app.repo)

        # Non-clobber: existing working code untouched (byte-identical).
        produced = (app.repo / app.core_rel).read_text(encoding="utf-8")
        assert produced == app.core_src, "adopt rewrote existing working code"

        # Non-clobber: the custom .gitignore line survived the additive merge.
        asserts.assert_contains(app.repo, ".gitignore", app.gitignore_marker)
