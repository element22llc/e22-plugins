#!/usr/bin/env sh
# steer PreToolUse hook — issue-creation contract guard (point-of-action).
#
# WHY THIS EXISTS
#   rule 35-issue-tracker + the issue-workflow contract require every
#   agent-authored GitHub issue to go through /steer:tracker-sync, which renders
#   the machine-readable contract: steer markers (steer:kind / steer:source /
#   managed block), the derived source:* label, the GitHub Issue Type, and native
#   relationship edges — with find-before-create dedup. A raw `gh issue create`,
#   a `gh api … POST …/issues`, a `gh api graphql` `createIssue` mutation, or an
#   MCP create-issue tool bypasses all of that: the issue lands with no markers,
#   no source:* label, the default Type, and no dependency edges — invisible to
#   marker-based dedup, triage, board, and reconcile. The issue-first nudge
#   (check-issue-before-mutation.sh) is deliberately blind to Bash and never fires
#   on issue creation, so nothing reasserts the contract at the point an agent is
#   about to open a contract-less issue. This hook is that point-of-action
#   reminder; /steer:issues reconcile is the after-the-fact recovery path.
#
# MECHANISM
#   Non-blocking. Emits hookSpecificOutput.additionalContext and exits 0 — the
#   create proceeds. Fires AT MOST ONCE per session+repo (marker in TMPDIR keyed
#   by session_id + repo root). Bails fast on any non-issue-create call (it is
#   matched on every Bash call). Silent unless /spec/tracker.md says
#   `system: github`. Stays silent when the payload already carries `steer:`
#   markers — that is the contract being applied (the /steer:tracker-sync path),
#   not a bypass.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. Fail-open everywhere: any ambiguity → exit 0, never
#   block. Honest limitation: a best-effort nudge, not a gate — it cannot tell a
#   --body-file create from an inline one, so it errs toward one harmless reminder
#   and words itself so a correct /steer:tracker-sync run can disregard it.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

TOOL="$(steer_field tool_name)"
CMD="$(steer_field command)"

# --- Is this an issue-CREATE action? Cheap checks first; this hook is matched on
# every Bash call, so bail immediately on anything that is not issue creation. ---
PAYLOAD=""
is_create=0

case "${TOOL}" in
mcp__*)
	# An MCP create-issue tool — match by tool name (create…issue / issue…create),
	# excluding comment/label/sub-tools that merely contain "issue". The contract
	# check below uses the issue body the tool was handed.
	_tn="$(printf '%s' "${TOOL}" | tr '[:upper:]' '[:lower:]')"
	case "${_tn}" in
	*create*issue* | *issue*create* | *add*issue) is_create=1 ;;
	esac
	case "${_tn}" in *comment*) is_create=0 ;; esac
	[ "${is_create}" -eq 1 ] && PAYLOAD="$(steer_field body)"
	;;
*)
	# Bash (or any command-bearing tool): inspect the command text.
	[ -n "${CMD}" ] || exit 0
	PAYLOAD="${CMD}"
	# 1) `gh issue create`
	if printf '%s' "${CMD}" | grep -Eq 'gh[[:space:]]+issue[[:space:]]+create'; then
		is_create=1
	# 2) `gh api graphql … createIssue` mutation
	elif printf '%s' "${CMD}" | grep -q 'gh api' &&
		printf '%s' "${CMD}" | grep -q 'createIssue'; then
		is_create=1
	# 3) `gh api … POST …/issues` (REST). The path must END at /issues (a trailing
	#    /issues/<n>/… is a comment/label/sub-resource, not issue creation), and a
	#    POST indicator must be present (gh api defaults to GET; -f/-F/--field/
	#    --raw-field imply POST, as does an explicit -X/--method POST).
	elif printf '%s' "${CMD}" | grep -q 'gh api' &&
		printf '%s' "${CMD}" | grep -Eq "/issues([[:space:]\"']|\$)" &&
		printf '%s' "${CMD}" | grep -Eq '(-X[[:space:]]+POST|--method[[:space:]]+POST|[[:space:]]-f[[:space:]]|[[:space:]]-F[[:space:]]|--field|--raw-field)'; then
		is_create=1
	fi
	;;
esac

[ "${is_create}" -eq 1 ] || exit 0

# --- Contract already being applied? A payload carrying steer: markers is the
# /steer:tracker-sync render path, not a bypass — stay silent. (A --body-file
# create hides the markers from us; the defensive wording below covers that.) ---
printf '%s' "${PAYLOAD}" | grep -q 'steer:' && exit 0

# --- Scope: GitHub-adopted consumer repo, never the plugin's own source repo. ---
SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0
steer_tracker_is_github "${ROOT}" || exit 0

# --- Fire at most once per session+repo (keyed by resolved root). ---
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-issuecreate-guard.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

CTX="Issue-create contract check: this repo's /spec/tracker.md uses GitHub Issues, and you are about to open an issue with a raw create (gh issue create / gh api / an MCP create-issue tool). Route issue creation through /steer:tracker-sync create instead, so the machine-readable contract is applied — steer markers (steer:kind / steer:source / managed block), the derived source:* label, the GitHub Issue Type, and native relationship edges — with find-before-create dedup. A contract-less issue is invisible to marker-based dedup, triage, board, and /steer:issues reconcile. If you are already running /steer:tracker-sync create (its rendered body carries those markers), disregard this. This nudge does not block the create and fires once per session."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
