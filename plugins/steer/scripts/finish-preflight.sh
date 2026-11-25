#!/usr/bin/env sh
# finish-preflight.sh - the deterministic checks /steer:work finish runs on the
# committed HEAD before the push, so a defect a script can see never costs a
# review round (issue #1025).
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/finish-preflight.sh" [--remote <name>] [--base <branch>] [<check>...]
#   No <check> runs them all. --base names the base the PR targets (a stack
#   parent, batch/<slug>, prod); without it an open PR's base is read, else
#   the default branch.
#
# CHECKS
#   base  Predicts, with `git merge-tree`, the merges that bring the freshly
#         fetched base into HEAD, and prints them as `merge` lines. A stack
#         parent whose PR merged is replaced by the base it merged into; after
#         a squash-merge the parent's last head (refs/pull/<n>/head) and the
#         base just before the squash are merged and the squash is recorded
#         with `merge-ours`, so the parent's hunks never conflict with
#         themselves; a branch already holding the squash skips those steps,
#         and a rebase-merged parent is `unchecked`. A merged batch/<slug>
#         base holds no commits of the sibling, so only the new base is
#         merged. A closed parent is
#         reported. A parent GitHub hid by retargeting the PR to the default
#         branch is found in the PR's automatic base-change history. Long-lived
#         bases (prod, production, staging, develop, release/*, releases/*) are
#         never stack parents.
#
# WHETHER IT MODIFIES ANYTHING
#   Never HEAD, a branch, the index or the working tree. It fetches the base,
#   and a merged parent's last head, into remote-tracking refs, pins a
#   squash-merged parent's squash under refs/remotes/<remote>/pull/<n>/, writes
#   objects (unreferenced merge commits for a multi-step prediction). Never
#   prompts: git and gh credential prompts are off.
#
# OUTPUT (stdout) - one TAB-separated line per finding:  <check>\t<status>\t<detail>
#   base  parent-merged  <branch> #<pr>
#   base  parent-closed  <branch> #<pr>
#   base  against        <remote>/<branch>          (the base HEAD was checked against)
#   base  clean
#   base  conflict       <path>                    (one line per path, C-quoted)
#   base  merge          <ref>                     (in order; none when up to date)
#   base  merge-ours     <ref>                     (record a squash this branch holds)
#   base  unchecked      <reason>
#   Anything it cannot determine (no remote, offline, no gh, git < 2.38) is
#   `unchecked`, never a conflict. A finding is never a nonzero exit.
#
# EXIT CODES  0 ran;  2 usage error;  3 not inside a git work tree.
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq.
# NOTE: plugin-internal, NOT shipped into consumer repos - no byte-identical copy.

set -u
GIT_TERMINAL_PROMPT=0
GH_PROMPT_DISABLED=1
export GIT_TERMINAL_PROMPT GH_PROMPT_DISABLED

CHECKS="base"

die() { # <rc> <message>
	printf 'finish-preflight: %s\n' "$2" >&2
	exit "$1"
}
emit() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}"; }

REMOTE=origin
BASE=""
while [ $# -gt 0 ]; do
	case "$1" in
	--remote | --base)
		[ $# -ge 2 ] || die 2 "$1 needs a value"
		case "$2" in -*) die 2 "not a name: $2" ;; esac
		[ "$1" = --remote ] && REMOTE="$2" || BASE="$2"
		shift 2
		;;
	-*) die 2 "unknown option: $1" ;;
	*) break ;;
	esac
done
[ $# -gt 0 ] || set -- ${CHECKS}
for c in "$@"; do
	case " ${CHECKS} " in *" ${c} "*) ;; *) die 2 "unknown check: ${c} (known: ${CHECKS})" ;; esac
done
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 3 "not inside a git work tree"

have_gh() { command -v gh >/dev/null 2>&1; }

fetch() { # <branch> - into <remote>/<branch>, the ref merge-tree reads
	git check-ref-format "refs/heads/$1" &&
		git fetch -q --no-tags "${REMOTE}" "+refs/heads/$1:refs/remotes/${REMOTE}/$1" 2>/dev/null
}

merge_tree() { # <ours> <theirs> - sets MT_RC, MT_OUT
	MT_OUT="$(git merge-tree --write-tree --name-only --no-messages "$1" "$2" 2>/dev/null)"
	MT_RC=$?
}

