#!/usr/bin/env sh
# steer SessionStart hook — surface recorded steer SELF-faults.
#
# WHY THIS EXISTS
#   steer's other hooks record their own malfunctions (a missing rules dir, a
#   crashed helper) to a per-repo log via lib/report-fault.sh — they never phone
#   home themselves (no network/`gh`/time budget on the hot path). This hook is
#   the one place that reads that log at session start and raises any UNREPORTED
#   faults into session context, so the always-on self-report rule can offer
#   `/steer:report` and the user decides whether to file upstream.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path
#   as inject-standards.sh / orient-session.sh). A surfaced-count marker beside
#   the log tracks how many fault lines have already been raised, so each fault
#   is surfaced exactly once — never a per-session nag. `/steer:report` removes
#   both files once it has filed (or the user dismisses) the faults.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd comes from the SessionStart
#   payload (may be a subdir). Fail-soft: any ambiguity → stay silent.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/report-fault.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || exit 0

# Never nag inside the plugin's own source tree.
[ -d "${ROOT}/.claude-plugin" ] && exit 0

LOG="$(steer_faults_file "${ROOT}")"
[ -f "${LOG}" ] || exit 0

# How many fault lines exist vs. how many were already surfaced.
TOTAL="$(grep -c '' "${LOG}" 2>/dev/null)"
[ -n "${TOTAL}" ] || TOTAL=0
[ "${TOTAL}" -gt 0 ] 2>/dev/null || exit 0

MARK="$(steer_faults_surfaced_file "${ROOT}")"
SURFACED="$(cat "${MARK}" 2>/dev/null)"
case "${SURFACED}" in
'' | *[!0-9]*) SURFACED=0 ;;
esac

[ "${TOTAL}" -gt "${SURFACED}" ] 2>/dev/null || exit 0
NEW=$((TOTAL - SURFACED))

printf '<!-- steer: self-fault notice -->\n'
printf '⚠ **steer recorded %s self-fault(s)** during recent sessions — the plugin ' "${NEW}"
printf 'itself misbehaved, not your code. The unreported faults:\n\n'
# Show only the not-yet-surfaced tail; one bullet per fault (version · source · signature).
tail -n "${NEW}" "${LOG}" 2>/dev/null | while IFS='|' read -r _ver _src _sig; do
	printf -- '- `%s` in **%s** — %s\n' "${_ver}" "${_src}" "${_sig}"
done
printf '\nThis is a defect in the steer plugin. Run `/steer:report` to review a '
printf 'scrubbed bug report and (with your confirmation) file it upstream in '
printf 'element22llc/e22-plugins. Do not silently work around it.\n'

# Mark these faults surfaced so they are never raised again. Fail-soft.
printf '%s\n' "${TOTAL}" >"${MARK}" 2>/dev/null || true
