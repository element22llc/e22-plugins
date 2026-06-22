"""End-to-end: ``/steer:spec`` drafts a feature spec, code-free.

spec authors a feature's ``intent.md`` (and optionally ``contract.md``) and ends
at a *draft* intent — it flips to approved only via the ``approve`` subcommand,
and its defining guardrail is that **all writes stay under ``/spec/``** (never
``/apps``, ``/packages``, or other code).

Assertions are structural: the intent file exists, it's left at draft (not
approved), and every write is confined to ``spec/`` — the never-builds guardrail.
"""

from __future__ import annotations

import re

import pytest

from . import asserts, gitutil
from .diagnostics import explain_on_failure
from .prompts import SPEC, SPEC_FEATURE_ID
from .run_steer import claude_available, have_credentials, run_skill, summarize_run

pytestmark = pytest.mark.e2e

# A *chosen* "Status: approved" — not the template enumeration line, which reads
# "Status: draft | approved | …" and so begins "Status: draft".
_APPROVED = re.compile(r"Status:\s*approved\b")


@pytest.mark.skipif(not claude_available(), reason="claude CLI not on PATH")
@pytest.mark.skipif(
    not have_credentials(),
    reason="no ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN / STEER_E2E_LOCAL",
)
def test_spec_drafts_feature_confined_to_spec(spec_repo):
    run = run_skill(spec_repo, SPEC)
    summarize_run("/steer:spec", run)

    with explain_on_failure(spec_repo, run):
        assert not run.is_error, f"spec run failed: {run.stderr[:1500]}"

        # The feature intent was drafted.
        intent = asserts.assert_file(spec_repo, f"spec/features/{SPEC_FEATURE_ID}/intent.md")
        text = intent.read_text(encoding="utf-8")

        # Left at draft — spec records approval only via the `approve` subcommand.
        assert not _APPROVED.search(text), "spec marked the intent approved without `approve`"

        # The defining guardrail: spec writes only under /spec/, never code.
        gitutil.assert_changes_confined_to(spec_repo, "spec/")