report() { # from MT_RC/MT_OUT; returns 0 when the result is known
	# rc 1 is also what an unresolvable ref returns, so only a tree OID line
	# followed by paths counts as a conflict.
	paths="$(printf '%s\n' "${MT_OUT}" | sed 1d | grep -v '^$')"
	if [ "${MT_RC}" -eq 0 ]; then
		emit base clean
	elif [ "${MT_RC}" -eq 1 ] && [ -n "${paths}" ] &&
		printf '%s\n' "${MT_OUT}" | sed -n 1p | grep -Eq '^[0-9a-f]{40}([0-9a-f]{24})?$'; then
		printf '%s\n' "${paths}" | while IFS= read -r p; do emit base conflict "${p}"; done
	else
		emit base unchecked "git merge-tree failed (rc ${MT_RC}; needs git 2.38+ and shared history)"
		return 1
	fi
}

check_base() {
	git remote get-url -- "${REMOTE}" >/dev/null 2>&1 || {
		emit base unchecked "no remote named ${REMOTE}"
		return
	}
	default="$(git ls-remote --symref "${REMOTE}" HEAD 2>/dev/null |
		sed -n 's|^ref: refs/heads/\([^	]*\)	HEAD$|\1|p')"
	if [ -z "${default}" ]; then
		default="$(git symbolic-ref -q --short "refs/remotes/${REMOTE}/HEAD")"
		default="${default#"${REMOTE}"/}"
	fi
	[ -n "${default}" ] || {
		emit base unchecked "${REMOTE} unreachable or has no default branch"
		return
	}
	git rev-parse -q --verify "HEAD^{commit}" >/dev/null || {
		emit base unchecked "no commit on HEAD"
		return
	}

	target="${BASE}"
	hidden=""
	branch="$(git symbolic-ref -q --short HEAD)"
	if [ -z "${target}" ] && [ -n "${branch}" ] && [ "${branch}" != "${default}" ]; then
		if have_gh &&
			pr="$(gh pr list --head "${branch}" --state open --json number,baseRefName \
				--jq '.[] | "\(.number) \(.baseRefName)"' 2>/dev/null)"; then
			pr="$(printf '%s\n' "${pr}" | sed -n 1p)"
			target="${pr#* }"
			pr="${pr%% *}"
			if [ -n "${pr}" ] && [ "${target}" = "${default}" ]; then
				# Only GitHub's own retarget hides a parent; a person's base change
				# (BaseRefChangedEvent) is a deliberate un-stack.
				if hidden="$(gh api graphql -F owner='{owner}' -F name='{repo}' -F n="${pr}" -f query='
