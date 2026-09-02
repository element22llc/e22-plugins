#!/usr/bin/env sh
# steer SessionEnd hook — stop a linked worktree's backing services on exit.
#
# WHY THIS EXISTS
#   Rule `99-end-of-session` asked the agent to tear down the services a worktree
#   started. A rule can only ask, it costs always-on bytes every session, and the
#   moment it matters is the moment the session is over. SessionEnd is that
#   moment, and it is a real event — so the port-freeing half of that checklist
#   item is now attempted automatically instead of requested (best-effort: see
#   the 1.5s budget below). The volume-destroying half belongs to WorktreeRemove;
#   see hooks/lib/worktree-lifecycle.sh for why they differ.
#
# WHAT IT WILL NOT DO
#   * Never touches a plain checkout. A dev's main stack is theirs; only a LINKED
#     worktree's per-worktree compose project is in scope.
#   * Never removes volumes. `docker:down` keeps data — a session ending is not
#     the worktree ending, and the dev may still be in that checkout from a plain
#     terminal.
#   * Never acts on `reason=clear` or `reason=resume`. Those are continuations of
#     the same working session (`/clear`, a resume) — the rules are re-injected
#     by the SessionStart `compact|clear|resume|fork` matcher precisely because work
#     goes on. Tearing services down there would break the session that follows.
#
#   `STEER_NO_WORKTREE_TEARDOWN=1` disables it entirely.
#
# MECHANISM
#   SessionEnd carries no decision control — it cannot block session termination —
#   and the harness discards its JSON output fields (`systemMessage` and the rest).
#   An `exit 2` would surface stderr to the user, but a teardown has nothing worth
#   interrupting a shutdown for, so this hook stays silent and always exits 0.
#   Everything it does is a side effect or nothing at all.
#
# BEST-EFFORT, NOT GUARANTEED — THE 1.5s BUDGET
#   SessionEnd hooks share a 1.5-second budget, and a timeout declared by a
#   PLUGIN does not raise it: the `"timeout": 60` on this registration in
#   hooks.json is inert, because only a timeout in a user's own settings file
#   raises the budget (to at most 60s). A hook cancelled at the budget has its
#   output discarded and its work left unfinished. `mise tasks ls` plus
#   `mise run -C … docker:down` will often not finish inside 1.5s, so treat this
#   hook as an opportunistic port-freeing pass, NOT a guarantee that containers
#   stopped. `WorktreeRemove` is the reliable half — it takes the ordinary
#   command-hook timeout, so the 60s there is real.
#
#   A dev who wants the full teardown to fit can raise the budget themselves:
#   `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000 claude`.
#
#   (Upstream contract, verified verbatim:
#   https://docs.claude.com/en/docs/claude-code/hooks.md — "SessionEnd hooks have
#   a default timeout of 1.5 seconds. … Timeouts set on plugin-provided hooks
#   don't raise the budget." and the exit-code-2 table row "SessionEnd | No |
#   Shows stderr to user only".)
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
