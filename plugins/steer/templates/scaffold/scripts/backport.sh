#!/usr/bin/env sh
# shellcheck disable=SC2016 # the backticks are Markdown in the PR comment, never command substitution
# steer - after a release or hotfix PR merges into prod, carry what it shipped back to main.
# Rationale: /steer:reference conventions -> "Deployment & environments". Run by .github/workflows/backport.yml.
#
# Pushes backport/<pr>-to-<target> with `git cherry-pick -x` of each commit the target lacks
# (ci-promotion.sh --list-missing), then comments a link to open the PR. The targets are the
# default branch, and for a hotfix the open release branch too. BACKPORT_OPEN_PR=true (an App
# token, never GITHUB_TOKEN) opens the PR itself.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

: "${PR:?}" "${HEAD_REF:?}" "${MERGE_SHA:?}" "${REPO:?}" "${DEFAULT_BRANCH:?}" "${GH_TOKEN:?}"

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "${GH_TOKEN}" | base64 | tr -d '\n')"

targets="${DEFAULT_BRANCH}"
case "${HEAD_REF}" in
hotfix/*)
	release="$(gh pr list --base prod --state open --json headRefName --jq '.[].headRefName' | grep '^release/' | head -n 1 || true)"
	[ -z "${release}" ] || targets="${targets} ${release}"
	;;
esac

body="$(mktemp)"
printf '### Back-port of #%s\n\n' "${PR}" >"${body}"

only_generated_conflicts() {
	conflicted="$(git diff --name-only --diff-filter=U)"
	[ -n "${conflicted}" ] && [ "$(printf '%s\n' "${conflicted}" | grep -vcx 'CHANGELOG.md' || true)" = 0 ]
}

for target in ${targets}; do
	git -c "http.extraheader=${auth}" fetch --quiet origin "+refs/heads/${target}:refs/remotes/origin/${target}"
	picks="$(sh "${HERE}/ci-promotion.sh" --list-missing "origin/${target}" "${MERGE_SHA}")"
	if [ -z "${picks}" ]; then
		printf -- '- `%s`: already carries everything; nothing to back-port.\n' "${target}" >>"${body}"
		continue
	fi
	branch="backport/${PR}-to-$(printf '%s' "${target}" | tr '/' '-')"
	git switch --quiet -C "${branch}" "origin/${target}"
	status=clean
	for c in ${picks}; do
		if git cherry-pick -x "${c}" >/dev/null 2>&1; then
			continue
		fi
		if only_generated_conflicts && changie merge >/dev/null 2>&1 && git add -A &&
			[ -z "$(git diff --name-only --diff-filter=U)" ] && GIT_EDITOR=true git cherry-pick --continue >/dev/null 2>&1; then
			continue
		fi
		git cherry-pick --abort
		status="conflict at $(git log -1 --format=%h "${c}")"
		break
	done
	reverts="$(for c in ${picks}; do git log -1 --format=%s "${c}"; done | grep -c '^Revert "' || true)"
	commands="git fetch origin && git switch -c ${branch} origin/${target} && git cherry-pick -x $(printf '%s' "${picks}" | tr '\n' ' ')"
	if [ "${status}" = clean ] && git -c "http.extraheader=${auth}" push --quiet origin "HEAD:refs/heads/${branch}" 2>/dev/null; then
		if [ "${BACKPORT_OPEN_PR:-false}" = true ] && [ "${reverts}" = 0 ]; then
			gh pr create --base "${target}" --head "${branch}" --title "backport: #${PR} into ${target}" \
				--body "Back-port of #${PR}. Merge with **Rebase and merge** so the cherry-pick trailers reach ${target}." >/dev/null
			printf -- '- `%s`: back-port PR opened from `%s`.\n' "${target}" "${branch}" >>"${body}"
		else
			printf -- '- `%s`: [open the back-port PR](https://github.com/%s/compare/%s...%s?expand=1) from `%s`. Merge it with **Rebase and merge** so the cherry-pick trailers reach `%s`.\n' \
				"${target}" "${REPO}" "${target}" "${branch}" "${branch}" "${target}" >>"${body}"
		fi
		[ "${reverts}" = 0 ] || printf '  It carries a revert: decide whether `%s` should get it too before opening the PR.\n' "${target}" >>"${body}"
	else
		[ "${status}" = clean ] && status='push refused (a workflow file needs a human push)'
		printf -- '- `%s`: needs a human (%s). Run:\n\n  ```sh\n  %s\n  ```\n\n  then open a PR into `%s` and merge it with **Rebase and merge**.\n' \
			"${target}" "${status}" "${commands}" "${target}" >>"${body}"
	fi
	git switch --quiet --detach "${MERGE_SHA}"
done

gh pr comment "${PR}" --body-file "${body}"
rm -f "${body}"