query($owner: String!, $name: String!, $n: Int!) {
  repository(owner: $owner, name: $name) { pullRequest(number: $n) {
    timelineItems(itemTypes: [AUTOMATIC_BASE_CHANGE_SUCCEEDED_EVENT], last: 1) {
      nodes { ... on AutomaticBaseChangeSucceededEvent { oldBase newBase } } } } } }' \
					--jq '.data.repository.pullRequest.timelineItems.nodes[] | "\(.oldBase) \(.newBase)"' 2>/dev/null)"; then
					hidden="$(printf '%s\n' "${hidden}" | sed -n 1p)"
					if [ "${hidden#* }" = "${target}" ]; then hidden="${hidden%% *}"; else hidden=""; fi
				else
					hidden=""
					emit base unchecked "base history of PR #${pr}: gh unavailable, a merged stack parent would be missed"
				fi
			fi
		else
			emit base unchecked "PR base of ${branch}: gh unavailable, a stack parent would be missed"
		fi
	fi
	[ -n "${target}" ] || target="${default}"

	parent="${hidden:-${target}}"
	pline=""
	src=""
	squash=""
	case "${parent}" in
	"${default}" | prod | production | staging | develop | release/* | releases/*) ;;
	*)
		if have_gh &&
			prs="$(gh pr list --head "${parent}" --state all --json state,number,baseRefName,mergeCommit \
				--jq 'sort_by(.number) | reverse | .[] | "\(.state) \(.number) \(.baseRefName) \(.mergeCommit.oid // "-")"' 2>/dev/null)"; then
			newest="$(printf '%s\n' "${prs}" | sed -n 1p)"
			num="$(printf '%s' "${newest}" | cut -d' ' -f2)"
			into="$(printf '%s' "${newest}" | cut -d' ' -f3)"
			squash="$(printf '%s' "${newest}" | cut -d' ' -f4)"
			if printf '%s\n' "${prs}" | grep -q '^OPEN '; then
				squash=""
			elif [ "${newest%% *}" = MERGED ] && [ -n "${hidden}" ] && [ "${into}" != "${target}" ]; then
				squash=""
				emit base unchecked "parent ${parent} merged into ${into}, not ${target}: left alone"
			elif [ "${newest%% *}" = MERGED ]; then
				case "${num}" in '' | *[!0-9]*)
					emit base unchecked "PR number of parent ${parent} unreadable"
					return
					;;
				esac
				pline="${parent} #${num}"
				case "${parent}" in
				batch/*) squash="" ;;
				*)
					git fetch -q --no-tags "${REMOTE}" \
						"+refs/pull/${num}/head:refs/remotes/${REMOTE}/pull/${num}/head" 2>/dev/null || {
						emit base parent-merged "${pline}"
						emit base against "${REMOTE}/${into:-${default}}"
						emit base unchecked "last head of merged parent ${parent} not fetched"
						return
					}
					src="${REMOTE}/pull/${num}/head"
					;;
				esac
				target="${into:-${default}}"
			else
				squash=""
				[ "${newest%% *}" = CLOSED ] && [ -z "${hidden}" ] && emit base parent-closed "${parent} #${num}"
			fi
		else
			emit base unchecked "PR state of parent ${parent}: gh unavailable"
		fi
		;;
	esac

	ref="refs/remotes/${REMOTE}/${target}"
	{ fetch "${target}" && git rev-parse -q --verify "${ref}^{commit}" >/dev/null; } || {
		[ -z "${pline}" ] || emit base parent-merged "${pline}"
		emit base against "${REMOTE}/${target}"
		emit base unchecked "fetch of ${REMOTE}/${target} failed"
		return
	}

	# The merges that bring the base in. After a squash-merged parent: its last
	# head, the base just before the squash, then the squash recorded with
	# `-s ours` - this branch already holds its content - so the parent's hunks
	# are never merged twice. Both are pinned under refs a fetch does not move
	# (a pruning fetch deletes them, and the merge then fails closed), or
	# `-s ours` could swallow a newer base commit.
	steps=""
	if [ -n "${src}" ] && ! git merge-base --is-ancestor "${src}" "${ref}" 2>/dev/null &&
		! git merge-base --is-ancestor "${squash}" HEAD 2>/dev/null; then
		why=""
		if ! pre="$(git rev-parse -q --verify "${squash}^1" 2>/dev/null)" ||
			! git merge-base --is-ancestor "${squash}" "${ref}" 2>/dev/null; then
			why="merge commit of ${pline} not found on ${REMOTE}/${target}"
		elif git log --format='%ae %at %s' "$(git merge-base "${pre}" "${src}")..${src}" 2>/dev/null |
			grep -Fxq -- "$(git log -1 --format='%ae %at %s' "${pre}")"; then
			# A rebase-merge replays the parent's commits with their author,
			# date and subject; a squash's predecessor is somebody else's work.
			why="${pline} was rebase-merged: bring the base in by hand"
		elif ! printf 'update %s %s\nupdate %s %s\n' \
			"refs/remotes/${REMOTE}/pull/${num}/pre-squash" "${pre}" \
			"refs/remotes/${REMOTE}/pull/${num}/squash" "${squash}" |
			git update-ref --stdin 2>/dev/null; then
			why="could not pin the squash of ${pline}"
		fi
		[ -z "${why}" ] || {
			emit base parent-merged "${pline}"
			emit base against "${REMOTE}/${target}"
			emit base unchecked "${why}"
			return
		}
		steps="merge ${src}
merge ${REMOTE}/pull/${num}/pre-squash
merge-ours ${REMOTE}/pull/${num}/squash
"
	fi
	steps="${steps}merge ${REMOTE}/${target}"
	if [ -n "${pline}" ] && { [ -z "${hidden}" ] || ! git merge-base --is-ancestor "${squash:-${src}}" HEAD 2>/dev/null; }; then
		emit base parent-merged "${pline}"
	fi
	emit base against "${REMOTE}/${target}"

	tip="$(git rev-parse HEAD)"
	done=""
	while read -r kind rev; do
		git merge-base --is-ancestor "${rev}" "${tip}" 2>/dev/null && continue
		if [ "${kind}" = merge-ours ]; then
			tree="$(git rev-parse "${tip}^{tree}")"
		else
			merge_tree "${tip}" "${rev}"
			if [ "${MT_RC}" -ne 0 ]; then
				report || return
				printf '%s%s %s\n' "${done}" "${kind}" "${rev}" | while read -r k r; do emit base "${k}" "${r}"; done
				return
			fi
			tree="$(printf '%s\n' "${MT_OUT}" | sed -n 1p)"
		fi
		tip="$(GIT_AUTHOR_NAME=preflight GIT_AUTHOR_EMAIL=preflight@localhost \
			GIT_COMMITTER_NAME=preflight GIT_COMMITTER_EMAIL=preflight@localhost \
			git commit-tree "${tree}" -p "${tip}" -p "${rev}" -m preflight 2>/dev/null)" || {
			emit base unchecked "could not stage the merge of ${rev}"
			return
		}
		done="${done}${kind} ${rev}
"
	done <<EOF
${steps}
EOF
	emit base clean
	printf '%s' "${done}" | while read -r k r; do emit base "${k}" "${r}"; done
}

for c in "$@"; do
	"check_${c}"
done
