#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- extraction (lib/json.sh) ---
# Force the no-jq fallback for this whole block: CI/dev usually HAS jq, so without
# this override the hand-rolled grep/sed extractor (the fragile path these cases
# exist to pin) would ship untested. The real steer_have_jq is restored after.
steer_have_jq() { return 1; }
STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"src/a.ts","content":"say \"hi\" and \"file_path\":\"DECOY.ts\""}}'
assert_eq "extract: escaped quotes / decoy file_path" "$(steer_field file_path)" "src/a.ts"

# JSON "a\\nb.ts" decodes to a-backslash-n-b (a literal backslash + 'n'), NOT a
# newline - the escaped-backslash case.
STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"a\\nb.ts","content":"x"}}'
assert_eq "extract: escaped backslash preserved" "$(steer_field file_path)" 'a\nb.ts'

STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"real.ts","content":"\"file_path\":\"fake.ts\""}}'
assert_eq "extract: repeated file_path not shadowed" "$(steer_field file_path)" "real.ts"

# A top-level decoy of the same name, BEFORE tool_input, must not win - the no-jq
# fallback scopes to the post-"tool_input" slice first (mirrors jq's precedence).
STEER_INPUT='{"tool_name":"Write","file_path":"TOP.ts","tool_input":{"file_path":"INNER.ts","content":"x"}}'
assert_eq "extract: top-level decoy file_path not preferred" "$(steer_field file_path)" "INNER.ts"

# steer_target_path: file_path for Write/Edit/MultiEdit, notebook_path for NotebookEdit.
STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"f.ts","content":"x"}}'
assert_eq "extract: target_path uses file_path" "$(steer_target_path)" "f.ts"
STEER_INPUT='{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"nb.ipynb","new_source":"x"}}'
assert_eq "extract: target_path falls back to notebook_path" "$(steer_target_path)" "nb.ipynb"

_p11="$(pin postgres 11)"
STEER_INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"x\",\"content\":\"${_p11}\"}}"
assert_eq "extract: Write content" "$(steer_mutation_content)" "${_p11}"

STEER_INPUT="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"x\",\"old_string\":\"${_p11}\",\"new_string\":\"$(pin postgres 18)\"}}"
assert_eq "extract: Edit uses new_string" "$(steer_mutation_content)" "$(pin postgres 18)"
printf '%s' "$(steer_mutation_content)" | grep -q "${_p11}" && bad "extract: Edit must not include old_string" || ok

STEER_INPUT="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ${_p11}\"}}"
assert_eq "extract: Bash content skipped" "$(steer_mutation_content)" ""

# NotebookEdit new_source IS mutation content (was a dead matcher on the version-pin
# gate before #271 added the arm).
STEER_INPUT='{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"nb.ipynb","new_source":"cell body"}}'
assert_eq "extract: NotebookEdit new_source is mutation content" "$(steer_mutation_content)" "cell body"

# no-jq unescape must decode \n to a REAL newline (issue #271): BSD sed emitted a
# literal 'n' in the replacement, collapsing multi-line content to one line and
# breaking check-version-pins.sh's same-line allow-pin discipline. Assert 2 lines.
assert_eq "unescape: no-jq \\n decodes to a real newline" "$(printf 'a\\nb' | steer_json_unescape | grep -c '')" "2"
# An escaped backslash before n stays literal (a\nb), never a newline.
assert_eq "unescape: no-jq escaped-backslash preserved (a\\nb -> 1 line)" "$(printf 'a\\\\nb' | steer_json_unescape | grep -c '')" "1"
STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"x","content":"a\nb"}}'
assert_eq "extract: no-jq Write content \\n decodes to real newline (2 lines)" "$(steer_mutation_content | grep -c '')" "2"

. "${HOOKS}/lib/json.sh" # restore real steer_have_jq (undo the forced no-jq above)

# steer_json_safe output is embedded raw in a JSON string, which forbids C0 bytes.
assert_eq "json_safe: control bytes dropped, quotes and newlines flattened" \
	"$(steer_json_safe "$(printf 'a\033b\001c"d\\e\nf')")" "abcde f"

# A per-call hook probes jq once per run, not once per `$(steer_field ...)` read.
FAKE="${WORK}/fakejq"
mkdir -p "${FAKE}"
# Logs and fails: a failing probe still counts, and the grep fallback reads the fields.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/calls"\nexit 1\n' "${FAKE}" >"${FAKE}/jq"
chmod +x "${FAKE}/jq"
JR="$(new_repo jqProbe)"
printf 'x\n' >"${JR}/notes.txt"
probes() { # <hook> <stdin> -> number of `jq --version` probes one run made
	: >"${FAKE}/calls"
	ENV="PATH=${FAKE}:/usr/bin:/bin" run_hook "$1" "$2" >/dev/null
	grep -c '^--version$' "${FAKE}/calls"
}
for h in check-version-pins.sh check-write-nudges.sh format-on-write.sh check-comment-density.sh; do
	assert_eq "jq probe: ${h} probes once" "$(probes "${h}" "$(json_write "${JR}" jq1 "${JR}/notes.txt" x)")" 1
done
assert_eq "jq probe: check-bash-actions.sh probes once" \
	"$(probes check-bash-actions.sh "$(bash_json "${JR}" jq2 'gh pr view 5')")" 1
: >"${FAKE}/calls"
ENV="PATH=${FAKE}:/usr/bin:/bin" run_hook check-bash-actions.sh "$(bash_json "${JR}" jq3 'ls -la')" >/dev/null
assert_rc "jq probe: the no-jq fast path exits cleanly" "$(last_rc)" 0
assert_eq "jq probe: a command with no gh or git push spawns no jq" "$(wc -l <"${FAKE}/calls" | tr -d ' ')" 0

finish
