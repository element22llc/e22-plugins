#!/usr/bin/env sh
# steer PreToolUse hook - ASCII-everywhere gate.
#
# Rule 85 says typographic characters - em/en dashes, curly quotes, ellipsis,
# arrows, non-breaking spaces - never appear in anything we produce: not in
# code, config or identifiers, and not in comments, specs, docs or commit text
# either. It is always-on prose, and always-on prose is what a long session
# drifts past. This denies the write instead.
#
# WHY A DENY, NOT A NUDGE
#   The sibling write-path checks (check-write-nudges.sh, check-comment-density.sh)
#   emit additionalContext and let the write land, because what they flag is a
#   judgement call. This one is deterministic: the character is either there or
#   it is not. A post-hoc notice cannot unwrite the file, and a mechanical fixup
#   is unsafe - rewriting a curly quote inside a string literal can break its
#   quoting, and folding a non-breaking space silently mangles copy. So the
#   write is denied and the model rewrites it, mirroring check-version-pins.sh
#   (deny on Claude, ask on the Copilot CLI, whose preToolUse is fail-closed and
#   still Preview).
#
# WHY PROSE IS NOT EXEMPT
#   It used to be: an earlier version stripped comments and scanned only value
#   positions, because the concrete failure was an AWS resource name rejected by
#   its validator. That left the characters free to spread through comments,
#   specs, docs and chat, which is the half the org actually objected to - they
#   read as machine-written and they break anything downstream that is strict
#   about input. The scan is now raw: same character set, every position.
#
# WHAT IS NOT FLAGGED
#   Accented Latin letters, CJK, guillemets and emoji are untouched - only the
#   enumerated set matches, so French, Spanish or German copy passes unchanged.
#   Lockfiles and generated output are out of scope by class, and a file type
#   that is not recognised text is skipped rather than guessed at.
#
# Bypass a deliberate character (a fixture asserting one, a Unicode table, a
# quoted external string): put `steer:allow-typographic` in the same content.
#
# Bash-mediated writes (heredocs) are not inspected - the same documented gap as
# check-version-pins.sh, whose backstop is a committed-state CI scan.
#
# POSIX sh; no jq, no network. Fail-open on any ambiguity.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/typographic.sh"

FILE="$(steer_field file_path)"
[ -n "${FILE}" ] || exit 0

# The plugin's own source repo: its pre-commit gates own style there (see
# scripts/check-ascii.sh), and the hook fixtures must be able to contain the
# very characters this denies.
#
# OUTSIDE A WORK TREE THE GATE STAYS ON. When the root cannot be resolved this
# falls back to cwd rather than exiting, matching the sibling deny gate
# (check-version-pins.sh) rather than the advisory nudges, which bail with
# `|| exit 0`. The nudges are about repo state (a /spec spine, a tracker), which
# a non-repo genuinely does not have; this rule is about the bytes in the file
# and holds just as well in a scratch directory. The plugin-repo skip is then
# best-effort (a relative ROOT resolves against the hook process's cwd), which
# is the right failure direction: at worst the gate stays on.
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_action_root "${CWD}" "${FILE}")" || ROOT="${CWD}"
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Every authored text class is in scope now that prose is not exempt. Only
# lockfiles and generated output are excluded - both are machine-written, and a
# vendored bundle is not ours to rewrite. `unknown` stays out too: a deny needs
# a recognised text type, and .hcl is allowed through a local allowlist rather
# than by widening classify.sh, which would change what the nudges fire on.
CLASS="$(steer_classify_path "${FILE}")"
case "${CLASS}" in
implementation | operations | documentation | spec) : ;;
unknown) case "${FILE}" in *.hcl) : ;; *) exit 0 ;; esac ;;
*) exit 0 ;;
esac

# Only the introduced text: Write->content, Edit->new_string, MultiEdit->every
# edits[].new_string, NotebookEdit->new_source. old_string is never inspected, so
# an edit that REMOVES an em dash is not itself denied.
CONTENT="$(steer_mutation_content)"
[ -z "${CONTENT}" ] && exit 0

# Deliberate character, declared in the same content.
case "${CONTENT}" in *steer:allow-typographic*) exit 0 ;; esac

FOUND="$(printf '%s' "${CONTENT}" | steer_typographic_names)"
[ -n "${FOUND}" ] || exit 0

SAFE_FILE="$(steer_json_safe "${FILE}")"
SAFE_FOUND="$(steer_json_safe "${FOUND}")"
REASON="Non-ASCII typographic characters - ${SAFE_FILE} introduces: ${SAFE_FOUND}. Org standard (rule 85, ASCII everywhere): these characters never appear in anything we produce - not in code, config, identifiers or strings bound for an external API, and not in comments, specs, docs or commit text either. Strict validators reject them (an AWS resource name or description carrying an em dash fails at deploy time) and they read as machine-written. Rewrite using the ASCII equivalent shown above, then retry. Accented letters, guillemets and other non-English characters are NOT what this is about and are never flagged - but the apostrophe is ' in every language, French included, so a typeset apostrophe is a violation like any other. If the character is genuinely required (a fixture asserting it, a Unicode table, a quoted external string), put 'steer:allow-typographic' in the same content and retry."

if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
	printf '{"permissionDecision":"ask","permissionDecisionReason":"%s"}\n' "${REASON}"
else
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "${REASON}"
fi
exit 0
