#!/usr/bin/env sh
# e22-standards PreToolUse hook — spec-before-code nudge (point-of-action).
#
# WHY THIS EXISTS
#   check-unmanaged-repo.sh (SessionStart) flags a missing /spec spine once, at
#   session start. But a startup banner is easy to move past, and a repo that is
#   empty at startup can grow its first feature code mid-session — after the
#   banner already fired. This hook re-asserts the spec-first rule at the exact
#   moment it's about to be broken: the first write of real source code into a
#   repo that still has no /spec spine. Same philosophy as check-version-pins.sh
#   — enforce the procedure at point-of-action, where prose alone gets skipped.
#
# MECHANISM
#   Non-blocking by design. Emits `hookSpecificOutput.additionalContext` (which
#   PreToolUse supports) and exits 0 — the write proceeds; the model just sees
#   the reminder next to the tool result. Fires AT MOST ONCE per session+repo
#   (a marker in TMPDIR keyed by session_id + cwd) so it nudges, never nags. It
#   never fires once /spec exists, and is silent for docs/config/scaffolding and
#   for files under spec/ or .claude/ — writing those is bootstrapping, not
#   feature code ahead of a spec.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. tool_input/session_id/cwd arrive as JSON on stdin. Fail-
#   open everywhere: any ambiguity → exit 0, never block a write.

INPUT="$(cat)"
[ -z "${INPUT}" ] && exit 0

# Pull a top-level/tool_input string field by name (first match; values survive
# JSON encoding verbatim, so a plain extract is enough).
get() { printf '%s' "${INPUT}" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1; }
FILE="$(get file_path)"
SID="$(get session_id)"
CWD="$(get cwd)"
[ -n "${CWD}" ] || CWD="."

# Already managed — /spec spine exists. Silent.
[ -d "${CWD}/spec" ] && exit 0
# Not a git repo, or the plugin's own source repo → not our concern.
[ -e "${CWD}/.git" ] || exit 0
[ -d "${CWD}/.claude-plugin" ] && exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Bootstrapping artifacts are exempt — these are the spec/scaffolding you write
# to GET a spine, not feature code that runs ahead of one.
case "${FILE}" in
  */spec/*|spec/*|*/.claude/*|.claude/*) exit 0 ;;
esac

# Nudge only on real source code (allowlist — precise, few false positives).
case "${FILE}" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.java|*.rb|*.php|*.cs|\
  *.cpp|*.cc|*.c|*.h|*.hpp|*.swift|*.kt|*.scala|*.ex|*.exs|*.vue|*.svelte) ;;
  *) exit 0 ;;
esac

# Fire at most once per session+repo — re-injecting on every write would be
# noise. Marker lives in TMPDIR (never touches the working tree), keyed by
# session id + a cheap hash of the repo path.
CWD_KEY="$(printf '%s' "${CWD}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/e22-gf-nudge.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: > "${MARK}" 2>/dev/null || true

# Sanitize the path before embedding it in JSON (paths rarely contain " or \,
# but never trust that).
SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\')"

CTX="Element 22 spec-first check: this repo has no /spec spine, and you are about to write source code (${SAFE_FILE}). A user-facing feature gets /spec/features/<id>/intent.md + contract.md (run /e22-spec-scaffold) before or alongside its code, and the initial stack is recorded as an ADR (run /e22-adr) — do not let the build degrade to toolchain conventions only. If you are starting this product from scratch, bootstrap first with /e22-init (greenfield path); if you are reverse-engineering pre-existing code, run /e22-adopt. This nudge does not block the write and fires once per session; it stops once /spec exists."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
