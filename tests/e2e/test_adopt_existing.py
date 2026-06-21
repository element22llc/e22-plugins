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
from .run_steer import claude_available, have_credentials, run_skill, summarize_run

pytestmark = pytest.mark.e2e

ADOPT_PROMPT = (
    "/steer:adopt\n\n"
    "Automated, non-interactive test run. This is an existing app with real code "
    "and no /spec. Reverse-engineer the spec spine and sync the bundled "
    "scaffolding ADDITIVELY — never delete or rewrite existing working code, and "
    "merge (never overwrite) existing config files. Use sensible placeholder "
    "defaults; do NOT ask interactive questions. Do NOT commit, push, create a "
    "branch, or open a pull request — only write files into the working tree."
)


@pytest.mark.skipif(not claude_available(), reason="claude CLI not on PATH")
@pytest.mark.skipif(
    not have_credentials(),
    reason="no ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN / STEER_E2E_LOCAL",
)
def test_adopt_existing(existing_app_repo):
    app = existing_app_repo
    run = run_skill(app.repo, ADOPT_PROMPT)
    summarize_run("/steer:adopt", run)

    assert not run.is_error, (
        f"claude run reported an error (rc={run.returncode}).\n"
        f"stderr: {run.stderr[:2000]}\nresult: {run.result[:2000]}"
    )

    # Spine reverse-engineered + version-stamped.
    asserts.assert_spec_spine(app.repo)

    # The invariant: no Accepted ADR minted from inferred code.
    asserts.assert_no_accepted_adr(app.repo)

    # Non-clobber: existing working code untouched (byte-identical).
    produced = (app.repo / app.core_rel).read_text(encoding="utf-8")
    assert produced == app.core_src, "adopt rewrote existing working code"

    # Non-clobber: the custom .gitignore line survived the additive merge.
    asserts.assert_contains(app.repo, ".gitignore", app.gitignore_marker)
