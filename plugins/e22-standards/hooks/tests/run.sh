#!/usr/bin/env sh
# e22-standards hook fixture suite — POSIX sh, network stubbed via
# E22_EOL_FIXTURE_DIR. Feeds canned PreToolUse JSON on stdin and asserts the
# hook's decision (deny / advisory additionalContext / silent allow) plus the
# field-extraction and classification behaviour. Run from anywhere:
#
#     sh plugins/e22-standards/hooks/tests/run.sh
#
# Exit 0 when all cases pass, 1 otherwise.
#
# NOTE: pin literals are assembled at runtime via pin() so this file's *source*
# never contains a `name:NN` token — otherwise the plugin's own version-pin hook
# (active in the authoring session) would block writing this test.

# shellcheck disable=SC2015,SC2034
# SC2015 — the assert helpers use the `cond && ok || bad` idiom; `ok` only bumps a
#          counter and never fails, so the `|| bad` branch runs only on a real
#          assertion failure. Intentional, not the if-then-else footgun.
# SC2034 — E22_INPUT is read by the sourced lib/json.sh functions (which ShellCheck
#          does not follow), so it reads as "unused" here though it is the input.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN="$(CDPATH='' cd -- "${HERE}/../.." && pwd)"
HOOKS="${PLUGIN}/hooks"
EOL="${HERE}/eol-fixtures"
export CLAUDE_PLUGIN_ROOT="${PLUGIN}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/e22-hooktests.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
PASS=0 ; FAIL=0

pin() { printf '%s:%s' "$1" "$2"; }   # pin postgres 11 -> the matchable token

run_hook() {  # <hook-file> <stdin>   (env via $ENV)
  # SC2086: ${ENV:-} is deliberately unquoted so "KEY=val KEY2=val2" splits into
  # separate env assignments; quoting it would pass one bogus assignment.
  # shellcheck disable=SC2086
  printf '%s' "$2" | env ${ENV:-} sh "${HOOKS}/$1" 2>/dev/null
}

ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1" >&2; }

assert_empty()   { [ -z "$2" ] && ok || bad "$1 (expected silent, got: $2)"; }
assert_deny()    { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && ok || bad "$1 (expected deny, got: $2)"; }
assert_no_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && bad "$1 (unexpected deny: $2)" || ok; }
assert_ctx()     { printf '%s' "$2" | grep -q '"additionalContext"' && ok || bad "$1 (expected additionalContext, got: $2)"; }
assert_eq()      { [ "$2" = "$3" ] && ok || bad "$1 (want '$3', got '$2')"; }

new_repo() { _r="${WORK}/$1"; mkdir -p "${_r}"; printf '' > "${_r}/.git"; printf '%s' "${_r}"; }

json_write() {  # <cwd> <session> <file_path> <content>
  printf '{"session_id":"%s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' \
    "$2" "$1" "$3" "$4"
}

. "${HOOKS}/lib/json.sh"
. "${HOOKS}/lib/classify.sh"

# --- extraction (lib/json.sh) ---
E22_INPUT='{"tool_name":"Write","tool_input":{"file_path":"src/a.ts","content":"say \"hi\" and \"file_path\":\"DECOY.ts\""}}'
assert_eq "extract: escaped quotes / decoy file_path" "$(e22_field file_path)" "src/a.ts"

# JSON "a\\nb.ts" decodes to a-backslash-n-b (a literal backslash + 'n'), NOT a
# newline — the escaped-backslash case.
E22_INPUT='{"tool_name":"Write","tool_input":{"file_path":"a\\nb.ts","content":"x"}}'
assert_eq "extract: escaped backslash preserved" "$(e22_field file_path)" 'a\nb.ts'

E22_INPUT='{"tool_name":"Write","tool_input":{"file_path":"real.ts","content":"\"file_path\":\"fake.ts\""}}'
assert_eq "extract: repeated file_path not shadowed" "$(e22_field file_path)" "real.ts"

_p11="$(pin postgres 11)"
E22_INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"x\",\"content\":\"${_p11}\"}}"
assert_eq "extract: Write content" "$(e22_mutation_content)" "${_p11}"

E22_INPUT="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"x\",\"old_string\":\"${_p11}\",\"new_string\":\"$(pin postgres 18)\"}}"
assert_eq "extract: Edit uses new_string" "$(e22_mutation_content)" "$(pin postgres 18)"
printf '%s' "$(e22_mutation_content)" | grep -q "${_p11}" && bad "extract: Edit must not include old_string" || ok

E22_INPUT="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ${_p11}\"}}"
assert_eq "extract: Bash content skipped" "$(e22_mutation_content)" ""

