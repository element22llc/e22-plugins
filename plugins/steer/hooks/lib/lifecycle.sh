# shellcheck shell=sh
# steer hook helper — the shared lifecycle-ordering contract.
#
# Open questions carry a `required_before:` gate (intent-approval, …,
# production-release). To say whether a blocking question blocks *now* versus a
# *later* transition, hooks need the canonical ORDER of those gates and a mapping
# from a feature's Status to the gate it has most recently cleared. The order is
# NOT hard-coded here — it is read from the canonical registry so it stays in
# lock-step with check_standards.py and the templates.
#
# Single source of truth: templates/reference/enums.registry → `required_before`.

# steer_required_before_order — space-separated gate tokens in lifecycle order,
# read from the registry. Empty if the registry is unreadable (callers degrade
# to "treat every blocking question as blocking-now", the conservative default).
steer_required_before_order() {
	_reg="${CLAUDE_PLUGIN_ROOT}/templates/reference/enums.registry"
	[ -f "${_reg}" ] || return 0
	# `required_before=a|b|c` → `a b c`
	grep '^required_before=' "${_reg}" 2>/dev/null | head -n 1 | cut -d= -f2 | tr '|' ' '
}

# steer_status_cleared_gate <feature-status> — the required_before gate a feature in
# the given Status has already cleared (empty = none cleared yet). A blocking
# question whose gate is at or before this is overdue; the gate one step past it
# is "blocking now"; anything further is a later transition.
#
#   draft       → (none)              not yet intent-approved
#   approved    → intent-approval     intent approved, contract/impl ahead
#   implemented → implementation      built, validation/release ahead
#   validated   → non-prod-validation demo-validated, release ahead
#   live        → production-release  in production
steer_status_cleared_gate() {
	case "$1" in
	approved) printf 'intent-approval' ;;
	implemented) printf 'implementation' ;;
	validated) printf 'non-prod-validation' ;;
	live) printf 'production-release' ;;
	*) : ;; # draft / unknown / absent → none cleared
	esac
}

# STEER_AWK_DAYS_FROM_CIVIL — awk source for a Gregorian-date → day-number
# function (days since 1970-01-01, UTC; the days-from-civil algorithm), so
# POSIX date math never depends on GNU `date -d`. Interpolate it ahead of an
# awk program body: awk "${STEER_AWK_DAYS_FROM_CIVIL}"'{ … }'. Shared by
# check-open-questions.sh's today-number and staleness passes.
# shellcheck disable=SC2034  # consumed by sourcing hooks, not this file
STEER_AWK_DAYS_FROM_CIVIL='
  function days_from_civil(y, m, d,   era, yoe, doy, doe) {
    if (m <= 2) y--
    era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
    doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
    doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
    return era * 146097 + doe - 719468
  }'
