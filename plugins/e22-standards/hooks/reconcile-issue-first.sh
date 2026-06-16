#!/usr/bin/env sh
# e22-standards Stop hook — issue-first working-tree reconciliation (end-of-turn).
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

E22_INPUT="$(cat)"
[ -z "${E22_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

# Loop guard 1: never re-enter while Claude is already continuing from our block.
printf '%s' "${E22_INPUT}" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

SID="$(e22_field session_id)"
CWD="$(e22_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Resolve the work-tree root (cwd may be a subdir). Not a git work tree, or the
# plugin's own source repo → not our concern.
ROOT="$(e22_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Scoped to GitHub-adopted repos: need /spec/tracker.md declaring system: github.
TRACKER="${ROOT}/spec/tracker.md"
[ -f "${TRACKER}" ] || exit 0
grep -iq '^[[:space:]]*system:[[:space:]]*github' "${TRACKER}" 2>/dev/null || exit 0

# Need git to inspect the working tree; fail open if unavailable.
command -v git >/dev/null 2>&1 || exit 0

BRANCH="$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null)"

# Prefer an explicit work marker over branch-name inference. /e22-standards:e22-work
# records the issue it claimed for a branch under spec/.work/<branch> (slashes →
# underscores). If this branch has a marker, the work is governed → stay silent.
_bkey="$(printf '%s' "${BRANCH}" | tr '/' '_')"
[ -n "${BRANCH}" ] && [ -f "${ROOT}/spec/.work/${_bkey}" ] && exit 0

# Fallback when no marker exists (older repos / out-of-band branches): recognize
# only the E22 issue-branch conventions — issue/<n>-slug, a leading issue number,
# or a Jira-style KEY-123. A date branch like release/2026-06 must NOT count as
# issue-governed; main/master/develop and topic branches get reconciled.
printf '%s' "${BRANCH}" | grep -qE '^issue/[0-9]+([/_-]|$)' && exit 0
printf '%s' "${BRANCH}" | grep -qE '^[0-9]+[/_-]' && exit 0
printf '%s' "${BRANCH}" | grep -qE '(^|/)[A-Z][A-Z0-9]+-[0-9]+([/_-]|$)' && exit 0

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
	_cls="$(e22_classify_path "${_path}")"
	if [ "$(e22_class_nudges "${_cls}")" = "nudge" ]; then
		GOVERNED="${GOVERNED}${_path} (${_cls}); "
	fi
done
IFS="${_oifs}"

[ -n "${GOVERNED}" ] || exit 0

# Loop guard 2 / fire-once: at most one advisory per session+repo (keyed by root).
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/e22-issuefirst-stop.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

# Single-line, JSON-safe reason (strip quotes/backslashes from dynamic parts, as
# check-issue-before-mutation.sh does). Cap the path list so the message stays short.
SAFE_BRANCH="$(printf '%s' "${BRANCH}" | tr -d '"\\')"
SAFE_LIST="$(printf '%s' "${GOVERNED}" | tr -d '"\\' | cut -c1-400)"

REASON="Element 22 issue-first reconciliation: this GitHub-adopted repo ended the turn with implementation-affecting changes in the working tree on branch '${SAFE_BRANCH}', which does not reference a GitHub issue: ${SAFE_LIST}Issue-first (rule 36) ties every implementation-affecting mutation to a GitHub issue. If this work is intended, capture or reuse an issue and route it through /e22-standards:e22-work (branch like issue/<n>-slug, which records a spec/.work marker); if it is throwaway, you can disregard this. One-time advisory for this session — it will not repeat."

# Stop hooks have exactly one channel for surfacing text to the model:
# {"decision":"block","reason":...}, which hands `reason` back and lets Claude
# CONTINUE (it does not stop the user or revert the edits — the mutation already
# happened). This is that advisory, not a gate. Fires once per session+repo.
printf '{"decision":"block","reason":"%s"}\n' "${REASON}"
exit 0
