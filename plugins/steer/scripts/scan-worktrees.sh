#!/usr/bin/env sh
# scan-worktrees.sh - read-only worktree-handling detector for /steer:setup worktrees.
#
# WHAT IT CHECKS
#   Whether a repo's linked worktrees - whoever created them (Claude Code, Orca,
#   Conductor, plain `git worktree add`) - get what the "Parallel worktrees" rule
#   assumes: inherited `mise trust`, per-worktree Compose isolation, the git-ignored
#   boot files copied in, in-repo worktree dirs ignored, a teardown that fires when
#   the worktree is deleted, and no Compose stack left behind by one already gone.
#   Only Claude Code tells steer a worktree is going away (`WorktreeRemove`); every
#   other manager needs its own archive hook, or leaves the orphans this reports.
#
# WHETHER IT MODIFIES ANYTHING
#   No. Reads git metadata, a few repo files, `mise trust --show` and
#   `docker compose ls`. Acting on the findings is the skill's job, on confirmation.
#
# OUTPUT (stdout) - one TAB-separated line per finding:  <check>\t<status>\t<detail>
#   checkout         primary | linked                  <primary checkout path>
#   manager          claude-code | orca | conductor | git | none   <how it was seen>
#   primary-trust    trusted | untrusted | n/a
#   trust            trusted | untrusted | n/a         <linked worktree path>
#   env-isolation    ok | absent | mis-wired | n/a
#   worktreeinclude  ok | absent | incomplete | n/a    <uncovered files, comma-joined>
#   env-copy         missing                           <worktree>: <files>
#   worktree-dir     ignored | unignored               <in-repo worktree dir>
#   teardown         hooked | ok | absent | merge | manual | n/a   <manager>
#   orphan           <compose project>                 <config dir that no longer exists>
#   orphans          <count> | n/a                     <why n/a>
#   A gap is reported on STDOUT, never via a nonzero exit.
#
# EXIT CODES  0 ran OK;  2 usage error;  3 not inside a git work tree.
#
# NOTE: plugin-internal, NOT shipped into consumer repos - no byte-identical copy.

set -u

[ $# -le 1 ] || {
	echo "usage: scan-worktrees.sh [repo-root]" >&2
	exit 2
}

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
. "${HERE}/../hooks/lib/repo-root.sh"
. "${HERE}/../hooks/lib/mise-trust.sh"

ROOT="$(steer_repo_root "${1:-.}")" || {
	echo "scan-worktrees: not inside a git work tree: ${1:-.}" >&2
	exit 3
}
PRIMARY="$(steer_primary_worktree "${ROOT}")"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}"; }

if [ "${PRIMARY}" != "${ROOT}" ]; then
	emit checkout linked "${PRIMARY}"
else
	emit checkout primary "${PRIMARY}"
fi

HAS_COMPOSE=0
for _f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
	[ -f "${ROOT}/${_f}" ] && HAS_COMPOSE=1
done

# The main worktree is always listed first; everything after it is linked.
LINKED_WTS="$(git -C "${ROOT}" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | sed '1d')"

MANAGERS=" "
add_mgr() {
	case "${MANAGERS}" in
	*" $1 "*) ;;
	*)
		MANAGERS="${MANAGERS}$1 "
		emit manager "$1" "$2"
		;;
	esac
}
# Orca also exports CONDUCTOR_* for script compatibility, so it is tested first.
if [ -n "${ORCA_WORKTREE_ID:-}" ] || [ "${TERM_PROGRAM:-}" = "Orca" ]; then
	add_mgr orca "session env"
elif [ -n "${CONDUCTOR_WORKSPACE_PATH:-}${CONDUCTOR_ROOT_PATH:-}" ]; then
	add_mgr conductor "session env"
