#!/usr/bin/env sh
# steer Stop hook — issue-first working-tree reconciliation (end-of-turn).
#
# WHY THIS EXISTS
#   rule 36-issue-first wants every implementation-affecting mutation tied to a
#   GitHub issue in a GitHub-adopted repo. The PreToolUse nudge
#   (check-issue-before-mutation.sh) catches *editor* writes (Write/Edit/
#   MultiEdit) at the point of action — but it is deliberately blind to Bash:
#   a `cat > src/foo.ts`, `sed -i`, `mv`, or codegen run mutates the repo without
#   ever passing a file_path through PreToolUse, so those changes are invisible to
#   the point-of-action nudge. This hook reconciles the *actual working tree* once
#   the turn ends: if implementation-affecting changes landed on a branch that
#   does not reference a GitHub issue, it surfaces them so the work can be tied to
#   an issue rather than slipping in untracked.
#
# MECHANISM
#   Reports, does not enforce — the mutation already happened; this is post-hoc
#   safety feedback, not a gate (non-goal: a hard block on local edits). A Stop
#   hook's only channel for surfacing text is {"decision":"block","reason":...},
#   which hands `reason` to the model and lets it CONTINUE — it does not stop the
#   user or revert anything. So "block" here is the delivery mechanism, not a gate.
#   Surfaces the concrete governed paths exactly ONCE per session+repo, then
#   self-disarms. Two independent loop guards:
#     1. stop_hook_active=true (the continuation triggered by our own block) → exit.
#     2. a per-session+repo marker in TMPDIR → exit on any later Stop.
#   Silent unless /spec/tracker.md says system: github, silent on an issue-
#   referenced branch, and silent when only exempt paths (spec/docs/generated/
#   lockfile) changed. Shares lib/classify.sh with the PreToolUse nudge so both
#   agree on what counts as implementation-affecting.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. Fail-open everywhere: any ambiguity → exit 0, never
#   block. Honest limitation: a best-effort end-of-turn reconciliation, not a gate.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

# Loop guard 1: never re-enter while Claude is already continuing from our block.
printf '%s' "${STEER_INPUT}" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Resolve the work-tree root (cwd may be a subdir). Not a git work tree, or the
# plugin's own source repo → not our concern.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Scoped to GitHub-adopted repos: need /spec/tracker.md declaring system: github.
steer_tracker_is_github "${ROOT}" || exit 0

# Need git to inspect the working tree; fail open if unavailable.
command -v git >/dev/null 2>&1 || exit 0

BRANCH="$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null)"

# Delivery mode governs how this turn is reconciled. In solo-trunk, main is the
# expected working branch and there is no issue/<n> branch or spec/.work marker
# (those are PR-flow / /steer:work constructs), so the branch-name inference below
# would wrongly fire every session — skip it and reword the advisory instead.
MODE="$(steer_delivery_mode "${ROOT}")"

