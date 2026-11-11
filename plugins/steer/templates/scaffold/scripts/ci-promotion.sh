#!/usr/bin/env sh
# steer - a PR into prod comes from a release or hotfix branch that already contains prod.
# Rationale: /steer:reference conventions -> "Deployment & environments". CI: a pull_request
# into prod; a no-op elsewhere.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

if [ "${STEER_CI_EVENT:-}" != pull_request ] || [ "${STEER_CI_BASE_REF:-}" != prod ]; then
	printf 'ci:promotion - not a pull request into prod; nothing to check.\n'
	exit 0
fi

head_ref="${STEER_CI_HEAD_REF:-}"
case "${head_ref}" in
hotfix/?*) ;;
release/*)
	if ! printf '%s\n' "${head_ref}" | grep -Eq '^release/(v[0-9]+\.[0-9]+\.[0-9]+|[0-9a-f]{7,40})$'; then
		steer_ci_error "A release branch into prod is release/vX.Y.Z (or release/<short-sha> for a promotion with no version); got ${head_ref}."
		exit 1
	fi
	;;
*)
	steer_ci_error "Only release/* and hotfix/* branches may open a PR into prod; got '${head_ref}'. Ship main through /steer:work promote, an incident through /steer:work --hotfix."
	exit 1
	;;
esac

if [ -z "${STEER_CI_HEAD_SHA:-}" ] || ! git cat-file -e "${STEER_CI_HEAD_SHA}^{commit}" 2>/dev/null; then
	steer_ci_notice 'No PR head commit to check - skipping the merge-back check (fail-open).'
	exit 0
fi
if ! prod="$(steer_ci_base)"; then
	steer_ci_notice 'No prod ref to compare against - skipping the merge-back check (fail-open).'
	exit 0
fi

# A hotfix cut from main instead of prod would carry every unreleased main commit.
case "${head_ref}" in
hotfix/*)
	main="origin/${STEER_CI_DEFAULT_BRANCH:-main}"
	if git rev-parse --verify --quiet "${main}" >/dev/null &&
		[ "$(git rev-list --count "${prod}..${STEER_CI_HEAD_SHA}")" != "$(git rev-list --count "${prod}..${STEER_CI_HEAD_SHA}" --not "${main}")" ]; then
		steer_ci_error "${head_ref} carries commits from ${main} that prod does not ship. Cut a hotfix from prod: git switch -c ${head_ref} origin/prod."
		exit 1
	fi
	printf 'ci:promotion - hotfix %s is cut from prod; nothing to drop.\n' "${head_ref}"
	exit 0
	;;
esac

# Prod is merged back into main, and into a release in QA, after every merge into it; a
# release that does not contain prod would drop a hotfix or a QA fix.
if ! git merge-base --is-ancestor "${prod}" "${STEER_CI_HEAD_SHA}"; then
	steer_ci_error "${head_ref} does not contain prod, so it would drop what prod ships: $(git log --no-merges --format='%h %s' "${STEER_CI_HEAD_SHA}..${prod}" | tr '\n' ';') Merge prod back into it through the open merge-back/* PR (or one pushed at origin/prod), with Create a merge commit - never squash."
	exit 1
fi
printf 'ci:promotion - %s contains everything prod ships.\n' "${head_ref}"
