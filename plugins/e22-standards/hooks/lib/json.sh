# shellcheck shell=sh
# (sourced, not executed — no shebang; the directive sets ShellCheck's dialect.)
#
# e22-standards hook helper — deterministic best-effort field extraction.
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
# Functions read the hook input from the variable $E22_INPUT (set by the caller
# once, so the raw stdin is read a single time).

# Unescape a JSON string body (the bytes between the surrounding quotes).
# Handles \\ \" \/ \n \t \r correctly, including escaped backslashes, by parking
# \\ on a sentinel control char first so \\n is NOT turned into a newline.
e22_json_unescape() {
  _S="$(printf '\001')"
  sed -e "s/\\\\\\\\/${_S}/g" \
      -e 's/\\"/"/g' \
      -e 's/\\\//\//g' \
      -e 's/\\n/\n/g' \
      -e 's/\\t/\t/g' \
      -e 's/\\r/\r/g' \
      -e "s/${_S}/\\\\/g"
}

# e22_have_jq — true if a usable jq is on PATH.
e22_have_jq() { command -v jq >/dev/null 2>&1; }

# e22_field <name> — value of a string field, preferring tool_input.<name> then
# top-level .<name>. Empty if absent/unextractable. Picks the FIRST matching
# occurrence (so a repeated key buried inside a later `content` value can't shadow
# the real tool_input field) and tolerates escaped quotes/backslashes in values.
e22_field() {
  _name="$1"
  if e22_have_jq; then
    printf '%s' "${E22_INPUT}" \
      | jq -r --arg k "${_name}" '(.tool_input[$k] // .[$k]) // empty' 2>/dev/null
    return
  fi
  # Fallback: first JSON string value for the key. The value pattern allows
  # escaped chars (\\.) so an embedded \" does not end the match early.
  printf '%s' "${E22_INPUT}" \
    | grep -oE "\"${_name}\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
    | head -n 1 \
    | sed -E "s/^\"${_name}\"[[:space:]]*:[[:space:]]*\"//; s/\"$//" \
    | e22_json_unescape
}

# e22_tool — the tool name (top-level .tool_name).
e22_tool() {
  if e22_have_jq; then
    printf '%s' "${E22_INPUT}" | jq -r '.tool_name // empty' 2>/dev/null
    return
  fi
  printf '%s' "${E22_INPUT}" \
    | grep -oE "\"tool_name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -n 1 | sed -E 's/.*:[[:space:]]*"//; s/"$//'
}

# e22_mutation_content — the *added/new* text a tool would write, unescaped, so a
# content check inspects only what is being introduced (F13: tool-aware):
#   Write     -> content
#   Edit      -> new_string   (NEVER old_string, so version upgrades aren't blocked)
#   MultiEdit -> every edits[].new_string, newline-joined
#   Bash      -> nothing (command text is intentionally skipped; the CI repo-scan
#                is the stronger backstop) — documented bypass.
# Empty for any other tool.
e22_mutation_content() {
  _tool="$(e22_tool)"
  case "${_tool}" in
    Write) e22_field content ;;
    Edit) e22_field new_string ;;
    MultiEdit)
      if e22_have_jq; then
        printf '%s' "${E22_INPUT}" \
          | jq -r '[.tool_input.edits[]?.new_string] | join("\n")' 2>/dev/null
      else
        printf '%s' "${E22_INPUT}" \
          | grep -oE "\"new_string\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" \
          | sed -E 's/^"new_string"[[:space:]]*:[[:space:]]*"//; s/"$//' \
          | e22_json_unescape
      fi
      ;;
    *) : ;;
  esac
}