# Record the current Claude Code session at the head of an existing .md work
# marker's session list (newest first), so /steer:work resume can offer to
# re-enter that conversation. Fail-open and idempotent: no session id, an
# unwritable marker, missing awk, a malformed marker, or the session already at
# the head → leave the file byte-for-byte untouched. POSIX awk, atomic temp+mv,
# and the issue:/branch: header lines (above the sessions heading) are never
# rewritten. The session list is local-only breadcrumbs; it never leaves the
# git-ignored marker.
_steer_stamp_session() {
	_mf="$1"
	_sid="$2"
	[ -n "${_sid}" ] || return 0
	[ -f "${_mf}" ] && [ -w "${_mf}" ] || return 0
	# Defensive: the id becomes file content — reject anything but uuid charset.
	printf '%s' "${_sid}" | grep -qE '^[A-Za-z0-9_-]+$' || return 0
	command -v awk >/dev/null 2>&1 || return 0
	_tmp="${_mf}.stamp.$$"
	# Lines before the "## Claude Code sessions" heading print verbatim (header).
	# Lines after are session bullets we rebuild: current id first, then the prior
	# ids (deduped, original order), capped. No heading → no append (untouched).
	awk -v sid="${_sid}" -v cap=5 '
		BEGIN { seen = 0; n = 0 }
		!seen {
			print
			if ($0 ~ /^## Claude Code sessions/) { seen = 1 }
			next
		}
		{
			if ($0 ~ /^[[:space:]]*$/) next
			if ($0 ~ /^-[[:space:]]+/) {
				id = $0
				sub(/^-[[:space:]]+/, "", id)
				sub(/[[:space:]].*$/, "", id)
				if (id != "" && id != sid && !(id in have)) { have[id] = 1; ord[++n] = id }
			}
			next
		}
		END {
			if (seen) {
				print ""
				print "- " sid
				c = 1
				for (i = 1; i <= n && c < cap; i++) { print "- " ord[i]; c++ }
			}
		}
	' "${_mf}" >"${_tmp}" 2>/dev/null || {
		rm -f "${_tmp}" 2>/dev/null
		return 0
	}
	# No-op when nothing changed (session already at the head) — avoid churn.
	if cmp -s "${_tmp}" "${_mf}" 2>/dev/null; then
		rm -f "${_tmp}" 2>/dev/null
	else
		mv "${_tmp}" "${_mf}" 2>/dev/null || rm -f "${_tmp}" 2>/dev/null
	fi
	return 0
}

# Branch-based governance (marker + issue-branch conventions) is a PR-flow concept.
# Solo-trunk has no feature branch or spec/.work marker, so skip this whole block
# there — the advisory below is reworded for trunk instead.
if [ "${MODE}" != "solo-trunk" ]; then
	# Prefer an explicit work marker over branch-name inference. /steer:work records
	# the claimed issue for a branch under spec/.work/<branch>.md (slashes →
	# underscores); a legacy extensionless marker (repos that predate the .md format)
	# is still honoured. If this branch has a marker the work is governed → stamp the
	# session into the .md marker and stay silent.
	_bkey="$(printf '%s' "${BRANCH}" | tr '/' '_')"
	if [ -n "${BRANCH}" ]; then
		_mdmark="${ROOT}/spec/.work/${_bkey}.md"
		if [ -f "${_mdmark}" ]; then
			_steer_stamp_session "${_mdmark}" "${SID}"
			exit 0
		fi
		[ -f "${ROOT}/spec/.work/${_bkey}" ] && exit 0
	fi

	# Fallback when no marker exists (older repos / out-of-band branches): recognize
	# only the issue-branch conventions — issue/<n>-slug, a leading issue number,
	# or a Jira-style KEY-123. A date branch like release/2026-06 must NOT count as
	# issue-governed; main/master/develop and topic branches get reconciled.
	printf '%s' "${BRANCH}" | grep -qE '^issue/[0-9]+([/_-]|$)' && exit 0
	printf '%s' "${BRANCH}" | grep -qE '^[0-9]+[/_-]' && exit 0
	printf '%s' "${BRANCH}" | grep -qE '(^|/)[A-Z][A-Z0-9]+-[0-9]+([/_-]|$)' && exit 0
fi

# Changed paths (staged + unstaged + untracked), NUL-delimited from git so odd
# filenames and renames are handled safely. --name-only avoids the porcelain
# status prefix and the rename "old -> new" arrow; ls-files adds untracked. The
# NUL stream is converted to newlines only for the POSIX for-loop below.
CHANGED="$(
	{
		git -C "${ROOT}" diff --name-only -z HEAD 2>/dev/null
		git -C "${ROOT}" ls-files --others --exclude-standard -z 2>/dev/null
	} | tr '\0' '\n'
)"
[ -n "${CHANGED}" ] || exit 0

# Any implementation-affecting (nudge-class) path among the changes? Exempt-only
# turns (spec/docs/generated/lockfile) produce no governed list → stay silent.
GOVERNED=""
_oifs="${IFS}"
IFS='
'
for _path in ${CHANGED}; do
	[ -n "${_path}" ] || continue
	_cls="$(steer_classify_path "${_path}")"
	if [ "$(steer_class_nudges "${_cls}")" = "nudge" ]; then
		GOVERNED="${GOVERNED}${_path} (${_cls}); "
	fi
