# shellcheck shell=sh
# (sourced, not executed — no shebang; the directive sets ShellCheck's dialect.)
#
# steer hook helper — deterministic best-effort field extraction.
#
# NOT a general JSON parser, and it does not claim arbitrary-JSON correctness.
# It extracts a small set of *known top-level / tool_input fields* from the exact
# hook-input shapes the plugin's hooks use — `tool_input` fields on the tool
# events, and top-level fields on the lifecycle events — with two strategies:
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

# steer_json_string — stdin → one JSON string literal (quotes included), lossless.
# The counterpart of steer_json_safe for payloads that must survive intact: the
# whole ruleset the Copilot surfaces receive as `additionalContext`. Backslash
# and double quote are escaped, tab / CR / newline become their escapes, and the
# remaining C0 control bytes (which cannot appear in JSON text and have no
# business in Markdown) are dropped. Runs under LC_ALL=C so multibyte UTF-8
# passes through as bytes — JSON allows raw UTF-8 in strings. One awk pass;
# ~7 ms for 60 K characters. The input's final newline, if any, is not emitted.
steer_json_string() {
	LC_ALL=C awk '
	BEGIN { ORS = ""; printf "\"" }
	{
		s = $0
		gsub(/\\/, "\\\\", s)
		gsub(/"/, "\\\"", s)
		gsub(/\t/, "\\t", s)
		gsub(/\r/, "\\r", s)
		gsub(/[\001-\010\013\014\016-\037]/, "", s)
		if (NR > 1) printf "\\n"
		printf "%s", s
	}
	END { printf "\"" }'
}

# steer_hook_host — which harness is running this hook: `claude` or `copilot`.
# The two want different SessionStart stdout (Claude Code: raw text; the Copilot
# surfaces: a JSON envelope), and VS Code's Copilot Chat runs the plugin's Claude
# hooks.json as-is, so the script — not the manifest — has to tell them apart.
#   1. STEER_HOOK_TARGET=copilot, set by the generated Copilot CLI manifest
#      (copilot-hooks.json)                                          → copilot
#   2. the payload carries "permission_mode" — a documented Claude Code common
#      input field that neither Copilot surface sends                → claude
#   3. the payload has "hook_event_name", "model" and "timestamp" but no
#      "permission_mode" — the shape Copilot Chat in VS Code sends
#      (observed on VS Code 1.135; the CLI's PascalCase form has no "model") → copilot
#   4. anything else                                                 → claude
# The default is deliberately Claude: mis-reading Claude Code as Copilot would
# swap its parted raw delivery for one oversized JSON command and lose the
# ruleset, whereas mis-reading a Copilot surface as Claude only keeps today's
# behaviour (raw stdout, discarded there). Reads $STEER_INPUT like steer_field.
steer_hook_host() {
	if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
		printf 'copilot'
		return
	fi
	case "${STEER_INPUT}" in
	*'"permission_mode"'*)
		printf 'claude'
		return
		;;
	esac
	case "${STEER_INPUT}" in
	*'"hook_event_name"'*)
		case "${STEER_INPUT}" in
		*'"model"'*)
			case "${STEER_INPUT}" in
			*'"timestamp"'*)
				printf 'copilot'
				return
				;;
			esac
			;;
		esac
		;;
	esac
	printf 'claude'
}
