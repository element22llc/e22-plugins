#!/usr/bin/env sh
# finish-preflight.sh - the deterministic checks /steer:work finish runs on the
# committed HEAD before the push, so a defect a script can see never costs a
# review round (issue #1025).
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/finish-preflight.sh" [--remote <name>] [--base <branch>] [<check>...]
#   No <check> runs them all. --base names the stack parent of a dependent
#   branch; without it an open PR's base is read, else the default branch.
#
# CHECKS
#   base  `git merge-tree` of HEAD against the freshly fetched default branch,
#         or the stack parent; a parent whose PR merged or closed is reported.
#         A merged parent is replaced by the base it merged into, merged from
#         the fork point, which predicts `git rebase --onto` after a squash-merge.
#         Long-lived bases (prod, staging, develop, release/*) are no parents.
#         GitHub retargets a child PR when its merged parent's branch is
#         deleted, which hides that parent: pass --base <parent> for a stack.
#
# WHETHER IT MODIFIES ANYTHING
#   Never HEAD, a branch, the index or the working tree. It fetches the target
#   into its remote-tracking ref (and objects, FETCH_HEAD) and writes no other
#   ref. Never prompts: git and gh credential prompts are off.
#
# OUTPUT (stdout) - one TAB-separated line per finding:  <check>\t<status>\t<detail>
#   base  against        <remote>/<branch>          (what HEAD was checked against)
#   base  clean
#   base  conflict       <path>                    (one line per path, C-quoted)
#   base  parent-merged  <branch> #<pr> <head-sha>
#   base  parent-closed  <branch> #<pr>
#   base  unchecked      <reason>
#   Anything it cannot determine (no remote, offline, no gh, git < 2.40) is
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

fetch() { # <branch> - into <remote>/<branch>, the ref merge-tree reads
	git check-ref-format "refs/heads/$1" &&
		git fetch -q --no-tags "${REMOTE}" "+refs/heads/$1:refs/remotes/${REMOTE}/$1" 2>/dev/null
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
	branch="$(git symbolic-ref -q --short HEAD)"
	if [ -z "${target}" ] && [ -n "${branch}" ] && [ "${branch}" != "${default}" ]; then
		if command -v gh >/dev/null 2>&1 &&
			prs="$(gh pr list --head "${branch}" --state open --json baseRefName --jq '.[].baseRefName' 2>/dev/null)"; then
			target="$(printf '%s\n' "${prs}" | sed -n 1p)"
		else
			emit base unchecked "PR base of ${branch}: gh unavailable, a stack parent would be missed"
		fi
	fi
	[ -n "${target}" ] || target="${default}"

	fork=""
	case "${target}" in
	"${default}" | prod | production | staging | develop | release/* | releases/*) ;;
	*)
		if command -v gh >/dev/null 2>&1 &&
			prs="$(gh pr list --head "${target}" --state all --json state,number,headRefOid,baseRefName \
				--jq 'sort_by(.number) | reverse | .[] | "\(.state) \(.number) \(.headRefOid) \(.baseRefName)"' 2>/dev/null)"; then
			newest="$(printf '%s\n' "${prs}" | sed -n 1p)"
			num="$(printf '%s' "${newest}" | cut -d' ' -f2)"
			oid="$(printf '%s' "${newest}" | cut -d' ' -f3)"
			into="$(printf '%s' "${newest}" | cut -d' ' -f4)"
			if printf '%s\n' "${prs}" | grep -q '^OPEN '; then
				:
			elif [ "${newest%% *}" = MERGED ]; then
				emit base parent-merged "${target} #${num} ${oid}"
				git cat-file -e "${oid}^{commit}" 2>/dev/null ||
					git fetch -q --no-tags "${REMOTE}" "refs/pull/${num}/head" 2>/dev/null
				fork="$(git merge-base HEAD "${oid}" 2>/dev/null)" || {
					emit base unchecked "head ${oid} of merged parent ${target} not fetched"
					return
				}
				target="${into:-${default}}"
			elif [ "${newest%% *}" = CLOSED ]; then
				emit base parent-closed "${target} #${num}"
			fi
		else
			emit base unchecked "PR state of parent ${target}: gh unavailable"
		fi
		;;
	esac

	emit base against "${REMOTE}/${target}"
	{ fetch "${target}" && git rev-parse -q --verify "refs/remotes/${REMOTE}/${target}^{commit}" >/dev/null; } || {
		emit base unchecked "fetch of ${REMOTE}/${target} failed"
		return
	}
	out="$(git merge-tree --write-tree --name-only --no-messages ${fork:+--merge-base="${fork}"} \
		HEAD "refs/remotes/${REMOTE}/${target}" 2>/dev/null)"
	rc=$?
	# rc 1 is also what an unresolvable ref returns, so only a tree OID line
	# followed by paths counts as a conflict.
	paths="$(printf '%s\n' "${out}" | sed 1d | grep -v '^$')"
	if [ "${rc}" -eq 0 ]; then
		emit base clean
	elif [ "${rc}" -eq 1 ] && [ -n "${paths}" ] &&
		printf '%s\n' "${out}" | sed -n 1p | grep -Eq '^[0-9a-f]{40}([0-9a-f]{24})?$'; then
		printf '%s\n' "${paths}" | while IFS= read -r p; do emit base conflict "${p}"; done
	else
		emit base unchecked "git merge-tree failed (rc ${rc}; needs git 2.40+ and shared history)"
	fi
}

for c in "$@"; do
	"check_${c}"
done
