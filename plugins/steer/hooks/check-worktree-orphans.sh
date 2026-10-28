#!/usr/bin/env sh
# steer SessionStart check - report the Compose stacks deleted worktrees left behind.
#
# WHY THIS EXISTS
#   Claude Code removes the git worktrees it creates itself (`git worktree
#   remove`), and `WorktreeRemove` fires only for a worktree a `WorktreeCreate`
#   hook created - so steer's full teardown never runs for `claude --worktree`,
#   `EnterWorktree` or `isolation: worktree`, and their volumes outlive the
#   checkout. A steer `WorktreeCreate` hook would replace Claude Code's worktree
#   creation in every consumer repo and stop `.worktreeinclude` being processed;
#   reporting the leftovers from the primary checkout costs far less. Report-only:
#   removing volumes deletes data, so /steer:setup worktrees does it on a yes.
#
# GATING - all before any docker call: the primary checkout, a compose file, a
#   `.claude/worktrees` dir (Claude Code worktrees were used here), docker on
#   PATH, `STEER_NO_WORKTREE_TEARDOWN` unset. Silent when nothing is found or
#   docker cannot answer.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Run by session-checks.sh. Fail soft.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/worktree-lifecycle.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/worktree-orphans.sh"

[ -z "${STEER_NO_WORKTREE_TEARDOWN:-}" ] || exit 0

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ "$(steer_primary_worktree "${ROOT}")" = "${ROOT}" ] || exit 0
[ -d "${ROOT}/.claude/worktrees" ] || exit 0
steer_wt_has_compose "${ROOT}" || exit 0

ORPHANS="$(steer_wt_orphans "${ROOT}")" || exit 0
[ -n "${ORPHANS}" ] || exit 0

NAMES="$(printf '%s\n' "${ORPHANS}" | cut -f1 | sed 's/.*/`&`/' | paste -sd ',' - | sed 's/,/, /g')"
COUNT="$(printf '%s\n' "${ORPHANS}" | wc -l | tr -d ' ')"

printf '<!-- steer: worktree orphans -->\n'
printf 'steer: %s Compose stack(s) left by deleted worktrees still hold containers or ' "${COUNT}"
printf 'volumes: %s. Tell the user and offer `/steer:setup worktrees`, which removes ' "${NAMES}"
printf 'them only on their yes (it deletes that data).\n'
