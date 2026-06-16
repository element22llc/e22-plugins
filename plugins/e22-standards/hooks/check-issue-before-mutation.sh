#!/usr/bin/env sh
# e22-standards PreToolUse hook — issue-first nudge (point-of-action).
#
# WHY THIS EXISTS
#   rule 36-issue-first says: in a GitHub-adopted repo, every code/config/infra/
#   behavior change has a GitHub issue before the first repository mutation. The
#   rule is always-on prose, but prose is easy to skip mid-session. This hook
#   re-asserts it at the moment it's about to be broken: the first write of real
#   source code in a repo whose /spec/tracker.md declares `system: github`. It is
#   the lightweight safety net; primary enforcement is routing (/e22-standards:e22-work) + the
#   skills, which actually find-or-create the issue. The hook cannot know whether
#   an issue exists — it only reminds.
#
# MECHANISM
#   Non-blocking. Emits hookSpecificOutput.additionalContext and exits 0 — the
#   write proceeds. Fires AT MOST ONCE per session+repo (marker in TMPDIR keyed
#   by session_id + cwd). Silent unless tracker.md says GitHub; complements
#   check-code-before-spec.sh (which fires when /spec is *missing* — tracker.md
#   lives under /spec, so the two never fire on the same write).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Fail-open everywhere: any ambiguity → exit 0, never block.

INPUT="$(cat)"
[ -z "${INPUT}" ] && exit 0

get() { printf '%s' "${INPUT}" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1; }
FILE="$(get file_path)"
SID="$(get session_id)"
CWD="$(get cwd)"
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

# Bootstrapping / spec / config artifacts are exempt — same spirit as the
# spec-before-code nudge: this is about feature code, not the spine itself.
case "${FILE}" in
  */spec/*|spec/*|*/.claude/*|.claude/*) exit 0 ;;
esac

# Nudge only on real source code (allowlist — precise, few false positives).
case "${FILE}" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.java|*.rb|*.php|*.cs|\
  *.cpp|*.cc|*.c|*.h|*.hpp|*.swift|*.kt|*.scala|*.ex|*.exs|*.vue|*.svelte) ;;
  *) exit 0 ;;
esac

# Fire at most once per session+repo.
CWD_KEY="$(printf '%s' "${CWD}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/e22-issuefirst-nudge.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: > "${MARK}" 2>/dev/null || true

SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\')"

CTX="Element 22 issue-first check: this repo's /spec/tracker.md uses GitHub Issues, and you are about to write source code (${SAFE_FILE}). Every code/config/infra/behavior change needs a GitHub issue BEFORE the first mutation — reuse the issue the user named, or find-or-create one via /e22-standards:e22-tracker-sync (an explicit fix/implement/add request needs no confirmation to create it), then run implementation through /e22-standards:e22-work. This nudge does not block the write and fires once per session."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0
