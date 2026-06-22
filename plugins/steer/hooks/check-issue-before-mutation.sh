#!/usr/bin/env sh
# steer PreToolUse hook — issue-first nudge (point-of-action).
#
# WHY THIS EXISTS
#   rule 36-issue-first says: in a GitHub-adopted repo, every code/config/infra/
#   behavior change has a GitHub issue before the first repository mutation. The
#   rule is always-on prose, but prose is easy to skip mid-session. This hook
#   re-asserts it at the moment it's about to be broken: the first write of real
#   source or operations file in a repo whose /spec/tracker.md declares
#   `system: github`. It is the lightweight safety net; primary enforcement is
#   routing (/steer:work) + the skills, which actually find-or-create
#   the issue. The hook cannot know whether an issue exists — it only reminds.
#
# MECHANISM
#   Non-blocking. Emits hookSpecificOutput.additionalContext and exits 0 — the
#   write proceeds. Fires AT MOST ONCE per session+repo (marker in TMPDIR keyed
#   by session_id + cwd). Silent unless tracker.md says GitHub; complements
#   check-code-before-spec.sh (which fires when /spec is *missing* — tracker.md
#   lives under /spec, so the two never fire on the same write). The shared
#   classifier (lib/classify.sh) decides which writes warrant the nudge.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. Fail-open everywhere: any ambiguity → exit 0, never
#   block. Honest limitation: a best-effort nudge, not a gate.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

FILE="$(steer_target_path)"
SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Resolve the work-tree root (cwd may be a subdir). Not a git work tree, or the
# plugin's own source repo → not our concern.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Scoped to GitHub-adopted repos: need /spec/tracker.md declaring system: github.
TRACKER="${ROOT}/spec/tracker.md"
[ -f "${TRACKER}" ] || exit 0
grep -iq '^[[:space:]]*system:[[:space:]]*github' "${TRACKER}" 2>/dev/null || exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Shared classification → shared exempt/nudge policy. spec/docs/generated/lockfile
# are exempt; implementation/operations/unknown nudge.
CLASS="$(steer_classify_path "${FILE}")"
[ "$(steer_class_nudges "${CLASS}")" = "nudge" ] || exit 0

# Plugin-maintenance flow exemption (rule 36 carve-out): /steer:sync runs on its
# own feat/sync branch and writes operations-class scaffold (CI, mise.toml,
# compose.yaml, …) — structural reconciliation against plugin templates, not
# feature implementation. Stay silent there UNLESS the write is app source
# (implementation-class), which sync's contract forbids and is worth surfacing.
if [ "${CLASS}" != "implementation" ] && command -v git >/dev/null 2>&1; then
	BRANCH="$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
	case "${BRANCH}" in feat/sync|feat/sync-*|feat/sync/*) exit 0 ;; esac
fi

# Fire at most once per session+repo (keyed by resolved root so subdir writes
# dedupe to one nudge).
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-issuefirst-nudge.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\')"

# Issue-first holds in BOTH delivery modes (the issue is the audit-evidence anchor);
# solo-trunk relaxes only the branch/PR ceremony, so its nudge keeps the issue
# requirement but drops the /steer:work branch/PR guidance.
MODE="$(steer_delivery_mode "${ROOT}")"
if [ "${MODE}" = "solo-trunk" ]; then
	CTX="Issue-first check (solo-trunk mode): this repo's /spec/tracker.md uses GitHub Issues, and you are about to write ${CLASS} (${SAFE_FILE}). Solo-trunk relaxes the per-feature branch and PR, but issue-first still holds: every implementation-affecting mutation (code/config/infra/behavior — not spec, docs, or lockfiles) needs a GitHub issue. Reuse the issue the user named, or find-or-create one via /steer:tracker-sync (an explicit fix/implement/add request needs no confirmation to create it; see the Authorization & confirmation block in ISSUE-WORKFLOW.md). Stay on main and CLOSE the issue from your trunk commit (a 'Closes #N' trailer, or '(#N)' in the subject) — do NOT create an issue/<N> branch or open a PR. This nudge does not block the write and fires once per session."
else
	CTX="Issue-first check: this repo's /spec/tracker.md uses GitHub Issues, and you are about to write ${CLASS} (${SAFE_FILE}). Every implementation-affecting mutation (code/config/infra/behavior — not spec, docs, or lockfiles) needs a GitHub issue BEFORE the first mutation — reuse the issue the user named, or find-or-create one via /steer:tracker-sync (an explicit fix/implement/add request needs no confirmation to create it; see the Authorization & confirmation block in ISSUE-WORKFLOW.md), then run implementation through /steer:work. This nudge does not block the write and fires once per session."
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
