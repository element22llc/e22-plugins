# shellcheck shell=sh
# (sourced, not executed — no shebang; the directive sets ShellCheck's dialect.)
#
# steer hook helper — tear down a linked worktree's local backing services.
#
# WHY THIS EXISTS
#   Rule `99-end-of-session` asks the agent to tear down the services a worktree
#   started ("no orphaned containers, volumes, or held ports"). Asking is all a
#   rule can do: it is prose in the always-on payload, it costs bytes every
#   session, and the one moment it matters — the worktree going away — is the
#   moment nobody is reading a checklist. `SessionEnd` and `WorktreeRemove` fire
#   exactly there, so the teardown becomes something that HAPPENS rather than
#   something that is requested.
#
# THE TWO MODES ARE NOT THE SAME ACT
#   stop   `docker:down` — stops this worktree's containers, KEEPS its volumes.
#          Used at SessionEnd. A session ending is not the worktree ending: the
#          dev may still be working in that checkout from a plain terminal, so
#          this frees held ports and CPU and touches no data.
#   clean  `docker:clean` — down + volumes + orphans. Used at WorktreeRemove,
#          where the checkout itself is about to be deleted and its per-worktree
#          volumes are, by construction, unreachable afterwards. This is the
#          command rule `24-worktrees` names for that moment.
#
#   Destroying volumes is only ever done on the `clean` path, and only when the
#   harness has told us the worktree is being removed. Nothing here removes data
#   because a session ended.
#
# GATING — every one of these must hold before anything runs:
#   * a LINKED worktree (a plain checkout's stack is the dev's main stack and is
#     never touched — the same boundary check-worktree-trust.sh draws);
#   * `mise` on PATH, and the task actually defined in that worktree's task set
#     (`docker:clean` in a normal repo, `ws:docker:clean` in a workspace root —
#     the scaffold's `ws:` prefixing invariant, see profiles/workspace/mise.toml);
#   * a compose file present, so a `library`/`cli` repo that pruned `docker:*`
#     pays nothing;
#   * `STEER_NO_WORKTREE_TEARDOWN` unset — the escape hatch for a dev who wants
#     their worktree stacks left alone.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Silent and fail-soft throughout: both calling events discard
#   stdout, stderr and exit code, so there is no channel to report a problem on
#   and no value in failing loudly. Never blocks — WorktreeCreate/WorktreeRemove
#   treat a nonzero exit as a veto, so the callers always exit 0.

# steer_wt_is_linked <root> — true when <root> is a linked worktree, i.e. it has a
# primary checkout that is not itself. Subprocess-free (reads the `.git` file).
steer_wt_is_linked() {
	_wl_root="$1"
	[ -n "${_wl_root}" ] || return 1
	_wl_primary="$(steer_primary_worktree "${_wl_root}")"
	[ -n "${_wl_primary}" ] && [ "${_wl_primary}" != "${_wl_root}" ]
}

# steer_wt_has_compose <root> — true when the worktree ships a compose file, the
# only thing the docker:* tasks act on.
steer_wt_has_compose() {
	for _wc_f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
		[ -f "$1/${_wc_f}" ] && return 0
	done
	return 1
}

# steer_wt_task <root> <suffix> — the mise task name to run for <suffix>
# (`down` / `clean`) in <root>: `docker:<suffix>` when that task is defined there,
# else `ws:docker:<suffix>` when THAT is (a workspace root, where every task is
# `ws:`-prefixed so it cannot shadow a member's). Empty when neither exists —
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

# steer_wt_teardown <root> <stop|clean> — run the matching teardown task in <root>.
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
	# COMPOSE_PROJECT_NAME — that scoping is what keeps a sibling worktree's stack
	# untouched. An untrusted config makes mise refuse and this exits quietly,
	# which is the correct outcome: nothing was started from an unloadable config.
	mise run -C "${_td_root}" "${_td_task}" >/dev/null 2>&1 || :
	return 0
}
