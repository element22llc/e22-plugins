#!/usr/bin/env sh
# steer PreToolUse hook - ASCII-in-code-and-values gate.
#
# Rule 85 ("ASCII in code and values") says typographic characters - em/en
# dashes, curly quotes, ellipsis, arrows, non-breaking spaces - belong in prose
# and docs, never in code, identifiers, config keys/values, or strings bound for
# an external API. It is always-on prose, and prose is easy to skip mid-session.
# The failure it prevents is not cosmetic: an AWS resource name or description
# carrying an em dash is rejected by the API's validator, and the break surfaces
# at deploy time rather than at write time.
#
# WHY A DENY, NOT A NUDGE
#   The sibling write-path checks (check-write-nudges.sh, check-comment-density.sh)
#   emit additionalContext and let the write land, because what they flag is a
#   judgement call. This one is deterministic: the character is either in a value
#   position or it is not. A post-hoc notice cannot unwrite the file, and a
#   mechanical fixup is unsafe - rewriting a curly quote inside a string literal
#   can break its quoting, and folding a non-breaking space silently mangles
#   copy. So the write is denied and the model rewrites it, mirroring
#   check-version-pins.sh (deny on Claude, ask on the Copilot CLI, whose
#   preToolUse is fail-closed and still Preview).
#
# WHY COMMENT-AWARE
#   Rule 85 permits these characters in prose, and the org's own scaffold relies
#   on that: every bundled mise.toml / compose.yaml / CI script opens with a
#   typographic header comment, by the Code comments rule. Scanning raw file
#   content would deny steer's own templates. So comments are stripped before the
#   scan and only value positions are inspected. Every stripping heuristic is
#   biased to over-strip: a missed character leaves the always-on rule in force,
#   whereas a false deny is what makes a gate get switched off.
#
# WHAT IS NOT FLAGGED
#   Accented Latin letters, CJK, and guillemets are untouched - only the
#   enumerated typographic set matches, so French, Spanish, or German copy passes
#   unchanged. Documentation, the /spec spine, lockfiles and generated output are
#   out of scope by class; a file type with no known comment syntax is skipped
#   entirely rather than guessed at.
#
# Bypass a deliberate character (a test fixture that must assert one, a Unicode
# table): put `steer:allow-typographic` anywhere in the introduced content.
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

# The plugin's own source repo: its pre-commit gates own style there, and the
# hook fixtures below must be able to contain the very characters it denies.
#
# OUTSIDE A WORK TREE THE GATE STAYS ON. When the root cannot be resolved this
# falls back to cwd rather than exiting, matching the sibling deny gate
# (check-version-pins.sh) rather than the advisory nudges, which bail with
# `|| exit 0`. The nudges are about repo state (a /spec spine, a tracker), which
# a non-repo genuinely does not have; this rule is about the bytes in the file
# and holds just as well in a scratch directory. Exiting there would switch the
# gate off in exactly the ad-hoc places a stray em dash is most likely to be
# written and least likely to be caught by review. The plugin-repo skip is then
# best-effort (a relative ROOT resolves against the hook process's cwd), which
# is the right failure direction: at worst the gate stays on.
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_action_root "${CWD}" "${FILE}")" || ROOT="${CWD}"
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Prose is where these characters belong, so documentation, the /spec spine,
# lockfiles and generated output are out of scope. `unknown` is NOT swept in
# conservatively the way the nudges sweep it - a deny needs a known file type.
# .hcl is allowed through a local allowlist rather than by widening classify.sh,
# which would change what the sibling nudges fire on.
CLASS="$(steer_classify_path "${FILE}")"
case "${CLASS}" in
implementation | operations) : ;;
unknown) case "${FILE}" in *.hcl) : ;; *) exit 0 ;; esac ;;
*) exit 0 ;;
esac

STYLE="$(steer_comment_style "${FILE}")"
[ -n "${STYLE}" ] || exit 0

# Only the introduced text: Write->content, Edit->new_string, MultiEdit->every
# edits[].new_string, NotebookEdit->new_source. old_string is never inspected, so
# an edit that REMOVES an em dash is not itself denied.
CONTENT="$(steer_mutation_content)"
[ -z "${CONTENT}" ] && exit 0

# Deliberate character, declared in the same content.
case "${CONTENT}" in *steer:allow-typographic*) exit 0 ;; esac

FOUND="$(printf '%s' "${CONTENT}" | steer_strip_comments "${STYLE}" | steer_typographic_names)"
[ -n "${FOUND}" ] || exit 0

SAFE_FILE="$(steer_json_safe "${FILE}")"
SAFE_FOUND="$(steer_json_safe "${FOUND}")"
REASON="Non-ASCII typographic characters in code or values - ${SAFE_FILE} introduces: ${SAFE_FOUND}. Org standard (rule 85, ASCII in code and values): typographic characters belong in prose and docs, never in code, identifiers, config keys/values, or strings bound for an external API - strict validators reject them (an AWS resource name or description carrying an em dash fails at deploy time). Rewrite the offending value with the ASCII equivalent shown above, then retry. Only VALUE positions were inspected; comments were skipped, so a typographic character in a comment header is fine and is not what this is reporting. If the character is deliberate (a fixture asserting it, a Unicode table, required copy), put 'steer:allow-typographic' in the same content and retry."

if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
	printf '{"permissionDecision":"ask","permissionDecisionReason":"%s"}\n' "${REASON}"
else
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "${REASON}"
fi
exit 0
