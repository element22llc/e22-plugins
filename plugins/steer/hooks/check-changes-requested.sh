#!/usr/bin/env sh
# steer SessionStart check - the session user's own PRs with changes requested.
#
# WHY THIS EXISTS
#   PRs in CHANGES_REQUESTED pile up because nothing shows an author their own:
#   `/steer:work drive` works through review feedback, but only when someone
#   thinks to run it. One line at session start makes the pile visible.
#
# MECHANISM - CACHED, REFRESHED DETACHED
#   Session start stays offline, like every other check: `gh pr list` takes about
#   a second, which the SessionStart latency budget cannot absorb. So the hook
#   prints what the previous session's refresh found, then re-runs itself as
#   `--refresh` detached (the on-session-end.sh pattern) to update the cache for
#   the next one. The cache lives in a private per-user directory under $TMPDIR,
#   never in the repo, keyed by the primary checkout so every worktree shares
#   it. A refresh that fails, times out or reads anything but PR numbers
#   removes the cache: no gh, no auth or no network means no line.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq (gh's --jq is built into gh). Fail-open: always exit 0.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

GH_TIMEOUT_S=5
LISTED_MAX=5

if [ "${1:-}" = --refresh ]; then
	_root="$2"
	_cache="$3"
	_tmp="$(mktemp "${_cache}.XXXXXX" 2>/dev/null)" || exit 0
	date '+%Y-%m-%d %H:%M' >"${_tmp}"
	(cd "${_root}" && exec gh pr list --author @me --search review:changes_requested \
		--limit 100 --json number --jq '.[].number') >>"${_tmp}" 2>/dev/null </dev/null &
	_gh=$!
	(sleep "${GH_TIMEOUT_S}" && kill "${_gh}") >/dev/null 2>&1 </dev/null &
	_watchdog=$!
	wait "${_gh}"
	_rc=$?
	# Killed straight after gh is reaped, so pid reuse cannot plausibly hit it.
	kill "${_watchdog}" 2>/dev/null
	if [ "${_rc}" -ne 0 ] || sed 1d "${_tmp}" | grep -qv '^[0-9]\{1,7\}$'; then
		rm -f "${_tmp}" "${_cache}"
		exit 0
	fi
	mv -f "${_tmp}" "${_cache}" || rm -f "${_tmp}"
	exit 0
fi

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
steer_have_jq
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Cheapest gates first: each jq spawn here costs every session ~40 ms.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
steer_tracker_is_github "${ROOT}" || exit 0
# Copilot hosts run this hooks.json too but discard SessionStart raw text.
[ "$(steer_hook_host)" = claude ] || exit 0
case "$(steer_field source)" in
clear | compact | fork) exit 0 ;;
esac
case "$(steer_spine_state "${ROOT}")" in
managed | openspec) ;;
*) exit 0 ;;
esac
command -v gh >/dev/null 2>&1 || exit 0

# $TMPDIR may be a shared /tmp: only a directory this user owns, with no one
# else's access, keeps another user's symlink, FIFO or numbers out of the cache.
USER_ID="$(id -u)"
DIR="${TMPDIR:-/tmp}/steer-${USER_ID}"
mkdir -m 700 "${DIR}" 2>/dev/null
# find, not `test -O` (not POSIX): a real directory, this user's, mode 700.
[ -n "$(find "${DIR}" -prune -type d -user "${USER_ID}" -perm 700 2>/dev/null)" ] || exit 0
KEY="$(steer_primary_worktree "${ROOT}" | cksum | cut -d' ' -f1)"
CACHE="${DIR}/changes-requested.${KEY}"

# Read once and capped, and every byte printed is validated: a stamp, then PR
# numbers of at most 7 digits, so the line stays well under the stdout cap.
CONTENT=""
[ -f "${CACHE}" ] && CONTENT="$(dd if="${CACHE}" bs=4096 count=1 2>/dev/null)"
CHECKED="$(printf '%s\n' "${CONTENT}" | head -n 1)"
LIST="$(printf '%s\n' "${CONTENT}" | sed 1d)"
case "${CHECKED}" in
[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]) ;;
*) CHECKED="" ;;
esac
if [ -n "${CHECKED}" ] && [ -n "${LIST}" ] &&
	! printf '%s\n' "${LIST}" | grep -qv '^[0-9]\{1,7\}$'; then
	COUNT="$(printf '%s\n' "${LIST}" | grep -c .)"
	if [ "${COUNT}" -gt 0 ]; then
		NUMBERS="$(printf '%s\n' "${LIST}" | head -n "${LISTED_MAX}" | sed 's/^/#/' | tr '\n' ' ')"
		NUMBERS="${NUMBERS% }"
		[ "${COUNT}" -gt "${LISTED_MAX}" ] && NUMBERS="${NUMBERS} ..."
		printf '<!-- steer: changes requested on your PRs -->\n'
		printf 'At the last check (%s), the user had %s open PR(s) of their own in this repo with changes requested in review: %s. ' "${CHECKED}" "${COUNT}" "${NUMBERS}"
		printf 'Mention it once in your first reply and point to `/steer:work drive`, which works through review feedback on their open PRs.\n'
	fi
fi

SELF="${CLAUDE_PLUGIN_ROOT}/hooks/check-changes-requested.sh"
if command -v setsid >/dev/null 2>&1; then
	set -- setsid sh "${SELF}" --refresh "${ROOT}" "${CACHE}"
elif command -v perl >/dev/null 2>&1; then
	set -- perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' sh "${SELF}" --refresh "${ROOT}" "${CACHE}"
else
	set -- sh "${SELF}" --refresh "${ROOT}" "${CACHE}"
fi
(
	trap '' HUP
	"$@" >/dev/null 2>&1 </dev/null &
)
exit 0
