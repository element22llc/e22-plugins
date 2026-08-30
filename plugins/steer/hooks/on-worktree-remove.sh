#!/usr/bin/env sh
# steer WorktreeRemove hook — full teardown before a worktree is deleted.
#
# WHY THIS EXISTS
#   Rule `24-worktrees` names `mise run docker:clean` (down + volumes + orphans)
#   as the thing to run before removing a worktree, and rule `99-end-of-session`
#   repeats it as a checklist item. Both are prose: they ask, and the ask is
#   easily missed at exactly the moment it stops being recoverable — once the
#   checkout is gone, its per-worktree compose project is orphaned with no
#   working directory left to run `docker compose down` from, and its named
#   volumes are unreachable by any task. WorktreeRemove fires while the worktree
#   is still on disk, which is the only window in which the cleanup is cheap.
#
# WHY IT MAY REMOVE VOLUMES HERE AND NOT AT SessionEnd
#   The harness has told us the checkout is being destroyed. The scaffold gives
#   each worktree its own COMPOSE_PROJECT_NAME (scripts/worktree-env.sh), so the
#   volumes in scope belong to a checkout that is about to stop existing — they
#   are not shared with the primary checkout or a sibling worktree. A session
#   merely ending carries no such guarantee, so on-session-end.sh stops
#   containers and keeps data. See hooks/lib/worktree-lifecycle.sh.
#
#   `STEER_NO_WORKTREE_TEARDOWN=1` disables it entirely.
#
# MECHANISM
#   The payload carries `worktree_path` — the worktree being removed, which is
#   NOT necessarily the session's cwd (a subagent's `isolation: worktree` tree, a
#   background session's). Act on that path, never on cwd.
#
#   WorktreeRemove carries no decision control: the harness discards this hook's
#   output and exit code, so it can neither report a problem nor stop the removal.
#   This exits 0 regardless: steer is not the gate (rule `95-not-the-gate`), and
#   least of all the gate on someone else's cleanup. It also never removes the
#   worktree itself; declining to do so is what leaves Claude Code's own git handling in
#   charge.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Invoked via an explicit `sh` prefix, so the executable bit
#   does not matter. Output is discarded by the harness — silent throughout.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/worktree-lifecycle.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"

WT="$(steer_field worktree_path)"
[ -n "${WT}" ] || exit 0

steer_wt_teardown "${WT}" clean || :
exit 0
