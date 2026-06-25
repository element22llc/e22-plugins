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
#   is the useful nudge. One exception is steered deterministically: if a PO build
#   is mid-flight (spec/BUILD-STATUS.md with an open handoff gate), this hook routes
#   straight back into /steer:build instead of the generic orientation.
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

# An in-progress PO build is the one case we steer DETERMINISTICALLY instead of
# waiting for the user to describe a goal: a returning owner must be put straight
# back into the guided flow, not greeted with a blank "what do you want to do?".
# Signal = spec/BUILD-STATUS.md whose Handoff gate still has an unchecked box
# (`- [ ]`). A handed-off build (every box `- [x]`) carries no `- [ ]` line, so it
# falls through to the generic orientation below — the flow stops nagging once
# the dev has taken over. Fail-soft: an unreadable status file → generic nudge.
BUILD_STATUS="${ROOT}/spec/BUILD-STATUS.md"
if [ -f "${BUILD_STATUS}" ] && grep -q '^- \[ \]' "${BUILD_STATUS}" 2>/dev/null; then
	printf '<!-- steer: in-progress PO build -->\n'
	printf 'An **in-progress PO build** lives here (`spec/BUILD-STATUS.md` has an open '
	printf 'handoff gate). **Resume the guided build now via `/steer:build`**: read '
	printf 'that file first and pick up from its **Current step** — do not restart the '
	printf 'interview or re-ask settled questions, and do not wait for the user to name '
	printf 'a command.\n'
	exit 0
fi

printf '<!-- steer: session orientation -->\n'
printf 'This repo is standards-managed. The user does **not** need to know skill '
printf 'names: when they describe a goal in plain language, route it to the matching '
printf '`/steer:*` skill yourself and announce the routing in one line (per the '
printf 'router rule). If they seem unsure where to start, tell them plainly that they '
printf 'can just say what they want — build a feature, fix a bug, ask what to do next — '
printf 'and you will drive the right workflow.\n'
