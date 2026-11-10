#!/usr/bin/env sh
# steer - a PR into prod comes from a release or hotfix branch and drops nothing prod already ships.
# Rationale: /steer:reference conventions -> "Deployment & environments".
#
#   ci-promotion.sh                         the gate (CI: a pull_request into prod; no-op elsewhere)
#   ci-promotion.sh --list-missing H P      commits P's merges carried that H lacks, oldest first
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

TRAILER='s/.*(cherry picked from commit \([0-9a-f]\{40\}\)).*/\1/p'

# What each merge into prod carried (M^1..M^2), so linear history from before
# prod took merge commits is never read as a missing change.
carried() {
	git rev-list --first-parent --merges "$1" | while IFS= read -r m; do
		git rev-list --no-merges "${m}^1..${m}^2"
	done
}

# A carried commit is covered when the head contains it, or a cherry-pick -x of
# it, or of the commit it was itself cherry-picked from (hotfix -> release copy).
missing() {
	head="$1"
	picked="$(mktemp)"
	lacking="$(mktemp)"
	git log --format=%B "${head}" | sed -n "${TRAILER}" | sort -u >"${picked}"
	carried "$2" | sort -u | while IFS= read -r c; do
		git merge-base --is-ancestor "${c}" "${head}" && continue
		grep -qx "${c}" "${picked}" && continue
		covered=no
		for src in $(git log -1 --format=%B "${c}" | sed -n "${TRAILER}"); do
			if grep -qx "${src}" "${picked}" || git merge-base --is-ancestor "${src}" "${head}" 2>/dev/null; then
				covered=yes
				break
			fi
		done
		[ "${covered}" = yes ] || printf '%s\n' "${c}"
	done >"${lacking}"
	# Oldest first, the order a cherry-pick replays them in.
	[ ! -s "${lacking}" ] || git rev-list --reverse --topo-order "$2" | grep -Fxf "${lacking}" || true
	rm -f "${picked}" "${lacking}"
}

if [ "${1:-}" = --list-missing ]; then
	[ $# -eq 3 ] || {
		steer_ci_error 'usage: ci-promotion.sh --list-missing <head> <prod-ref>'
		exit 2
	}
	missing "$2" "$3"
	exit 0
fi

if [ "${STEER_CI_EVENT:-}" != pull_request ] || [ "${STEER_CI_BASE_REF:-}" != prod ]; then
	printf 'ci:promotion - not a pull request into prod; nothing to check.\n'
	exit 0
fi

head_ref="${STEER_CI_HEAD_REF:-}"
case "${head_ref}" in
hotfix/?*)
	printf 'ci:promotion - hotfix %s is cut from prod; nothing to drop.\n' "${head_ref}"
	exit 0
	;;
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
	steer_ci_notice 'No PR head commit to check - skipping the drop check (fail-open).'
	exit 0
fi
if ! prod="$(steer_ci_base)"; then
	steer_ci_notice 'No prod ref to compare against - skipping the drop check (fail-open).'
	exit 0
fi

dropped="$(missing "${STEER_CI_HEAD_SHA}" "${prod}")"
if [ -n "${dropped}" ]; then
	steer_ci_error "This release would drop changes prod already ships (a hotfix or an earlier QA fix that never reached main). Cherry-pick each onto ${head_ref} with \`git cherry-pick -x\`, through a PR: $(printf '%s\n' "${dropped}" | while IFS= read -r c; do git log -1 --format='%h %s' "${c}"; done | tr '\n' ';')"
	exit 1
fi
printf 'ci:promotion - %s carries everything prod ships.\n' "${head_ref}"
