#!/usr/bin/env sh
# steer — lint + format check for every detected stack. Invoked by `mise run ci:lint`.
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
	steer_ci_group 'biome ci .'
	biome ci .
	steer_ci_endgroup
fi

if steer_ci_has_python; then
	ran=1
	steer_ci_group 'ruff'
	ruff check .
	ruff format --check .
	steer_ci_endgroup
fi

if [ "${ran}" -eq 0 ]; then
	steer_ci_notice 'No Node or Python stack detected — no linter to run.'
fi
