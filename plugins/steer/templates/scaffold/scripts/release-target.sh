#!/usr/bin/env sh
# steer - print the branch the held environment (policy/delivery.yml release_hold) should run.
# Rationale: /steer:reference conventions -> "Deployment & environments".
#
# The open release branch while a release/* PR into prod is open, else the default branch.
# A product deploy job calls it and deploys only that branch. Needs GH_TOKEN with pull-requests: read.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

default="${STEER_DEFAULT_BRANCH:-}"
[ -n "${default}" ] || default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
[ -n "${default}" ] || default=main

hold="$(sed -n 's/^release_hold:[[:space:]]*\([^[:space:]#]*\).*/\1/p' policy/delivery.yml 2>/dev/null || true)"
if [ -z "${hold}" ] || [ "${hold}" = none ]; then
	printf '%s\n' "${default}"
	exit 0
fi

# Fail closed: deploying main over a release in QA is the failure this exists to prevent.
if ! heads="$(gh pr list --base prod --state open --limit 100 --json headRefName --jq '.[].headRefName')"; then
	steer_ci_error "Cannot list open PRs into prod, so the ${hold} target is unknown - not deploying. Check GH_TOKEN (pull-requests: read)."
	exit 1
fi
releases="$(printf '%s\n' "${heads}" | grep '^release/' || true)"
count="$(printf '%s' "${releases}" | grep -c . || true)"
case "${count}" in
0) printf '%s\n' "${default}" ;;
1) printf '%s\n' "${releases}" ;;
*)
	steer_ci_error "More than one release PR into prod is open ($(printf '%s' "${releases}" | tr '\n' ' ')) - close all but one; not deploying ${hold}."
	exit 1
	;;
esac
