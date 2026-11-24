# shellcheck shell=sh
# (sourced, not executed - no shebang; the directive sets ShellCheck's dialect.)
#
# steer hook helper - tear down a linked worktree's local backing services.
#
# WHY THIS EXISTS
#   Rule `50-done` -> End-of-session checklist asks the agent to stop the dev servers and watchers
#   it started, freeing their ports; the containers a worktree started are this
#   helper's half of that. Asking is all a
#   rule can do: it is prose in the always-on payload, it costs bytes every
#   session, and the one moment it matters - the worktree going away - is the
#   moment nobody is reading a checklist. `SessionEnd` and `WorktreeRemove` fire
#   exactly there, so the teardown is attempted automatically rather than
#   requested. How reliably differs by event, and the difference is not cosmetic:
#   `WorktreeRemove` gets the ordinary command-hook timeout and its declared 60s
#   is real, but it fires only for a worktree a `WorktreeCreate` hook created -
#   never for the ones Claude Code creates and removes itself, whose volumes
#   check-worktree-orphans.sh reports instead; `SessionEnd` hooks share a
#   1.5-second budget that a PLUGIN-declared timeout cannot raise, so
#   on-session-end.sh runs this helper detached rather than inside the budget.
#
# THE TWO MODES ARE NOT THE SAME ACT
#   stop   `docker:down` - stops this worktree's containers, KEEPS its volumes.
#          Used at SessionEnd. A session ending is not the worktree ending: the
#          dev may still be working in that checkout from a plain terminal, so
#          this frees held ports and CPU and touches no data.
#   clean  `docker:clean` - down + volumes + orphans. Used at WorktreeRemove,
#          where the checkout itself is about to be deleted and its per-worktree
#          volumes are, by construction, unreachable afterwards. This is the
#          command rule `47-worktree-services` names for that moment.
#
#   Destroying volumes is only ever done on the `clean` path, and only when the
#   harness has told us the worktree is being removed. Nothing here removes data
#   because a session ended.
#
# GATING - every one of these must hold before anything runs:
#   * a LINKED worktree (a plain checkout's stack is the dev's main stack and is
#     never touched - the same boundary check-worktree-trust.sh draws);
#   * `docker` on PATH (a repo whose stack is never run pays nothing);
#   * `mise` on PATH, and the task actually defined in that worktree's task set
#     (`docker:clean` in a normal repo, `ws:docker:clean` in a workspace root -
#     the scaffold's `ws:` prefixing invariant, see profiles/workspace/mise.toml);
#   * a compose file present, so a `library`/`cli` repo that pruned `docker:*`
#     pays nothing;
#   * `STEER_NO_WORKTREE_TEARDOWN` unset - the escape hatch for a dev who wants
#     their worktree stacks left alone.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Silent and fail-soft throughout. Never blocks - neither
#   calling event carries decision control, so a nonzero exit would stop nothing;
#   the callers always exit 0.
#
#   The two events differ in what they could report, which is why neither caller
#   bothers: `WorktreeRemove` failures are logged in debug mode only, so there is
#   genuinely no user-facing channel there; `SessionEnd` would show stderr to the
#   user on an `exit 2`, but a teardown is not worth interrupting a shutdown for.
#   Both discard their JSON output fields. (Upstream exit-code-2 table, verified
#   verbatim: https://docs.claude.com/en/docs/claude-code/hooks.md - "SessionEnd |
#   No | Shows stderr to user only", "WorktreeRemove | No | Failures are logged in
#   debug mode only".)

# steer_wt_is_linked <root> - true when <root> is a linked worktree, i.e. it has a
# primary checkout that is not itself. Subprocess-free (reads the `.git` file).
steer_wt_is_linked() {
	_wl_root="$1"
	[ -n "${_wl_root}" ] || return 1
	_wl_primary="$(steer_primary_worktree "${_wl_root}")"
	[ -n "${_wl_primary}" ] && [ "${_wl_primary}" != "${_wl_root}" ]
}

# steer_wt_has_compose <root> - true when the worktree ships a compose file, the
# only thing the docker:* tasks act on.
steer_wt_has_compose() {
	for _wc_f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
		[ -f "$1/${_wc_f}" ] && return 0
	done
	return 1
}

