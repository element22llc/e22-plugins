#!/usr/bin/env sh
# steer SessionEnd hook — stop a linked worktree's backing services on exit.
#
# WHY THIS EXISTS
#   Rule `99-end-of-session` asked the agent to tear down the services a worktree
#   started. A rule can only ask, it costs always-on bytes every session, and the
#   moment it matters is the moment the session is over. SessionEnd is that
#   moment, and it is a real event — so the port-freeing half of that checklist
#   item is now enforced instead of requested (the volume-destroying half belongs
#   to WorktreeRemove; see hooks/lib/worktree-lifecycle.sh for why they differ).
#
# WHAT IT WILL NOT DO
#   * Never touches a plain checkout. A dev's main stack is theirs; only a LINKED
#     worktree's per-worktree compose project is in scope.
#   * Never removes volumes. `docker:down` keeps data — a session ending is not
#     the worktree ending, and the dev may still be in that checkout from a plain
#     terminal.
#   * Never acts on `reason=clear` or `reason=resume`. Those are continuations of
#     the same working session (`/clear`, a resume) — the rules are re-injected
#     by the SessionStart `compact|clear|resume` matcher precisely because work
#     goes on. Tearing services down there would break the session that follows.
#
#   `STEER_NO_WORKTREE_TEARDOWN=1` disables it entirely.
#
# MECHANISM
#   SessionEnd output and exit code are discarded by the harness (only
#   `terminalSequence` is honored), so this hook prints nothing, reports nothing,
#   and always exits 0. Everything it does is a side effect or nothing at all.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Invoked via an explicit `sh` prefix, so the executable bit
#   does not matter. Fail soft: any ambiguity → change nothing.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/worktree-lifecycle.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"

# Only a genuine exit. `clear` / `resume` continue the working session.
case "$(steer_field reason)" in
logout | prompt_input_exit | other) : ;;
*) exit 0 ;;
esac

CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

ROOT="$(steer_repo_root "${CWD}")" || exit 0

steer_wt_teardown "${ROOT}" stop || :
exit 0
