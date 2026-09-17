#!/usr/bin/env sh
# steer - build-only container image check (no push, no credentials).
# Invoked by `mise run ci:image`.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

dockerfiles="$(git ls-files 'apps/*/Dockerfile' 'Dockerfile')"
if [ -z "${dockerfiles}" ]; then
	steer_ci_notice 'No Dockerfile found (apps/*/Dockerfile or ./Dockerfile) - skipping image build. Add one when a deployable app exists (see /steer:build).'
	exit 0
fi

# Build context is the repo root so workspace deps + the lockfile are in scope.
printf '%s\n' "${dockerfiles}" | while IFS= read -r df; do
	[ -n "${df}" ] || continue
	case "${df}" in
	apps/*/Dockerfile)
		# APP=<app> makes CI authoritative over the Dockerfile's ARG default.
		app="$(basename "$(dirname "${df}")")"
		steer_ci_group "docker build -f ${df} --build-arg APP=${app} ."
		docker build -f "${df}" --build-arg "APP=${app}" .
		;;
	*)
		steer_ci_group "docker build -f ${df} ."
		docker build -f "${df}" .
		;;
	esac
	steer_ci_endgroup
done