done
IFS="${_oifs}"

[ -n "${GOVERNED}" ] || exit 0

# Plugin-maintenance flow exemption (rule 36 carve-out). /steer:sync runs on its
# own feat/sync branch and reconciles the materialized spine + scaffold against
# the plugin's own templates — operations-class config/infra, but structural, not
# feature implementation (same rationale as the spec-spine exemption). Stay silent
# UNLESS app source (implementation-class) also changed: sync's contract forbids
# touching app code, so that is a real anomaly worth surfacing rather than exempting.
case "${BRANCH}" in
	feat/sync|feat/sync-*|feat/sync/*)
		printf '%s' "${GOVERNED}" | grep -q '(implementation)' || exit 0 ;;
esac

# Loop guard 2 / fire-once: at most one advisory per session+repo (keyed by root).
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-issuefirst-stop.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

# Single-line, JSON-safe reason (strip quotes/backslashes from dynamic parts, as
# check-issue-before-mutation.sh does). Cap the path list so the message stays short.
SAFE_BRANCH="$(printf '%s' "${BRANCH}" | tr -d '"\\')"
SAFE_LIST="$(printf '%s' "${GOVERNED}" | tr -d '"\\' | cut -c1-400)"

case "${BRANCH}" in
hotfix/*)
	# Hotfix fast-path (rule 62): a production hotfix files its issue after-the-fact
	# by design, so the standard "branch does not reference an issue" nag is a false
	# positive here. Reframe as the mandatory post-incident follow-up reminder instead.
	REASON="Issue-first reconciliation (hotfix lane, rule 62): this turn made implementation-affecting changes on hotfix branch '${SAFE_BRANCH}': ${SAFE_LIST}A production hotfix may file its issue after-the-fact, so this is not a skipped step. Once the incident is resolved, complete the MANDATORY follow-up to restore traceability: backfill or finish the GitHub issue and reference it from the PR/commit, write the spec/ADR if a durable decision was made, and append a /spec/HISTORY.md entry. Definition of Done is deferred under the hotfix lane, not waived (rule 50). One-time advisory for this session — it will not repeat."
	;;
*)
	if [ "${MODE}" = "solo-trunk" ]; then
		REASON="Issue-first reconciliation (solo-trunk mode): this GitHub-adopted repo ended the turn with implementation-affecting changes in the working tree: ${SAFE_LIST}Solo-trunk commits straight to main, but issue-first (rule 36) still ties every implementation-affecting mutation to a GitHub issue. Before committing, make sure this work carries an issue reference in the trunk commit — close the issue from the commit (a 'Closes #N' trailer, or '(#N)' in the subject). If you have no issue yet, capture or reuse one via /steer:tracker-sync. If an autonomous 'gh issue create' was blocked by host permissions this turn, that is a host gate, not a skipped step — ask the user to confirm the create or have them run '!gh issue create'. Do NOT create an issue/<N> branch or a PR — that ceremony is relaxed pre-MVP. If this work is throwaway, you can disregard this. One-time advisory for this session — it will not repeat."
	else
		REASON="Issue-first reconciliation: this GitHub-adopted repo ended the turn with implementation-affecting changes in the working tree on branch '${SAFE_BRANCH}', which does not reference a GitHub issue: ${SAFE_LIST}Issue-first (rule 36) ties every implementation-affecting mutation to a GitHub issue. If this work is intended, capture or reuse an issue and route it through /steer:work (branch like issue/<n>-slug, which records a spec/.work marker). If an autonomous 'gh issue create' was blocked by host permissions this turn, that is a host gate, not a skipped step — ask the user to confirm the create or have them run '!gh issue create'. If it is throwaway, you can disregard this. One-time advisory for this session — it will not repeat."
	fi
	;;
esac

# Stop hooks have exactly one channel for surfacing text to the model:
# {"decision":"block","reason":...}, which hands `reason` back and lets Claude
# CONTINUE (it does not stop the user or revert the edits — the mutation already
# happened). This is that advisory, not a gate. Fires once per session+repo.
printf '{"decision":"block","reason":"%s"}\n' "${REASON}"
exit 0
