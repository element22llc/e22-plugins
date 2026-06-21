"""End-to-end: ``/steer:init`` against a greenfield repo.

Drives the real plugin headlessly and asserts the produced repo has the spec
spine, plugin wiring, and the ``always`` capability scaffold. Skipped unless the
``claude`` CLI is on PATH *and* a credential is present, so the default suite
(``uv run pytest``) and contributors without a key stay green and spend nothing.

Fidelity note: the prompt tells ``init`` to stop before commit/PR (the user
decision for the prototype) — deterministic, no ``gh`` auth or branch cleanup.
The on-disk artifacts the skill writes are identical either way; only the
final commit/PR tail is suppressed.
"""

from __future__ import annotations

import pytest

from . import asserts
from .run_steer import claude_available, have_credentials, run_skill

pytestmark = pytest.mark.e2e

INIT_PROMPT = (
    "/steer:init\n\n"
    "This is an automated, non-interactive test run against a greenfield repo. "
    "Bootstrap it: install the bundled scaffold and instantiate the full spec "
    "spine, using sensible placeholder defaults for anything you would normally "
    "ask a human. Do NOT ask interactive questions. Do NOT commit, push, create "
    "a branch, or open a pull request — only write the files into the working tree."
)


@pytest.mark.skipif(not claude_available(), reason="claude CLI not on PATH")
@pytest.mark.skipif(
    not have_credentials(),
    reason="no ANTHROPIC_API_KEY / CLAUDE_CODE_OAUTH_TOKEN",
)
def test_init_greenfield(seed_repo):
    run = run_skill(seed_repo, INIT_PROMPT)

    # Surface cost so the budget cap can be tuned from a real run.
    print(f"\n[e2e] /steer:init turns={run.num_turns} cost_usd={run.cost_usd}")

    assert not run.is_error, (
        f"claude run reported an error (rc={run.returncode}).\n"
        f"stderr: {run.stderr[:2000]}\nresult: {run.result[:2000]}"
    )

    # Spine instantiated + version-stamped.
    asserts.assert_spec_spine(seed_repo)

    # "always" capabilities (CAPABILITIES.md) wired into the produced repo.
    asserts.assert_plugin_enabled_local(seed_repo)
    asserts.assert_toolchain_pin(seed_repo)
    asserts.assert_version_pin_enforcement(seed_repo)
    asserts.assert_branch_protection_policy(seed_repo)
    asserts.assert_drift_gate(seed_repo)
    asserts.assert_in_ci_plugin_loading(seed_repo)
    asserts.assert_dependency_automation(seed_repo)
