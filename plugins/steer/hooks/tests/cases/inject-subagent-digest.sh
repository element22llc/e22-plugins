#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# inject-subagent-digest.sh (SubagentStart) - hands a spawned subagent the short
# digest of the standards that bind it. A subagent inherits none of the session's
# SessionStart context, so without this it edits or reviews rule-less (#515).
# ---------------------------------------------------------------------------
sa_json() { # <agent_type>
	printf '{"session_id":"s","transcript_path":"/t","cwd":"%s","hook_event_name":"SubagentStart","agent_id":"agent-1","agent_type":"%s"}' "${WORK}" "$1"
}
sa_ctx() { printf '%s' "$1" | sed -n 's/.*"additionalContext":"\(.*\)"}}$/\1/p'; }

# (a) the two matched types get the digest, as SubagentStart additionalContext.
for _t in general-purpose steer:steer-reviewer; do
	out="$(run_hook inject-subagent-digest.sh "$(sa_json "${_t}")")"
	assert_rc "subagent-digest: ${_t} exits 0" "$(last_rc)" 0
	case "${out}" in
	'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"'*'"}}') ok ;;
	*) bad "subagent-digest: ${_t} must emit the SubagentStart envelope (got: $(printf '%s' "${out}" | head -c 90))" ;;
	esac
	assert_has "subagent-digest: ${_t} is told to stay in scope" "${out}" 'Stay in the scope'
	assert_has "subagent-digest: ${_t} is told never to merge or deploy" "${out}" 'Never merge, never deploy'
done

# (b) Explore and Plan pay NOTHING. They read and propose; widening the matcher to
# them is the regression this asserts against - the script re-checks the type
# rather than trusting hooks.json, so a widened matcher still injects nothing.
for _t in Explore Plan general-purpose-ish steer:steer-reviewer-x ''; do
	out="$(run_hook inject-subagent-digest.sh "$(sa_json "${_t}")")"
	assert_empty "subagent-digest: '${_t}' gets nothing" "${out}"
	assert_rc "subagent-digest: '${_t}' still exits 0" "$(last_rc)" 0
done

# (c) the digest stays a DIGEST. The whole point is that a subagent does not pay
# the ~60k ruleset per spawn, and the 10k per-hook-command cap is a hard ceiling.
SA_BYTES="$(wc -c <"${HOOKS}/subagent-digest.md" | tr -d ' ')"
[ "${SA_BYTES}" -le 2048 ] && ok ||
	bad "subagent-digest.md is ${SA_BYTES} bytes - the digest budget is 2048 (say less, or move it to rules/)"
out="$(run_hook inject-subagent-digest.sh "$(sa_json general-purpose)")"
[ "$(printf '%s' "${out}" | wc -c | tr -d ' ')" -lt 10000 ] && ok ||
	bad "subagent-digest: emitted payload exceeds the 10k per-hook-command cap"

# (d) fail-open: no digest file, or empty stdin, is silence rather than a crash -
# a subagent that starts without the digest is worse off, one that fails to start
# is worse still.
SA_NODIGEST="${WORK}/plugin-no-digest"
mkdir -p "${SA_NODIGEST}/hooks/lib"
cp "${HOOKS}/lib/json.sh" "${SA_NODIGEST}/hooks/lib/json.sh"
out="$(ENV="CLAUDE_PLUGIN_ROOT=${SA_NODIGEST}" run_hook inject-subagent-digest.sh "$(sa_json general-purpose)")"
assert_empty "subagent-digest: missing digest file is silent" "${out}"
out="$(run_hook inject-subagent-digest.sh "")"
assert_empty "subagent-digest: empty payload is silent" "${out}"

# (e) registration: matched types are anchored, and the plugin-scoped id must be -
# the colon puts it on the regex path, so an unanchored form would match wider.
SA_MANIFEST="$(tr -d '\\' <"${HOOKS}/hooks.json")"
printf '%s' "${SA_MANIFEST}" | grep -q '"SubagentStart"' && ok ||
	bad "hooks.json: inject-subagent-digest.sh must be registered under SubagentStart"
printf '%s' "${SA_MANIFEST}" | grep -q '\^general-purpose\$' && ok ||
	bad "hooks.json: the general-purpose matcher must be anchored"
printf '%s' "${SA_MANIFEST}" | grep -q '\^steer:steer-reviewer\$' && ok ||
	bad "hooks.json: the plugin-scoped reviewer matcher must be anchored"
printf '%s' "${SA_MANIFEST}" | grep -q 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/inject-subagent-digest.sh"' && ok ||
	bad "hooks.json: inject-subagent-digest.sh must be registered with the sh prefix"

finish
