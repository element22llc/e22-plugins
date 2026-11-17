#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# Self-fault recording (lib/report-fault.sh) + surfacing (surface-faults.sh).
# ---------------------------------------------------------------------------

# Recording is deduped by source|signature so a recurring fault is logged once.
RF1="$(new_repo rf1)"
steer_record_fault "${RF1}" "inject-standards.sh" "rules directory missing"
steer_record_fault "${RF1}" "inject-standards.sh" "rules directory missing"
assert_eq "fault: identical faults deduped to one record" \
	"$(grep -c '' "${RF1}/.claude/steer-faults.log")" "1"
steer_record_fault "${RF1}" "other.sh" "different symptom"
assert_eq "fault: distinct faults both recorded" \
	"$(grep -c '' "${RF1}/.claude/steer-faults.log")" "2"

# A signature carrying the delimiter/newline is sanitized, never breaks the row.
RF1b="$(new_repo rf1b)"
steer_record_fault "${RF1b}" "x|y" "a|b"
assert_eq "fault: one record despite embedded delimiter" \
	"$(grep -c '' "${RF1b}/.claude/steer-faults.log")" "1"

# No log -> surface stays silent.
RF2="$(new_repo rf2)"
out="$(run_hook surface-faults.sh "$(session_json "${RF2}" rf2)")"
assert_empty "surface: no fault log -> silent" "${out}"

# A recorded, unsurfaced fault -> notice in context, marker advanced.
RF3="$(new_repo rf3)"
steer_record_fault "${RF3}" "inject-standards.sh" "rules directory missing"
out="$(run_hook surface-faults.sh "$(session_json "${RF3}" rf3)")"
oq_grep "surface: unreported fault raises a notice" 'self-fault' "${out}"
oq_grep "surface: notice points at /steer:report" 'steer:report' "${out}"
assert_eq "surface: marker records count surfaced" \
	"$(cat "${RF3}/.claude/steer-faults.surfaced")" "1"

# Second run with no new fault -> silent (surfaced once, never a per-session nag).
out="$(run_hook surface-faults.sh "$(session_json "${RF3}" rf3)")"
assert_empty "surface: already-surfaced fault stays silent" "${out}"

# A newly-recorded fault after surfacing -> only the new one is raised.
steer_record_fault "${RF3}" "surface-faults.sh" "brand new symptom"
out="$(run_hook surface-faults.sh "$(session_json "${RF3}" rf3)")"
oq_grep "surface: new fault raised after prior surface" 'brand new symptom' "${out}"
printf '%s' "${out}" | grep -q 'rules directory missing' &&
	bad "surface: must not re-raise already-surfaced fault (got: ${out})" || ok

# Inside the plugin's own tree (.claude-plugin present) -> never nag.
RF4="$(new_repo rf4)"
mkdir -p "${RF4}/.claude-plugin"
steer_record_fault "${RF4}" "inject-standards.sh" "rules directory missing"
out="$(run_hook surface-faults.sh "$(session_json "${RF4}" rf4)")"
assert_empty "surface: silent inside the plugin's own repo" "${out}"

finish