# steer_wt_task <root> <suffix> - the mise task name to run for <suffix>
# (`down` / `clean`) in <root>: `docker:<suffix>` when that task is defined there,
# else `ws:docker:<suffix>` when THAT is (a workspace root, where every task is
# `ws:`-prefixed so it cannot shadow a member's). Empty when neither exists -
# a repo that legitimately pruned the docker tasks. One `mise tasks` call.
steer_wt_task() {
	_wt_list="$(mise tasks ls --no-header -C "$1" 2>/dev/null)" || return 1
	for _wt_name in "docker:$2" "ws:docker:$2"; do
		# `mise tasks ls` prints "<name><whitespace><description>"; anchor on the
		# name followed by whitespace or end of line so `docker:down` cannot match
		# a hypothetical `docker:downgrade`.
		printf '%s\n' "${_wt_list}" |
			grep -qE "^${_wt_name}([[:space:]]|\$)" && {
			printf '%s' "${_wt_name}"
			return 0
		}
	done
	return 1
}

# steer_wt_teardown <root> <stop|clean> - run the matching teardown task in <root>.
# Silent; returns 0 whether it ran or declined, so a caller can `|| :` free.
steer_wt_teardown() {
	_td_root="$1"
	_td_mode="$2"

	[ -n "${STEER_NO_WORKTREE_TEARDOWN:-}" ] && return 0
	[ -n "${_td_root}" ] && [ -d "${_td_root}" ] || return 0
	steer_wt_is_linked "${_td_root}" || return 0
	steer_wt_has_compose "${_td_root}" || return 0
	command -v mise >/dev/null 2>&1 || return 0
	command -v docker >/dev/null 2>&1 || return 0

	case "${_td_mode}" in
	stop) _td_suffix="down" ;;
	clean) _td_suffix="clean" ;;
	*) return 0 ;;
	esac

	_td_task="$(steer_wt_task "${_td_root}" "${_td_suffix}")" || return 0
	[ -n "${_td_task}" ] || return 0

	# `-C` so the worktree's own `[env] _.source = "scripts/worktree-env.sh"` sets
	# COMPOSE_PROJECT_NAME - that scoping is what keeps a sibling worktree's stack
	# untouched. An untrusted config makes mise refuse and this exits quietly,
	# which is the correct outcome: nothing was started from an unloadable config.
	mise run -C "${_td_root}" "${_td_task}" >/dev/null 2>&1 || :
	return 0
}

# steer_wt_is_claude <args> - true when a `ps` args line is a Claude Code process:
# the native `claude` binary, or the npm CLI. Matched anywhere, not on the first
# word, because the Desktop app's binary lives under `Application Support/`.
steer_wt_is_claude() {
	case "$1" in
	claude | claude\ * | */claude | */claude\ * | *claude-code/cli.*) return 0 ;;
	esac
	return 1
}

# steer_wt_claude_ancestor - pid of the nearest Claude Code ancestor of this shell.
steer_wt_claude_ancestor() {
	_ca_pid=$$
	_ca_i=0
	while [ "${_ca_i}" -lt 8 ] && [ "${_ca_pid:-0}" -gt 1 ]; do
		if steer_wt_is_claude "$(ps -o args= -p "${_ca_pid}" 2>/dev/null)"; then
			printf '%s' "${_ca_pid}"
			return 0
		fi
		_ca_pid="$(ps -o ppid= -p "${_ca_pid}" 2>/dev/null | tr -d ' ')"
		_ca_i=$((_ca_i + 1))
	done
	return 1
}

# steer_wt_cwd_of <pid> - that process's working directory, via /proc or lsof.
steer_wt_cwd_of() {
	if [ -d "/proc/$1" ]; then
		readlink "/proc/$1/cwd"
		return
	fi
	command -v lsof >/dev/null 2>&1 || return 1
	lsof -a -d cwd -p "$1" -Fn 2>/dev/null | sed -n 's/^n//p'
}

# steer_wt_claude_live <root> [exclude-pid] - true when a Claude Code process
# other than <exclude-pid> has its working directory in <root>. False when it
# cannot tell, so an unreadable process table never blocks the stop.
steer_wt_claude_live() {
	_cl_pids="$(ps -A -o pid= -o args= 2>/dev/null | while read -r _cl_p _cl_a; do
		[ "${_cl_p}" = "${2:-}" ] && continue
		steer_wt_is_claude "${_cl_a}" && printf '%s\n' "${_cl_p}"
	done)"
	for _cl_p in ${_cl_pids}; do
		_cl_cwd="$(steer_wt_cwd_of "${_cl_p}")" || continue
		case "${_cl_cwd}/" in "$1"/*) return 0 ;; esac
	done
	return 1
}
