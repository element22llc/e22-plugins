#!/usr/bin/env sh
# steer PostToolUse hook — comment-density notice. The Code comments rule is
# prose the model can skip mid-session; this surfaces a comment-heavy write at
# the moment it lands. Reads the just-written file from disk (so Edit and
# MultiEdit need no payload parsing). Advisory in the 20-33% band; at or above a
# third it returns a `block` decision, which on PostToolUse puts the reason beside
# the tool result rather than undoing the write. POSIX sh, no jq, fail-open.

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
# A shebang and a linter/type-checker directive are machine-read instructions the
# file cannot work without, not prose a reader could delete — counting them made
# short, directive-heavy scripts look comment-bloated and invited stripping the
# real why-comments beside them. They still count toward the line total.
COUNTS="$(awk -v style="${STYLE}" '
	/^[[:space:]]*$/ { next }
	{ total++ }
	NR == 1 && /^#!/ { next }
	/^[[:space:]]*(#|\/\/)[[:space:]]*(shellcheck|noqa|type:|pyright:|mypy:|ruff:|pylint:|flake8:|eslint-|biome-ignore|prettier-ignore|@ts-|steer:)/ { next }
	style == "hash" && /^[[:space:]]*#/ { c++ }
	style == "slash" && /^[[:space:]]*(\/\/|\/\*|\*)/ { c++ }
	style == "dash" && /^[[:space:]]*--/ { c++ }
	END { printf "%d %d", c + 0, total + 0 }' "${TARGET}" 2>/dev/null)"
COMMENTS="${COUNTS% *}"
TOTAL="${COUNTS#* }"
[ "${TOTAL}" -ge 20 ] 2>/dev/null || exit 0

# Two tiers. At or above a third the notice is a `block` decision; the 20-33%
# band is advisory, and exists because that is where the old single threshold
# stayed silent on files that are still far past why-only.
TIER=''
[ $((COMMENTS * 5)) -ge "${TOTAL}" ] && TIER='advise'
[ $((COMMENTS * 3)) -gt "${TOTAL}" ] && TIER='block'
[ -n "${TIER}" ] || exit 0

# File-level opt-out, deliberately unlike the per-line `# steer:allow-pin`:
# density is a property of the whole file. The reason is required — a bare
# marker suppresses nothing, so the escape hatch cannot be taken silently.
if grep -qE '^[[:space:]]*(#|//)[[:space:]]*steer:allow-comments[[:space:]]+[^[:space:]]' "${TARGET}" 2>/dev/null; then
	exit 0
fi

SID="$(steer_field session_id)"
KEY="$(printf '%s' "${TARGET}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-comment-density.${SID:-nosid}.${KEY:-0}"

# Advisory fires once per file per session; a block re-fires while the file is
# still over, because one ignorable notice is what the block tier exists to
# escape — capped, so a file that genuinely cannot be trimmed stops nagging.
if [ "${TIER}" = advise ]; then
	[ -f "${MARK}" ] && exit 0
	: >"${MARK}" 2>/dev/null || true
else
	SEEN="$(cat "${MARK}.block" 2>/dev/null || printf '0')"
	case "${SEEN}" in
	'' | *[!0-9]*) SEEN=0 ;;
	esac
	[ "${SEEN}" -ge 3 ] && exit 0
	printf '%s' "$((SEEN + 1))" >"${MARK}.block" 2>/dev/null || true
	# Clear the advisory marker so a later drop into the advisory band is still heard.
	rm -f "${MARK}" 2>/dev/null || true
fi

PCT=$((COMMENTS * 100 / TOTAL))
SAFE_FILE="$(steer_json_safe "${FILE}")"
MSG="$(printf 'Comment-density check: %s is %s%% comment lines (%s of %s non-blank). The Code comments rule allows a comment only for a non-obvious why. In the code you wrote or touched, delete every comment that restates the code, narrates a step, banners a section, describes the task or its history, or keeps code commented out; keep the why-comments that name a trap, an invariant, or the reason for an escape hatch. Rationale for config belongs in the reference prose or ARCHITECTURE.md, not inline. A pre-existing dense file is not a licence to add more. If every remaining comment earns its line, record that once with `steer:allow-comments <reason>` in a comment.' "${SAFE_FILE}" "${PCT}" "${COMMENTS}" "${TOTAL}")"

# Claude Code reads additionalContext nested under hookSpecificOutput, and takes
# a `block` decision that puts the reason beside the tool result — the write has
# already landed, so this is a louder notice, not a gate. The Copilot CLI has no
# decision field on postToolUse and documents only a top-level additionalContext,
# so the block tier carries its severity in the text instead of being dropped.
if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
	[ "${TIER}" = block ] && MSG="BLOCKED: ${MSG}"
	printf '{"additionalContext":"%s"}\n' "${MSG}"
elif [ "${TIER}" = block ]; then
	printf '{"decision":"block","reason":"%s"}\n' "${MSG}"
else
	printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "${MSG}"
fi
exit 0
