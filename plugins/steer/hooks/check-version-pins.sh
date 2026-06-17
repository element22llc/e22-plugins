#!/usr/bin/env sh
# steer PreToolUse hook — version-pin policy (deterministic, advisory).
#
# Inspects the *new* content a Write/Edit/MultiEdit/NotebookEdit introduces for
# pinned major versions of common backing-service / runtime images and applies
# the org policy in policy/versions.yml:
#
#   below minimum_supported / denied  -> DENY  (deterministic, from policy)
#   supported but below recommended   -> WARN  (advisory additionalContext)
#   at/above recommended / unknown    -> ALLOW (silent)
#
# WHY DETERMINISTIC (this is a redesign):
#   The previous version queried endoflife.date on the write path. That made the
#   "hard deny" fail OPEN without jq, and put a network call on the hot path. The
#   gate now reads a static, version-controlled policy file — no network, no jq —
#   so it is reproducible and never fails open for lack of a tool. Upstream EOL is
#   tracked by the scheduled refresh workflow that PROPOSES policy bumps; it is
#   never consulted here. The CI scanner (scripts/scan-version-pins.sh) is the
#   committed-state backstop and enforces the SAME policy file.
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
# Resolve policy from the repo-local file (when cwd is the repo root) else the
# plugin-bundled default. (Subdir-aware root resolution is a separate concern; the
# bundled fallback keeps enforcement working regardless.)
POLICY="$(steer_policy_resolve "${CWD}")"
[ -n "${POLICY}" ] || exit 0 # no policy available → cannot enforce, stay silent

DENY=""
WARN=""
for PIN in ${PINS}; do
	PRODUCT="${PIN%%:*}"
	VERSION="${PIN#*:}"

	# Same-line justification marker -> deliberate pin, allow. The boundary
	# class excludes only digits (not the dot) so a three-segment pin (matched
	# here at its major.minor) still honors the marker, while a non-digit or
	# end-of-line after the pin still blocks a partial-major match (a "1" pin
	# must not match a "189" version).
	printf '%s' "${CONTENT}" | grep -E "${PIN}([^0-9]|\$).*(steer:allow-pin|pin-ok)" >/dev/null 2>&1 && continue

	VERDICT="$(steer_policy_verdict "${POLICY}" "${PRODUCT}" "${VERSION}")"
	case "${VERDICT}" in
	deny\ *) DENY="${DENY}${VERDICT#deny }; " ;;
	advise\ *) WARN="${WARN}${VERDICT#advise }; " ;;
	*) : ;; # ok / unknown → silent
	esac
done

# Deny dominates: any below-floor / denied pin is a hard deny.
if [ -n "${DENY}" ]; then
	REASON="Version-pin policy violation — ${DENY}source: policy/versions.yml (version policy). Bump to a supported version. Org standard (/steer:conventions): default to current stable, do not trust training-data memory. If the older pin is deliberate (deploy-target parity, vendor LTS), record an ADR and append ' # steer:allow-pin <reason>' on the same line, then retry."
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "${REASON}"
	exit 0
fi

# Advisory only — allow the write, surface a reminder.
if [ -n "${WARN}" ]; then
	CTX="Version-pin advisory — ${WARN}source: policy/versions.yml. Supported, but behind the target; consider bumping (or record an ADR + ' # steer:allow-pin <reason>' if the pin is deliberate). Not blocking."
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
	exit 0
fi

exit 0
