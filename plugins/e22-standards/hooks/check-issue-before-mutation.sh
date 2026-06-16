#!/usr/bin/env sh
# e22-standards PreToolUse hook — issue-first nudge (point-of-action).
#
# WHY THIS EXISTS
#   rule 36-issue-first says: in a GitHub-adopted repo, every code/config/infra/
#   behavior change has a GitHub issue before the first repository mutation. The
#   rule is always-on prose, but prose is easy to skip mid-session. This hook
#   re-asserts it at the moment it's about to be broken: the first write of real
#   source or operations file in a repo whose /spec/tracker.md declares
#   `system: github`. It is the lightweight safety net; primary enforcement is
#   routing (/e22-standards:e22-work) + the skills, which actually find-or-create
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

E22_INPUT="$(cat)"
[ -z "${E22_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"

FILE="$(e22_field file_path)"
SID="$(e22_field session_id)"
CWD="$(e22_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Not a git repo, or the plugin's own source repo → not our concern.
[ -e "${CWD}/.git" ] || exit 0
[ -d "${CWD}/.claude-plugin" ] && exit 0

# Scoped to GitHub-adopted repos: need /spec/tracker.md declaring system: github.
TRACKER="${CWD}/spec/tracker.md"
[ -f "${TRACKER}" ] || exit 0
grep -iq '^[[:space:]]*system:[[:space:]]*github' "${TRACKER}" 2>/dev/null || exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Shared classification → shared exempt/nudge policy. spec/docs/generated/lockfile
# are exempt; implementation/operations/unknown nudge.
CLASS="$(e22_classify_path "${FILE}")"
[ "$(e22_class_nudges "${CLASS}")" = "nudge" ] || exit 0

# Fire at most once per session+repo.
CWD_KEY="$(printf '%s' "${CWD}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/e22-issuefirst-nudge.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: > "${MARK}" 2>/dev/null || true

SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\')"

CTX="Element 22 issue-first check: this repo's /spec/tracker.md uses GitHub Issues, and you are about to write ${CLASS} (${SAFE_FILE}). Every implementation-affecting mutation (code/config/infra/behavior — not spec, docs, or lockfiles) needs a GitHub issue BEFORE the first mutation — reuse the issue the user named, or find-or-create one via /e22-standards:e22-tracker-sync (an explicit fix/implement/add request needs no confirmation to create it; see the Authorization & confirmation block in ISSUE-WORKFLOW.md), then run implementation through /e22-standards:e22-work. This nudge does not block the write and fires once per session."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
