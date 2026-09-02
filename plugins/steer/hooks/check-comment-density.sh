#!/usr/bin/env sh
# steer PostToolUse hook — comment-density notice. The Code comments rule is
# prose the model can skip mid-session; this surfaces a comment-heavy write at
# the moment it lands. Reads the just-written file from disk (so Edit and
# MultiEdit need no payload parsing), emits additionalContext only, never blocks.
# POSIX sh, no jq, fail-open.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

FILE="$(steer_field file_path)"
[ -n "${FILE}" ] || exit 0
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

ROOT="$(steer_action_root "${CWD}" "${FILE}")" || exit 0
# The plugin's own source repo: its pre-commit gates own style there.
[ -d "${ROOT}/.claude-plugin" ] && exit 0

case "${FILE}" in
/*) TARGET="${FILE}" ;;
*) TARGET="${CWD}/${FILE}" ;;
esac
[ -f "${TARGET}" ] || exit 0

# Comment syntax by file name; prose, JSON, HTML and unknown types are skipped.
# dependabot.yml has no conditional include, so its per-stack blocks are
# commented-out code by necessity — a notice there would invite deleting them.
case "${TARGET##*/}" in
dependabot.yml) exit 0 ;;
Dockerfile | Dockerfile.* | Makefile | *.py | *.sh | *.bash | *.zsh | *.rb | *.pl | *.toml | *.yaml | *.yml | *.tf | *.hcl | *.ini | *.cfg) STYLE="hash" ;;
*.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs | *.go | *.rs | *.java | *.kt | *.kts | *.swift | *.c | *.h | *.cc | *.cpp | *.hpp | *.cs | *.scala | *.dart | *.php) STYLE="slash" ;;
*.sql | *.lua) STYLE="dash" ;;
*) exit 0 ;;
esac

# Only a line's leading marker counts, so a `#` inside a string never does.
COUNTS="$(awk -v style="${STYLE}" '
	/^[[:space:]]*$/ { next }
	{ total++ }
	style == "hash" && /^[[:space:]]*#/ { c++ }
	style == "slash" && /^[[:space:]]*(\/\/|\/\*|\*)/ { c++ }
	style == "dash" && /^[[:space:]]*--/ { c++ }
	END { printf "%d %d", c + 0, total + 0 }' "${TARGET}" 2>/dev/null)"
COMMENTS="${COUNTS% *}"
TOTAL="${COUNTS#* }"
[ "${TOTAL}" -ge 20 ] 2>/dev/null || exit 0
[ $((COMMENTS * 3)) -gt "${TOTAL}" ] || exit 0

# Once per file per session: the first notice is the useful one.
SID="$(steer_field session_id)"
KEY="$(printf '%s' "${TARGET}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-comment-density.${SID:-nosid}.${KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

PCT=$((COMMENTS * 100 / TOTAL))
SAFE_FILE="$(steer_json_safe "${FILE}")"
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Comment-density check: %s is %s%% comment lines (%s of %s non-blank). The Code comments rule allows a comment only for a non-obvious why. In the code you wrote or touched, delete every comment that restates the code, narrates a step, banners a section, describes the task or its history, or keeps code commented out; keep the why-comments that name a trap, an invariant, or the reason for an escape hatch. Rationale for config belongs in the reference prose or ARCHITECTURE.md, not inline. A pre-existing dense file is not a licence to add more. This notice fires once per file per session."}}\n' "${SAFE_FILE}" "${PCT}" "${COMMENTS}" "${TOTAL}"
exit 0
