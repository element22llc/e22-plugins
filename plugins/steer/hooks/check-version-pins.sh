#!/usr/bin/env sh
# steer PreToolUse hook — version-pin policy (deterministic EOL floor).
#
# Inspects the *new* content a Write/Edit/MultiEdit/NotebookEdit introduces for
# pinned major versions of common backing-service / runtime images and applies
# the org policy in policy/versions.yml:
#
#   below minimum_supported / denied  -> DENY  (deterministic, from policy)
#   at/above the floor / unknown      -> ALLOW (silent)
#
# This is a FLOOR, not a version chooser — it blocks dead majors. WHAT to pin
# (current stable) is decided live, in-session, per the versioning rule
# (/steer:reference conventions); there is deliberately no advisory "behind the target" tier.
#
# WHY DETERMINISTIC (this is a redesign):
#   The previous version queried endoflife.date on the write path. That made the
#   "hard deny" fail OPEN without jq, and put a network call on the hot path. The
#   gate now reads a static, version-controlled policy file — no network, no jq —
#   so it is reproducible and never fails open for lack of a tool. Upstream EOL is
#   tracked by the scheduled refresh workflow that PROPOSES policy bumps (opens a
#   PR raising the floors); it is never consulted here. The CI scanner
#   (scripts/scan-version-pins.sh) is the committed-state backstop and enforces
#   the SAME policy file.
#
# F13 — tool-aware: only introduced content is inspected (Write->content,
# Edit->new_string, MultiEdit->new_strings). old_string is NEVER inspected, so an
# upgrade edit is not falsely blocked. Bash command text is skipped (documented
# bypass); the CI scanner covers committed Bash-mediated writes.
#
# Bypass a deliberate old/denied pin: append `# steer:allow-pin <reason>` (legacy:
# `# pin-ok: <reason>`) on the same line and record an ADR (versioning policy).
#
# POSIX sh; no jq, no network. Fail-open on any ambiguity — never break a session.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/version-policy.sh"

# Docs legitimately mention old versions -> exempt.
FILE="$(steer_field file_path)"
[ -n "${FILE}" ] && [ "$(steer_classify_path "${FILE}")" = "documentation" ] && exit 0

# F13: inspect only the introduced content (empty for Bash / unknown tools).
CONTENT="$(steer_mutation_content)"
[ -z "${CONTENT}" ] && exit 0

PINS="$(printf '%s' "${CONTENT}" | grep -Eo '(postgres|node|python|redis|valkey|nginx|mysql|mariadb|mongo):[0-9]+(\.[0-9]+)?' | sort -u)"
[ -z "${PINS}" ] && exit 0

CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
# Resolve the work-tree root so a repo-local policy/versions.yml is honored even
# when editing from a subdir (e.g. apps/web); fall back to CWD when not inside a
# work tree. steer_policy_resolve then prefers that repo-local file, else the
# plugin-bundled default — so enforcement works regardless.
ROOT="$(steer_repo_root "${CWD}")" || ROOT="${CWD}"
POLICY="$(steer_policy_resolve "${ROOT}")"
[ -n "${POLICY}" ] || exit 0 # no policy available → cannot enforce, stay silent

DENY=""
for PIN in ${PINS}; do
	PRODUCT="${PIN%%:*}"
	VERSION="${PIN#*:}"

	# Same-line justification marker -> deliberate pin, allow. The boundary
	# class excludes only digits (not the dot) so a three-segment pin (matched
	# here at its major.minor) still honors the marker, while a non-digit or
	# end-of-line after the pin still blocks a partial-major match (a "1" pin
	# must not match a "189" version). Escape the pin's dots so a dotted pin (e.g. a
	# 3.9 tag) is matched literally, not as an ERE `.` that matches any char.
	PIN_RE="$(printf '%s' "${PIN}" | sed 's/[.]/\\./g')"
	printf '%s' "${CONTENT}" | grep -E "${PIN_RE}([^0-9]|\$).*(steer:allow-pin|pin-ok)" >/dev/null 2>&1 && continue

	VERDICT="$(steer_policy_verdict "${POLICY}" "${PRODUCT}" "${VERSION}")"
	case "${VERDICT}" in
	deny\ *) DENY="${DENY}${VERDICT#deny }; " ;;
	*) : ;; # ok / unknown → silent
	esac
done

# Deny dominates: any below-floor / denied pin is a hard deny.
if [ -n "${DENY}" ]; then
	# Sanitize the only interpolated part before embedding it in the JSON reason,
	# mirroring the sibling point-of-action hooks (check-write-nudges.sh,
	# reconcile-issue-first.sh). The
	# verdict text is policy-derived + a numeric pin today, so this is hardening
	# against malformed JSON if that prose ever gains a quote, not a live bug.
	SAFE_DENY="$(steer_json_safe "${DENY}")"
	REASON="Version-pin policy violation — ${SAFE_DENY}source: policy/versions.yml (version policy). Bump to a supported version. Org standard (/steer:reference conventions): default to current stable, do not trust training-data memory. If the older pin is deliberate (deploy-target parity, vendor LTS), record an ADR and append ' # steer:allow-pin <reason>' on the same line, then retry."
	# Output envelope is harness-specific. Claude PreToolUse takes a hard "deny"
	# wrapped in hookSpecificOutput. GitHub Copilot CLI (registered under the
	# PascalCase `PreToolUse` event, which feeds the same tool_name/tool_input
	# shape this hook already parses) takes a flat decision object — and we emit
	# "ask" rather than "deny": Copilot's preToolUse is fail-closed and the
	# feature is Preview, so the gate surfaces for confirmation instead of
	# silently hard-blocking the edit. Default (unset) is the Claude path.
	if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
		printf '{"permissionDecision":"ask","permissionDecisionReason":"%s"}\n' "${REASON}"
	else
		printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "${REASON}"
	fi
	exit 0
fi

exit 0
