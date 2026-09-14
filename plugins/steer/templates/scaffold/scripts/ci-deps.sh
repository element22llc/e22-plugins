#!/usr/bin/env sh
# steer — install workspace dependencies for the checks that need them.
# Invoked by `mise run ci:deps` (a `depends` of ci:typecheck and ci:test).
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from —
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

if ! steer_ci_has_node; then
	steer_ci_notice 'No Node workspace — nothing to install.'
	exit 0
fi

# Freeze only once a lockfile exists (a fresh fork has none until /steer:init generates it).
if [ -f pnpm-lock.yaml ]; then
	pnpm install --frozen-lockfile
else
	printf 'No pnpm-lock.yaml yet — installing without frozen lockfile.\n'
	pnpm install --no-frozen-lockfile
fi
