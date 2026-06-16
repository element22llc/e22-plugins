#!/usr/bin/env sh
# steer PreToolUse hook — spec-before-code nudge (point-of-action).
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

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"

FILE="$(steer_target_path)"
SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Resolve the work-tree root (cwd may be a subdir like apps/web). Not a git work
# tree → not a project we manage. Silent.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
# The plugin's own source repo → not our concern.
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Only a complete, version-stamped spec spine counts as "managed". A bare,
# foreign, or half-migrated spec/ must NOT silence the spec-first nudge.
STATE="$(steer_spine_state "${ROOT}")"
[ "${STATE}" = "managed" ] && exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Shared classification → shared exempt/nudge policy.
CLASS="$(steer_classify_path "${FILE}")"
[ "$(steer_class_nudges "${CLASS}")" = "nudge" ] || exit 0

# Fire at most once per session+repo. Marker lives in TMPDIR (never the working
# tree), keyed by session id + a cheap hash of the repo path.
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-gf-nudge.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

# Sanitize the path before embedding it in JSON.
SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\')"

# State-specific framing: an absent spine vs a foreign spec/ vs a damaged spine
# call for different first moves.
case "${STATE}" in
foreign)
	SPINE_NOTE="a spec/ directory exists but has no spec-spine marker (spec/.version) — if this repo should be standards-managed, run /steer:adopt to reverse-engineer the spine from the code; otherwise this is not an spec spine"
	;;
damaged)
	SPINE_NOTE="this repo has an incomplete spec spine (spec/.version is present but spine files are missing) — run /steer:sync to repair it"
	;;
*)
	SPINE_NOTE="this repo has no /spec spine — if you are starting this product from scratch, bootstrap first with /steer:init (greenfield path); if you are reverse-engineering pre-existing code, run /steer:adopt"
	;;
esac

CTX="Spec-first check: ${SPINE_NOTE}, and you are about to write ${CLASS} (${SAFE_FILE}). A user-facing feature gets /spec/features/<id>/intent.md + contract.md (run /steer:spec-scaffold) before or alongside its code, and the initial stack is recorded as an ADR (run /steer:adr) — do not let the build degrade to toolchain conventions only. This nudge does not block the write and fires once per session; it stops once a complete /spec spine exists."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
