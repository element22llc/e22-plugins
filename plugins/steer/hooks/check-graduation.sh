#!/usr/bin/env sh
# steer SessionStart hook — solo-trunk graduation detector.
#
# WHY THIS EXISTS
#   solo-trunk mode (pre-MVP greenfield: commit straight to main, no PR, branch
#   protection off) is the least-gated phase of the SDLC. It is meant to be
#   temporary, but nothing tells the owner WHEN the repo has outgrown it, so a
#   project can quietly stay ungated long after it has a deploy target or a
#   promotion branch. This hook watches for the local, offline signals that a
#   repo has grown past pre-MVP and nudges the owner to graduate via
#   /steer:protect — which raises the PR wall and flips the delivery-mode marker
#   to pr-flow. The networked signal (a second collaborator) is left to
#   /steer:audit and /steer:protect, which already use gh; this hook stays
#   offline so it adds no latency and no auth dependency to session start.
#
# MECHANISM
#   stdout becomes session `additionalContext` (same path as inject-standards.sh
#   / check-template-drift.sh). Fires ONLY when the repo declares solo-trunk AND
#   at least one local graduation signal is present; SILENT otherwise — a fresh
#   pre-MVP repo and every pr-flow repo get zero noise, and the notice clears
#   itself the moment /steer:protect graduates the repo.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd comes from the SessionStart
#   payload (may be a subdir). Fail-soft: any ambiguity → stay silent. git is
#   used only for branch detection and only if present — this is SessionStart,
#   not the PreToolUse hot path, and git correctly resolves loose/packed/worktree
#   refs that a filesystem peek would miss; absent git, that one signal is skipped.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/graduation.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

ROOT="$(steer_repo_root "${CWD}")" || exit 0

# Only speak in solo-trunk mode; a pr-flow repo has already graduated.
[ "$(steer_delivery_mode "${ROOT}")" = "solo-trunk" ] || exit 0

# Signal detection is shared with the trunk-push PreToolUse gate (in
# check-bash-actions.sh)
# (lib/graduation.sh) so the nudge and the gate can never disagree.
SIGNALS="$(steer_graduation_signals "${ROOT}")"

[ -n "${SIGNALS}" ] || exit 0

printf '<!-- steer: solo-trunk graduation signal -->\n'
printf '# This repo has outgrown solo-trunk — graduate it\n\n'
printf 'This repo is in **solo-trunk** mode (direct-to-`main`, no PR, branch '
printf 'protection off) — appropriate pre-MVP, but these signals say it has '
printf 'outgrown that:\n'
printf '%s\n' "${SIGNALS}"
printf '\nWhile these signals stand, autonomous trunk pushes are gated (the '
printf 'trunk-push gate in check-bash-actions.sh surfaces the first `git push` '
printf 'each session for confirmation). '
printf 'Recommend the user run `/steer:protect` to review branch protection '
printf 'and, on confirmation, raise the PR wall — protection is what defines '
printf 'PR mode, and applying it flips the delivery-mode marker to pr-flow and '
printf 'logs the graduation to /spec/HISTORY.md. This notice (and the push '
printf 'gate) clears once graduated.\n'
