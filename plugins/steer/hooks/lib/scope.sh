# shellcheck shell=sh
# steer hook helper — rule-injection scope predicates.
#
# inject-standards.sh injects the always-on ruleset every session. A rule may
# carry a first-line marker `<!-- steer:inject-when=<token> -->` declaring that
# it is only relevant in a specific repo context; this helper evaluates those
# tokens against the consumer repo so the hook can skip an inapplicable rule
# (e.g. issue-first on a non-GitHub repo) and reclaim that context budget.
#
# Fail-open is the rule here: an always-on safety ruleset must never silently
# DROP a rule on an unreadable signal or an unrecognized token. Every predicate
# degrades to "inject" (return 0) when it cannot prove the rule is out of scope.

# steer_tracker_is_github <repo-root> — true when the repo's /spec/tracker.md
# declares `system: github`. Single source of truth for GitHub-tracker
# detection, shared with the issue-first hooks (check-issue-before-mutation.sh,
# reconcile-issue-first.sh) and the inject-when scope dispatch below.
steer_tracker_is_github() {
	_tracker="${1:-.}/spec/tracker.md"
	[ -f "${_tracker}" ] || return 1
	grep -iq '^[[:space:]]*system:[[:space:]]*github' "${_tracker}" 2>/dev/null
}

# steer_inject_when_ok <token> <repo-root> — true (inject the rule) / false (skip
# it) for a rule's inject-when marker token. Empty root or an unknown token →
# fail-open (inject), so a missing cwd or a typo'd marker never silently removes
# a rule from the always-on context.
steer_inject_when_ok() {
	_token="$1"
	_root="${2:-}"
	[ -n "${_root}" ] || return 0
	case "${_token}" in
	tracker-github) steer_tracker_is_github "${_root}" ;;
	has-infra) [ -d "${_root}/infra" ] ;;
	*) return 0 ;;
	esac
}
