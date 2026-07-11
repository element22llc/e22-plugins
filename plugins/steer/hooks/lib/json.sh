# shellcheck shell=sh
# (sourced, not executed — no shebang; the directive sets ShellCheck's dialect.)
#
# steer hook helper — deterministic best-effort field extraction.
#
# NOT a general JSON parser, and it does not claim arbitrary-JSON correctness.
# It extracts a small set of *known top-level / tool_input fields* from the exact
# PreToolUse hook-input shapes the plugin's hooks use, with two strategies:
#
#   1. `jq` when present (authoritative).
#   2. otherwise a narrow grep/sed extractor for those exact shapes.
#
# If neither can confidently extract, the caller fails open (the hooks treat an
# empty result as "nothing to act on"). POSIX sh; source this file.
#
# Functions read the hook input from the variable $STEER_INPUT (set by the caller
# once, so the raw stdin is read a single time).

# Unescape a JSON string body (the bytes between the surrounding quotes).
# Handles \\ \" \/ \n \t \r correctly, including escaped backslashes, by parking
# \\ on a sentinel control char first so \\n is NOT turned into a newline.
#
# awk, not sed: POSIX leaves \n/\t/\r in a sed *replacement* undefined, and BSD
# sed (the macOS default — the exact jq-less environment this fallback exists for)
# emits literal n/t/r instead of the control chars, collapsing multi-line content
# to one line. awk's gsub replacements are portable across BSD and GNU.
steer_json_unescape() {
	awk '{
		gsub(/\\\\/, "\001")   # park escaped backslashes on a sentinel first
		gsub(/\\"/, "\"")
		gsub(/\\\//, "/")
		gsub(/\\n/, "\n")
		gsub(/\\t/, "\t")
		gsub(/\\r/, "\r")
		gsub(/\001/, "\\")     # restore parked backslashes as a single backslash
		printf "%s%s", sep, $0
		sep = "\n"
	}'
}

# steer_have_jq — true if a usable jq is on PATH.
steer_have_jq() { command -v jq >/dev/null 2>&1; }

# _steer_field_grep <name> <json> — FIRST JSON string value for <name> in <json>,
# returned still-escaped (caller unescapes). The value pattern allows escaped
# chars (\\.) so an embedded \" does not end the match early.
_steer_field_grep() {
	printf '%s' "$2" |
		grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" |
		head -n 1 |
		sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"$//"
}

# steer_field <name> — value of a string field, preferring tool_input.<name> then
# top-level .<name>. Empty if absent/unextractable. The no-jq fallback mirrors the
# jq precedence by searching the slice AFTER the "tool_input" key first (so a
# top-level decoy field of the same name can't win), then the whole document.
# Within either slice the FIRST match wins, so a repeated key buried in a later
# `content` value can't shadow the real field. Tolerates escaped quotes/backslashes.
steer_field() {
	_name="$1"
	if steer_have_jq; then
		printf '%s' "${STEER_INPUT}" |
			jq -r --arg k "${_name}" '(.tool_input[$k] // .[$k]) // empty' 2>/dev/null
		return
	fi
	_val="$(_steer_field_grep "${_name}" "${STEER_INPUT#*\"tool_input\"}")"
	[ -n "${_val}" ] || _val="$(_steer_field_grep "${_name}" "${STEER_INPUT}")"
	printf '%s' "${_val}" | steer_json_unescape
}

# steer_target_path — the path a mutating tool would write: tool_input.file_path
# for Write/Edit/MultiEdit, tool_input.notebook_path for NotebookEdit. Empty if
# neither is present (e.g. a Bash call). Lets the point-of-action hooks classify
# notebook writes the same way they classify ordinary file writes.
steer_target_path() {
	_fp="$(steer_field file_path)"
	if [ -n "${_fp}" ]; then
		printf '%s' "${_fp}"
		return
	fi
	steer_field notebook_path
}

# steer_tool — the tool name (top-level .tool_name).
steer_tool() {
	if steer_have_jq; then
		printf '%s' "${STEER_INPUT}" | jq -r '.tool_name // empty' 2>/dev/null
		return
	fi
	printf '%s' "${STEER_INPUT}" |
		grep -oE "\"tool_name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" |
		head -n 1 | sed -E 's/.*:[[:space:]]*"//; s/"$//'
}

# steer_mutation_content — the *added/new* text a tool would write, unescaped, so a
# content check inspects only what is being introduced (F13: tool-aware):
#   Write        -> content
#   Edit         -> new_string   (NEVER old_string, so version upgrades aren't blocked)
#   MultiEdit    -> every edits[].new_string, newline-joined
#   NotebookEdit -> new_source   (the cell body being written)
#   Bash         -> nothing (command text is intentionally skipped; the CI repo-scan
#                   is the stronger backstop) — documented bypass.
# Empty for any other tool.
steer_mutation_content() {
	_tool="$(steer_tool)"
	case "${_tool}" in
	Write) steer_field content ;;
	Edit) steer_field new_string ;;
	NotebookEdit) steer_field new_source ;;
	MultiEdit)
		if steer_have_jq; then
			printf '%s' "${STEER_INPUT}" |
				jq -r '[.tool_input.edits[]?.new_string] | join("\n")' 2>/dev/null
		else
			printf '%s' "${STEER_INPUT}" |
				grep -oE "\"new_string\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" |
				sed -E 's/^"new_string"[[:space:]]*:[[:space:]]*"//; s/"$//' |
				steer_json_unescape
		fi
		;;
	*) : ;;
	esac
}

# steer_json_safe <value> — sanitize a value for embedding in a hand-built JSON
# string: strip double quotes and backslashes, flatten newlines/tabs/CRs to
# spaces. The shared idiom behind every hook's SAFE_* interpolation — one home
# so a fix to the sanitization lands everywhere at once.
steer_json_safe() {
	printf '%s' "$1" | tr -d '"\\' | tr '\n\t\r' '   '
}
