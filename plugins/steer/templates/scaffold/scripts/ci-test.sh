#!/usr/bin/env sh
# steer — run the test suite for every detected stack. Invoked by `mise run ci:test`.
# A detected stack with no test contract FAILS: green must mean tests ran.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from —
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

ran=0

if steer_ci_has_node; then
	ran=1
	# The root `--if-present` fan-out is not a test contract — green must mean tests ran.
	if ! git ls-files '*package.json' |
		xargs grep -hE '"test"[[:space:]]*:' 2>/dev/null |
		grep -qv -- '--if-present'; then
		steer_ci_error 'Node workspace detected but no package defines a "test" script - a green CI would not mean tests ran. Add tests (Definition of Done).'
		exit 1
	fi
	steer_ci_group 'pnpm test'
	# Per-package lcov.info only when @vitest/coverage is wired; the coverage gate is fail-open without it.
	if git ls-files '*package.json' | xargs grep -lq '@vitest/coverage' 2>/dev/null; then
		pnpm run test -- --coverage --coverage.reporter=lcov
	else
		pnpm run test
	fi
	steer_ci_endgroup
fi

if steer_ci_has_python; then
	ran=1
	steer_ci_group 'pytest'
	cov_args=''
	if uv run python -c 'import pytest_cov' >/dev/null 2>&1; then
		cov_args='--cov --cov-report=xml --cov-report=term-missing'
	fi
	rc=0
	# shellcheck disable=SC2086  # deliberate word-splitting of the optional coverage flags
	uv run pytest $cov_args || rc=$?
	# pytest exit 5 = no tests collected: fail rather than report a false green.
	if [ "${rc}" -eq 5 ]; then
		steer_ci_error 'Python project detected but pytest collected no tests. Add tests (Definition of Done).'
		exit 1
	fi
	if [ "${rc}" -ne 0 ]; then
		exit "${rc}"
	fi
	steer_ci_endgroup
fi

if [ "${ran}" -eq 0 ]; then
	steer_ci_notice 'No Node or Python stack detected - no test suite to run.'
fi
