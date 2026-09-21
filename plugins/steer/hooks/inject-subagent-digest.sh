#!/usr/bin/env sh
# steer SubagentStart hook - hand a spawned subagent the short digest of the
# standards that bind it.
#
# WHY THIS EXISTS
#   The always-on ruleset is delivered as SessionStart additionalContext, and a
#   subagent does not inherit it: the Agent tool starts a fresh conversation with
#   its own context. So a general-purpose subagent that edits code during
#   /steer:work ran with none of the testing, secrets, scope or gate rules, and
#   steer-reviewer audited a slice against standards nobody handed it. Rule
#   the context-hygiene standard actively steers heavy work TO subagents, so that is not a
#   marginal share of steer-governed work (#515).
#
#   A DIGEST, not the ruleset. The full payload is ~60k characters and would be
#   paid per spawn - defeating the point of delegating for a fresh window, and
#   requiring the parted delivery inject-standards.sh needs for the 10k
#   per-command cap. The digest is one part, well under the cap, and carries only
#   what governs an agent doing a bounded piece of work: stay in scope, report what
#   you find, follow local patterns, test what you change, no secrets, never merge
#   or deploy. Anything more specific it can read from rules/ - which the digest
#   says.
#
#   MATCHERS ARE THE SAFETY BOUNDARY, and they live in hooks.json: only
#   `^general-purpose$` (the one that edits) and `^steer:steer-reviewer$` (a
#   plugin-scoped id, so it is anchored - the colon puts it on the regex path).
#   Explore and Plan are deliberately excluded: they read and propose, they pay
#   nothing today, and they must stay that way. This script re-checks the type
#   rather than trusting the matcher, so a future hooks.json edit that widens a
#   matcher cannot silently start injecting into every subagent.
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq, fail-open - a subagent that
# starts without the digest is worse off, but a subagent that fails to start is
# worse still.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"

AGENT="$(steer_field agent_type)"
case "${AGENT}" in
general-purpose | steer:steer-reviewer) ;;
*) exit 0 ;;
esac

DIGEST="${CLAUDE_PLUGIN_ROOT}/hooks/subagent-digest.md"
[ -f "${DIGEST}" ] || exit 0

printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":%s}}\n' \
	"$(steer_json_string <"${DIGEST}")"
exit 0
