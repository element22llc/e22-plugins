#!/usr/bin/env sh
# steer — changed-line coverage gate. Invoked by `mise run ci:coverage` (after ci:test).
# Gates only the lines a change touches — never a global %; fail-open without a report.
# Rationale: rule 41-coverage; /steer:reference conventions -> Coverage.
#
# BASE RESOLUTION
#   CI exports STEER_CI_EVENT / STEER_CI_BASE_REF / STEER_CI_BEFORE from the
#   workflow context. Locally none are set, so the base falls back to
#   STEER_CI_BASE (default origin/main) — the same fail-open convention as the
#   plugin repo's delivery-gates.sh: an unresolvable base skips, never blocks.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from —
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

COVERAGE_DIFF_MIN="${COVERAGE_DIFF_MIN:-80}"
ZERO=0000000000000000000000000000000000000000

# The root fan-out writes PER-PACKAGE reports, so glob apps/* and packages/* alongside the root paths.
reports=''
for f in coverage/lcov.info apps/*/coverage/lcov.info packages/*/coverage/lcov.info \
	coverage.xml apps/*/coverage.xml packages/*/coverage.xml; do
	if [ -f "${f}" ]; then reports="${reports} ${f}"; fi
done
if [ -z "${reports}" ]; then
	steer_ci_notice 'No coverage report produced - wire pytest-cov / @vitest/coverage to measure coverage (/steer:reference conventions -> Coverage). Skipping changed-line gate.'
	exit 0
fi

case "${STEER_CI_EVENT:-local}" in
pull_request)
	base="origin/${STEER_CI_BASE_REF}"
	if ! git fetch --no-tags --quiet origin "${STEER_CI_BASE_REF}" 2>/dev/null; then
		steer_ci_notice "Could not fetch base branch '${STEER_CI_BASE_REF}' - skipping changed-line coverage (fail-open)."
		exit 0
	fi
	;;
push)
	# push to main: the solo-trunk DoD floor (pr-flow already gated via PR).
	if ! grep -Eiq '^[[:space:]]*<!--[[:space:]]*steer:delivery-mode=solo-trunk[[:space:]]*-->' CLAUDE.md 2>/dev/null; then
		steer_ci_notice 'push to main in pr-flow - the PR already gated coverage; skipping push-time floor.'
		exit 0
	fi
	if [ -z "${STEER_CI_BEFORE:-}" ] || [ "${STEER_CI_BEFORE}" = "${ZERO}" ]; then
		steer_ci_notice 'No prior commit to diff against (first push) - skipping changed-line coverage (fail-open).'
		exit 0
	fi
	base="${STEER_CI_BEFORE}"
	;;
*)
	base="${STEER_CI_BASE:-origin/main}"
	if ! git rev-parse --verify --quiet "${base}" >/dev/null 2>&1; then
		steer_ci_notice "Base ref '${base}' not found - skipping changed-line coverage (fail-open). Set STEER_CI_BASE to pick another."
		exit 0
	fi
	;;
esac

printf '## Coverage (changed lines vs %s)\n' "${base}" >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
# Pinned — this gate can FAIL a PR. If a bump drops --markdown-report, use --format markdown:coverage-diff.md.
# shellcheck disable=SC2086  # deliberate word-splitting of the collected report paths
if uvx diff-cover@10.4.1 ${reports} \
	--compare-branch "${base}" \
	--fail-under "${COVERAGE_DIFF_MIN}" \
	--markdown-report coverage-diff.md; then
	cat coverage-diff.md >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
else
	cat coverage-diff.md >>"${GITHUB_STEP_SUMMARY:-/dev/null}"
	cat coverage-diff.md
	steer_ci_error "Changed lines are under ${COVERAGE_DIFF_MIN}% covered - cover the code you touched (rule 41-coverage)."
	exit 1
fi