fi
while IFS= read -r _wt; do
	[ -n "${_wt}" ] || continue
	case "${_wt}" in
	*/.claude/worktrees/*) add_mgr claude-code "${_wt}" ;;
	*/.orca/worktrees/* | */orca/workspaces/*) add_mgr orca "${_wt}" ;;
	*/conductor/workspaces/*) add_mgr conductor "${_wt}" ;;
	*) add_mgr git "${_wt}" ;;
	esac
done <<EOF
${LINKED_WTS}
EOF
[ "${MANAGERS}" != " " ] || emit manager none "no linked worktrees"

if command -v mise >/dev/null 2>&1; then
	_pt="$(steer_trust_state "${PRIMARY}")"
	emit primary-trust "${_pt:-n/a}" "${PRIMARY}"
	while IFS= read -r _wt; do
		[ -n "${_wt}" ] && [ -d "${_wt}" ] || continue
		_t="$(steer_trust_state "${_wt}")"
		emit trust "${_t:-n/a}" "${_wt}"
	done <<EOF
${LINKED_WTS}
EOF
else
	emit primary-trust n/a "mise not on PATH"
fi

if [ "${HAS_COMPOSE}" = 0 ]; then
	emit env-isolation n/a "no compose file"
elif [ ! -f "${ROOT}/scripts/worktree-env.sh" ]; then
	emit env-isolation absent "scripts/worktree-env.sh"
elif grep -q 'scripts/worktree-env.sh' "${ROOT}/mise.toml" 2>/dev/null; then
	emit env-isolation ok
else
	emit env-isolation mis-wired "mise.toml does not source scripts/worktree-env.sh"
fi

# Boot-critical git-ignored files in the primary: what a new worktree cannot boot
# without, and what .worktreeinclude exists to carry. `--directory` keeps a wholly
# ignored tree (node_modules) to one line instead of walking it.
CANDIDATES="$(git -C "${PRIMARY}" ls-files --others --ignored --exclude-standard --directory 2>/dev/null |
	grep -E '(^|/)(\.env(\..+)?|\.?mise\.local\.toml|\.claude/settings\.local\.json)$' |
	grep -vE '(^|/)\.env\.(example|sample|template)$')"
if [ -z "${CANDIDATES}" ]; then
	emit worktreeinclude n/a "no git-ignored boot files in the primary checkout"
else
	_uncovered=""
	while IFS= read -r _c; do
		[ -n "${_c}" ] || continue
		# git's own matcher, limited to the one path, so gitignore semantics hold.
		if [ ! -f "${PRIMARY}/.worktreeinclude" ] ||
			[ -z "$(git -C "${PRIMARY}" ls-files --others --ignored \
				--exclude-from="${PRIMARY}/.worktreeinclude" -- "${_c}" 2>/dev/null)" ]; then
			_uncovered="${_uncovered:+${_uncovered},}${_c}"
		fi
	done <<EOF
${CANDIDATES}
EOF
	if [ ! -f "${PRIMARY}/.worktreeinclude" ]; then
		emit worktreeinclude absent "${_uncovered}"
	elif [ -n "${_uncovered}" ]; then
		emit worktreeinclude incomplete "${_uncovered}"
	else
		emit worktreeinclude ok
	fi
	while IFS= read -r _wt; do
		[ -n "${_wt}" ] && [ -d "${_wt}" ] || continue
		_missing=""
		while IFS= read -r _c; do
			[ -n "${_c}" ] && [ ! -e "${_wt}/${_c}" ] && _missing="${_missing:+${_missing},}${_c}"
		done <<EOF
${CANDIDATES}
EOF
		[ -z "${_missing}" ] || emit env-copy missing "${_wt}: ${_missing}"
	done <<EOF
${LINKED_WTS}
EOF
fi

for _d in .claude/worktrees .orca/worktrees; do
	[ -d "${PRIMARY}/${_d}" ] || continue
	if git -C "${PRIMARY}" check-ignore -q "${_d}/" 2>/dev/null; then
		emit worktree-dir ignored "${_d}"
	else
		emit worktree-dir unignored "${_d}"
	fi
done

for _m in ${MANAGERS}; do
	if [ "${HAS_COMPOSE}" = 0 ]; then
		emit teardown n/a "${_m}"
		continue
	fi
	case "${_m}" in
	claude-code) emit teardown hooked "${_m}" ;;
	orca)
		if [ ! -f "${ROOT}/orca.yaml" ]; then
			emit teardown absent "${_m}"
		elif grep -q 'docker:clean' "${ROOT}/orca.yaml"; then
			emit teardown ok "${_m}"
		else
			emit teardown merge "${_m}"
		fi
		;;
	*) emit teardown manual "${_m}" ;;
	esac
done

# Orphans: Compose projects named the way worktree-env.sh names this repo's linked
# worktrees (`<primary-basename>-<worktree>`) whose config dir is gone.
if ! command -v docker >/dev/null 2>&1; then
	emit orphans n/a "docker not on PATH"
elif ! _ls="$(docker compose ls --all --format json 2>/dev/null)"; then
	emit orphans n/a "docker compose ls failed (daemon down?)"
else
	_prefix="$(basename "${PRIMARY}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_\n-' '-' | sed 's/-\{1,\}/-/g;s/^-//;s/-$//')-"
	_n=0
	_rows="$(printf '%s' "${_ls}" | tr '{' '\n' |
		sed -n 's/.*"Name":"\([^"]*\)".*"ConfigFiles":"\([^",]*\).*/\1|\2/p')"
	while IFS='|' read -r _name _cfg; do
		[ -n "${_name}" ] && [ -n "${_cfg}" ] || continue
		case "${_name}" in "${_prefix}"?*) ;; *) continue ;; esac
		_dir="$(dirname "${_cfg}")"
		[ -d "${_dir}" ] && continue
		emit orphan "${_name}" "${_dir}"
		_n=$((_n + 1))
	done <<EOF
${_rows}
EOF
	emit orphans "${_n}"
fi

exit 0
