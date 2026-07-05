#!/usr/bin/env sh
# Branch-diff delivery gates — the PR-only --base checks, runnable locally.
#
# WHY THIS EXISTS
#   CI's plugin-quality job runs two gates that diff the PR against its base:
#   check_changelog.py --base (a plugins/steer change needs a CHANGELOG entry)
#   and check_docs_impact.py --base (a documented-surface change needs a docs/
#   update). They need a base ref, so they were CI-only — which meant the local
#   `mise run ci` passed, you pushed, and only THEN did CI fail. This script runs
#   the same two gates against origin/main so the failure is caught before push.
#   `mise run ci` depends on it (see mise.toml); it is also safe to run directly.
#
# BASE RESOLUTION
#   Diffs against origin/main. Each gate uses `<base>...HEAD` (three-dot, i.e.
#   the merge-base) internally, matching how CI diffs the PR
#   base sha. Fail-OPEN if origin/main is not resolvable (e.g. a fresh clone with
#   no fetch, or the CI checkout that has only the PR ref — there the explicit
#   sha-based steps in plugin-quality.yml remain authoritative): print a note and
#   exit 0 rather than block. POSIX sh.

set -e

# In CI the explicit sha-based steps in plugin-quality.yml run these same gates
# against the PR's real base ref — running them here too would duplicate them
# and, for a PR targeting a non-main base, diff the WRONG base (origin/main) and
# false-fail. Skip in CI; this task is the local pre-push safety net.
# DELIVERY_GATES_BASE still forces a run (with that base) for explicit local use.
if [ "${CI:-}" = "true" ] && [ -z "${DELIVERY_GATES_BASE:-}" ]; then
	echo "delivery-gates: CI=true — skipping (CI's sha-based PR steps are authoritative)."
	exit 0
fi

BASE="${DELIVERY_GATES_BASE:-origin/main}"

if ! git rev-parse --verify --quiet "${BASE}" >/dev/null 2>&1; then
	echo "delivery-gates: base ref '${BASE}' not found — skipping (CI enforces the sha-based gates)."
	exit 0
fi

# Run both gates; let either non-zero exit propagate (set -e) so the push is
# blocked with the gate's own actionable message.
uv run python scripts/check_changelog.py --base "${BASE}"
uv run python scripts/check_docs_impact.py --base "${BASE}"
