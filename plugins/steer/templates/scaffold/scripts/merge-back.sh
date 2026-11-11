#!/usr/bin/env sh
# shellcheck disable=SC2016 # the backticks are Markdown in the PR comment, never command substitution
# steer - after a release or hotfix PR merges into prod, merge prod back into main.
# Rationale: /steer:reference conventions -> "Deployment & environments". Run by .github/workflows/merge-back.yml.
#
# Pushes merge-back/<pr>-to-<target> at prod's merge commit and comments a link to open the PR. The
# targets are the default branch, and for a hotfix the open release branch too: one branch each, so a
# conflict resolved for one target never reaches the other. MERGE_BACK_OPEN_PR=true (an App token,
# never GITHUB_TOKEN) opens the PR itself.
set -eu

: "${PR:?}" "${HEAD_REF:?}" "${MERGE_SHA:?}" "${REPO:?}" "${DEFAULT_BRANCH:?}" "${GH_TOKEN:?}"

auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "${GH_TOKEN}" | base64 | tr -d '\n')"

targets="${DEFAULT_BRANCH}"
case "${HEAD_REF}" in
hotfix/*)
	release="$(gh pr list --base prod --state open --json headRefName --jq '.[].headRefName' | grep '^release/' | head -n 1 || true)"
	[ -z "${release}" ] || targets="${targets} ${release}"
	;;
esac

body="$(mktemp)"
printf '### Merge-back of #%s\n\n' "${PR}" >"${body}"
opened=''

for target in ${targets}; do
	git -c "http.extraheader=${auth}" fetch --quiet origin "+refs/heads/${target}:refs/remotes/origin/${target}"
	if git merge-base --is-ancestor "${MERGE_SHA}" "origin/${target}"; then
		printf -- '- `%s`: already contains prod; nothing to merge back.\n' "${target}" >>"${body}"
		continue
	fi
	opened=yes
	branch="merge-back/${PR}-to-$(printf '%s' "${target}" | tr '/' '-')"
	link="https://github.com/${REPO}/compare/${target}...${branch}?expand=1"
	if git -c "http.extraheader=${auth}" ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
		printf -- '- `%s`: `%s` already exists from an earlier run; [open the PR](%s) from it.\n' "${target}" "${branch}" "${link}" >>"${body}"
		continue
	fi
	reverts="$(git log --format=%s "origin/${target}..${MERGE_SHA}" | grep -c '^Revert "' || true)"
	pushlog="$(mktemp)"
	if git -c "http.extraheader=${auth}" push --quiet origin "${MERGE_SHA}:refs/heads/${branch}" 2>"${pushlog}"; then
		if [ "${MERGE_BACK_OPEN_PR:-false}" = true ] && [ "${reverts}" = 0 ]; then
			gh pr create --base "${target}" --head "${branch}" --title "merge-back: #${PR} into ${target}" \
				--body "Merge-back of #${PR}. Merge with **Create a merge commit**, never squash." >/dev/null
			printf -- '- `%s`: merge-back PR opened from `%s`.\n' "${target}" "${branch}" >>"${body}"
		else
			printf -- '- `%s`: [open the merge-back PR](%s) from `%s`.\n' "${target}" "${link}" "${branch}" >>"${body}"
		fi
		[ "${reverts}" = 0 ] || printf '  It carries a revert: decide whether `%s` keeps it before merging.\n' "${target}" >>"${body}"
	else
		printf -- '- `%s`: needs a human (push refused: %s). Run `git fetch origin && git push origin %s:refs/heads/%s`, then open a PR from it into `%s`.\n' \
			"${target}" "$(grep -m 1 . "${pushlog}" | tr -d '`' || true)" "${MERGE_SHA}" "${branch}" "${target}" >>"${body}"
	fi
	rm -f "${pushlog}"
done

[ -z "${opened}" ] || printf '\nMerge each with **Create a merge commit**, never squash: a squashed merge-back leaves prod out of the target, and the next Release PR fails `ci:promotion`. Resolve a conflict on the merge-back branch by merging the target into it (`git merge origin/<target>`), never with a commit of its own and never on prod.\n' >>"${body}"

gh pr comment "${PR}" --body-file "${body}"
rm -f "${body}"