# --- classifier ---
assert_eq "classify ts"         "$(e22_classify_path src/app.ts)"        "implementation"
assert_eq "classify tf"         "$(e22_classify_path infra/main.tf)"     "operations"
assert_eq "classify compose"    "$(e22_classify_path compose.yaml)"      "operations"
assert_eq "classify .env"       "$(e22_classify_path .env)"              "operations"
assert_eq "classify Makefile"   "$(e22_classify_path Makefile)"          "operations"
assert_eq "classify toml"       "$(e22_classify_path mise.toml)"         "operations"
assert_eq "classify Dockerfile" "$(e22_classify_path Dockerfile)"        "operations"
assert_eq "classify md"         "$(e22_classify_path README.md)"         "documentation"
assert_eq "classify lock"       "$(e22_classify_path uv.lock)"           "lockfile"
assert_eq "classify generated"  "$(e22_classify_path dist/app.js)"       "generated"
assert_eq "classify spec"       "$(e22_classify_path spec/features/x/intent.md)" "spec"
assert_eq "classify unknown"    "$(e22_classify_path data.bin)"          "unknown"

# --- check-version-pins.sh (network stubbed) ---
ENV="E22_EOL_FIXTURE_DIR=${EOL}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11)")")"
assert_deny "version-pins: EOL pin denied" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 16)")")"
assert_no_deny "version-pins: supported-behind not denied" "${out}"
assert_ctx     "version-pins: supported-behind advisory"   "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 18)")")"
assert_empty "version-pins: latest silent" "${out}"

out="$(run_hook check-version-pins.sh "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"compose.yaml\",\"old_string\":\"$(pin postgres 11)\",\"new_string\":\"$(pin postgres 18)\"}}")"
assert_empty "version-pins: upgrade edit silent (F13, old value ignored)" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11) # pin-ok: vendor LTS")")"
assert_empty "version-pins: pin-ok bypass" "${out}"

out="$(run_hook check-version-pins.sh "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker run $(pin postgres 11)\"}}")"
assert_empty "version-pins: Bash skipped" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 NOTES.md "we used $(pin postgres 11) once")")"
assert_empty "version-pins: docs exempt" "${out}"

mkdir -p "${WORK}/empty"
out="$(ENV="E22_EOL_FIXTURE_DIR=${WORK}/empty" run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11)")")"
assert_empty "version-pins: offline fails open" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin node 18)")")"
assert_deny "version-pins: node EOL(true) denied" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin redis 7)")")"
assert_no_deny "version-pins: odd-ordering fixture no false-deny" "${out}"

# --- check-code-before-spec.sh (no /spec spine) ---
unset ENV
R1="$(new_repo repoA)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: code write nudges" "${out}"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1}" sA src/other.ts 'y')")"
assert_empty "spec-before-code: one nudge per session+repo" "${out}"

R2="$(new_repo repoB)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R2}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: second repo, same session, nudges" "${out}"

R3="$(new_repo repoC)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R3}" sC compose.yaml 'services: {}')")"
assert_ctx "spec-before-code: operations write nudges" "${out}"

R4="$(new_repo repoD)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R4}" sD README.md '# hi')")"
assert_empty "spec-before-code: docs exempt" "${out}"

R5="$(new_repo repoE)" ; mkdir -p "${R5}/spec"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R5}" sE src/app.ts 'x')")"
assert_empty "spec-before-code: spine present -> silent" "${out}"

R6="${WORK}/repoWT" ; mkdir -p "${R6}" ; printf 'gitdir: /elsewhere\n' > "${R6}/.git"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R6}" sWT src/app.ts 'x')")"
assert_ctx "spec-before-code: .git-as-file worktree engages" "${out}"

R7="$(new_repo repoSpace)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R7}" sSp 'src/my file.ts' 'x')")"
assert_ctx "spec-before-code: path with spaces" "${out}"

# --- check-issue-before-mutation.sh (GitHub tracker) ---
R8="$(new_repo repoGH)" ; mkdir -p "${R8}/spec" ; printf 'system: github\n' > "${R8}/spec/tracker.md"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R8}" sGH src/app.ts 'x')")"
assert_ctx "issue-first: github repo code write nudges" "${out}"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R8}" sGH src/two.ts 'x')")"
assert_empty "issue-first: one nudge per session+repo" "${out}"

R9="$(new_repo repoJira)" ; mkdir -p "${R9}/spec" ; printf 'system: jira\n' > "${R9}/spec/tracker.md"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R9}" sJ src/app.ts 'x')")"
assert_empty "issue-first: non-github tracker silent" "${out}"

R10="$(new_repo repoNoTracker)" ; mkdir -p "${R10}/spec"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R10}" sN src/app.ts 'x')")"
assert_empty "issue-first: no tracker silent" "${out}"

printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
