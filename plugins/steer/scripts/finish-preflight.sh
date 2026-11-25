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
#         parent whose PR merged is replaced by the base it merged into, and
#         its last head (refs/pull/<n>/head) is merged first, so a squash-merge
#         is no false conflict; a merged batch/<slug> base holds no commits of
#         the sibling, so only the new base is merged. A closed parent is
#         reported. A parent GitHub hid by retargeting the PR to the default
#         branch is found in the PR's base-change history. Long-lived bases
#         (prod, production, staging, develop, release/*, releases/*) are never
#         stack parents.
#
# WHETHER IT MODIFIES ANYTHING
#   Never HEAD, a branch, the index or the working tree. It fetches the base,
#   and a merged parent's last head, into remote-tracking refs, and writes
#   objects (one unreferenced merge commit for a two-step prediction). Never
#   prompts: git and gh credential prompts are off.
#
# OUTPUT (stdout) - one TAB-separated line per finding:  <check>\t<status>\t<detail>
#   base  parent-merged  <branch> #<pr>
#   base  parent-closed  <branch> #<pr>
#   base  against        <remote>/<branch>          (the base HEAD was checked against)
#   base  clean
#   base  conflict       <path>                    (one line per path, C-quoted)
#   base  merge          <ref>                     (in order; none when up to date)
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
				if hidden="$(gh api graphql -F owner='{owner}' -F name='{repo}' -F n="${pr}" -f query='
query($owner: String!, $name: String!, $n: Int!) {
  repository(owner: $owner, name: $name) { pullRequest(number: $n) {
    timelineItems(itemTypes: [BASE_REF_CHANGED_EVENT, AUTOMATIC_BASE_CHANGE_SUCCEEDED_EVENT], last: 1) {
      nodes { ... on BaseRefChangedEvent { previousRefName } ... on AutomaticBaseChangeSucceededEvent { oldBase } } } } } }' \
					--jq '.data.repository.pullRequest.timelineItems.nodes[] | .oldBase // .previousRefName' 2>/dev/null)"; then
					hidden="$(printf '%s\n' "${hidden}" | sed -n 1p)"
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
	src=""
	case "${parent}" in
	"${default}" | prod | production | staging | develop | release/* | releases/*) ;;
	*)
		if have_gh &&
			prs="$(gh pr list --head "${parent}" --state all --json state,number,headRefOid,baseRefName \
				--jq 'sort_by(.number) | reverse | .[] | "\(.state) \(.number) \(.headRefOid) \(.baseRefName)"' 2>/dev/null)"; then
			newest="$(printf '%s\n' "${prs}" | sed -n 1p)"
			num="$(printf '%s' "${newest}" | cut -d' ' -f2)"
			oid="$(printf '%s' "${newest}" | cut -d' ' -f3)"
			into="$(printf '%s' "${newest}" | cut -d' ' -f4)"
			if printf '%s\n' "${prs}" | grep -q '^OPEN '; then
				:
			elif [ "${newest%% *}" = MERGED ]; then
				emit base parent-merged "${parent} #${num}"
				case "${parent}" in
				batch/*) ;;
				*)
					if git fetch -q --no-tags "${REMOTE}" \
						"+refs/pull/${num}/head:refs/remotes/${REMOTE}/pull/${num}/head" 2>/dev/null; then
						src="${REMOTE}/pull/${num}/head"
					elif git cat-file -e "${oid}^{commit}" 2>/dev/null; then
						src="${oid}"
					else
						emit base unchecked "head ${oid} of merged parent ${parent} not fetched"
						return
					fi
					;;
				esac
				target="${into:-${default}}"
			elif [ "${newest%% *}" = CLOSED ] && [ -z "${hidden}" ]; then
				emit base parent-closed "${parent} #${num}"
			fi
		else
			emit base unchecked "PR state of parent ${parent}: gh unavailable"
		fi
		;;
	esac

	emit base against "${REMOTE}/${target}"
	ref="refs/remotes/${REMOTE}/${target}"
	{ fetch "${target}" && git rev-parse -q --verify "${ref}^{commit}" >/dev/null; } || {
		emit base unchecked "fetch of ${REMOTE}/${target} failed"
		return
	}
	tip=HEAD
	merges=""
	if [ -n "${src}" ] && ! git merge-base --is-ancestor "${src}" HEAD 2>/dev/null; then
		merges="${src}"
		merge_tree HEAD "${src}"
		if [ "${MT_RC}" -eq 0 ]; then
			tip="$(GIT_AUTHOR_NAME=preflight GIT_AUTHOR_EMAIL=preflight@localhost \
				GIT_COMMITTER_NAME=preflight GIT_COMMITTER_EMAIL=preflight@localhost \
				git commit-tree "$(printf '%s\n' "${MT_OUT}" | sed -n 1p)" -p HEAD -p "${src}" -m preflight 2>/dev/null)" || {
				emit base unchecked "could not stage the merge of ${src}"
				return
			}
		else
			report || return
			emit base merge "${src}"
			return
		fi
	fi
	git merge-base --is-ancestor "${ref}" "${tip}" 2>/dev/null || merges="${merges:+${merges} }${REMOTE}/${target}"
	merge_tree "${tip}" "${ref}"
	report || return
	for m in ${merges}; do emit base merge "${m}"; done
}

for c in "$@"; do
	"check_${c}"
done
