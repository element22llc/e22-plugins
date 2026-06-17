#!/usr/bin/env sh
# steer SessionStart hook — natural-language orientation (managed repos).
#
# WHY THIS EXISTS
#   The router rule tells *you* (the model) to route plain-language intent to the
#   right skill — but a non-technical user doesn't see that rule and may assume
#   they must memorize `/steer:*` commands. This hook makes the "just say what you
#   want" affordance a high-salience, session-start signal so an unsure user gets
#   oriented before they go looking for commands they never needed.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path as
#   inject-standards.sh / check-open-questions.sh). Fires ONLY on a fully managed
#   spine — the unmanaged / foreign / damaged cases are owned by
#   check-unmanaged-repo.sh, which speaks instead, so the two never stack. An
#   already-set-up repo is exactly where "describe a goal, I'll drive the workflow"
#   is the useful nudge.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd comes from the SessionStart
#   payload (may be a subdir). Fail-soft: any ambiguity → stay silent.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"

# SessionStart payload carries cwd (may be a subdir); anchor the spine lookup at
# the work-tree root. Not a git repo → fall back to cwd.
# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || exit 0

# This IS the steer source / marketplace repo itself, not a product repo —
# never nag the plugin's own tree.
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Only orient on a complete, version-stamped spine. Unmanaged / foreign / damaged
# spines are handled (and spoken to) by check-unmanaged-repo.sh — stay silent here
# so the session never gets two competing session-start banners.
[ "$(steer_spine_state "${ROOT}")" = "managed" ] || exit 0

printf '<!-- steer: session orientation -->\n'
printf 'This repo is standards-managed. The user does **not** need to know skill '
printf 'names: when they describe a goal in plain language, route it to the matching '
printf '`/steer:*` skill yourself and announce the routing in one line (per the '
printf 'router rule). If they seem unsure where to start, tell them plainly that they '
printf 'can just say what they want — build a feature, fix a bug, ask what to do next — '
printf 'and you will drive the right workflow.\n'
