#!/usr/bin/env sh
# e22-standards PreToolUse hook — spec-before-code nudge (point-of-action).
#
# WHY THIS EXISTS
#   check-unmanaged-repo.sh (SessionStart) flags a missing /spec spine once, at
#   session start. But a startup banner is easy to move past, and a repo that is
#   empty at startup can grow its first feature code mid-session — after the
#   banner already fired. This hook re-asserts the spec-first rule at the exact
#   moment it's about to be broken: the first write of code/config into a repo
#   that still has no /spec spine.
#
# MECHANISM
#   Best-effort, non-blocking by design. Emits hookSpecificOutput.additionalContext
#   and exits 0 — the write proceeds; the model just sees the reminder. Fires AT
#   MOST ONCE per session+repo (a marker in TMPDIR keyed by session_id + cwd) so
#   it nudges, never nags. Never fires once /spec exists. The shared classifier
#   (lib/classify.sh) decides which writes are feature work (implementation /
#   operations / unknown → nudge) vs bootstrapping the spine itself
#   (spec / documentation / generated / lockfile → exempt).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. tool_input/session_id/cwd arrive as JSON on stdin.
#   Fail-open everywhere: any ambiguity → exit 0, never block a write. Honest
#   limitation: a best-effort nudge, not a gate.

E22_INPUT="$(cat)"
[ -z "${E22_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"

FILE="$(e22_field file_path)"
SID="$(e22_field session_id)"
CWD="$(e22_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Already managed — /spec spine exists. Silent.
[ -d "${CWD}/spec" ] && exit 0
# Not a git repo, or the plugin's own source repo → not our concern.
[ -e "${CWD}/.git" ] || exit 0
[ -d "${CWD}/.claude-plugin" ] && exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Shared classification → shared exempt/nudge policy.
CLASS="$(e22_classify_path "${FILE}")"
[ "$(e22_class_nudges "${CLASS}")" = "nudge" ] || exit 0

# Fire at most once per session+repo. Marker lives in TMPDIR (never the working
# tree), keyed by session id + a cheap hash of the repo path.
CWD_KEY="$(printf '%s' "${CWD}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/e22-gf-nudge.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: > "${MARK}" 2>/dev/null || true

# Sanitize the path before embedding it in JSON.
SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\')"

CTX="Element 22 spec-first check: this repo has no /spec spine, and you are about to write ${CLASS} (${SAFE_FILE}). A user-facing feature gets /spec/features/<id>/intent.md + contract.md (run /e22-standards:e22-spec-scaffold) before or alongside its code, and the initial stack is recorded as an ADR (run /e22-standards:e22-adr) — do not let the build degrade to toolchain conventions only. If you are starting this product from scratch, bootstrap first with /e22-standards:e22-init (greenfield path); if you are reverse-engineering pre-existing code, run /e22-standards:e22-adopt. This nudge does not block the write and fires once per session; it stops once /spec exists."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
