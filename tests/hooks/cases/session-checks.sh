#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# session-checks.sh - consolidated SessionStart orchestrator. Sequencing only:
# the individual checks stay authoritative (tested above); these cases
# pin the orchestration contract - aggregation, separation, silence, rc 0.
# ---------------------------------------------------------------------------

# (a) one fixture tripping TWO checks: spec/ without .version (unmanaged-repo
#     notice) + a title-only feature intent (template-drift report). Both
#     notices must appear in one combined output, in registration order
#     (drift before unmanaged), separated cleanly.
SC1="$(new_repo scBoth)"
mkdir -p "${SC1}/spec/features/f"
printf '# Some feature\n\njust a title\n' >"${SC1}/spec/features/f/intent.md"
out="$(run_hook session-checks.sh "$(session_json "${SC1}" sc1)")"
assert_has "session-checks: aggregates template-drift notice" "${out}" "## Open questions"
assert_has "session-checks: aggregates unmanaged-repo notice" "${out}" "no spec-spine marker"
_drift_pos="$(printf '%s' "${out}" | grep -n 'Open questions' | head -1 | cut -d: -f1)"
_unmgd_pos="$(printf '%s' "${out}" | grep -n 'no spec-spine marker' | head -1 | cut -d: -f1)"
[ "${_drift_pos:-0}" -lt "${_unmgd_pos:-0}" ] && ok ||
	bad "session-checks: registration order preserved (drift at ${_drift_pos:-?}, unmanaged at ${_unmgd_pos:-?})"

# (b) a healthy managed repo -> every check silent -> orchestrator silent, rc 0.
SC2="$(new_repo scClean)"
managed_spine "${SC2}"
out="$(run_hook session-checks.sh "$(session_json "${SC2}" sc2)")"
assert_empty "session-checks: healthy managed repo silent" "${out}"

# (c) rc 0 even when checks emit notices - a notice is context, not a failure.
out="$(run_hook session-checks.sh "$(session_json "${SC1}" sc1c)")"
assert_eq "session-checks: rc 0 with notices" "$(last_rc)" "0"

# (d) hooks.json registers the orchestrator (not each check individually)
#     for startup|resume|clear|fork - the consolidation this section exists to pin.
_hj="${HOOKS}/hooks.json"
grep -q 'session-checks\.sh' "${_hj}" && ok || bad "session-checks: registered in hooks.json"
for _solo in check-template-drift check-open-questions check-unmanaged-repo surface-faults check-graduation; do
	grep -q "${_solo}\.sh" "${_hj}" && bad "session-checks: ${_solo}.sh must not be registered directly" || ok
done

# (e) every SessionStart matcher carries `fork`. Since Claude Code 2.1.214 a
#     session created with --fork-session, /fork or /branch reports
#     source="fork" (it used to report "resume"), so a matcher without it skips
#     the ruleset, the session checks and the orientation card on every fork.
_ss_total="$(grep -c '"matcher": "startup|' "${_hj}")"
_ss_fork="$(grep -c '"matcher": "startup|[a-z|]*fork"' "${_hj}")"
[ "${_ss_total}" -ge 3 ] && ok || bad "hooks.json: expected >=3 SessionStart matchers, found ${_ss_total}"
assert_eq "hooks.json: every SessionStart matcher carries fork" "${_ss_fork}" "${_ss_total}"

finish
