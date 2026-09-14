#!/usr/bin/env sh
# steer — static type check. Invoked by `mise run ci:typecheck`.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from —
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

if ! steer_ci_has_node; then
	steer_ci_notice 'No Node workspace — no typecheck contract.'
	exit 0
fi

pnpm run typecheck
