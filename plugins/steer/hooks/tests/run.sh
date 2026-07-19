#!/usr/bin/env sh
# steer hook fixture suite — POSIX sh. Version-pin checks are
# deterministic against the bundled policy/versions.yml (no network, no jq).
# Feeds canned PreToolUse JSON on stdin and asserts the hook's decision
# (deny / silent allow) plus the field-extraction
# and classification behaviour. Run from anywhere:
#
#     sh plugins/steer/hooks/tests/run.sh
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
# SC2034 — STEER_INPUT is read by the sourced lib/json.sh functions (which ShellCheck
#          does not follow), so it reads as "unused" here though it is the input.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN="$(CDPATH='' cd -- "${HERE}/../.." && pwd)"
HOOKS="${PLUGIN}/hooks"
export CLAUDE_PLUGIN_ROOT="${PLUGIN}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/steer-hooktests.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
# run_hook records the invoked hook's exit code here so assert_empty can require a
# clean (rc 0) silent-allow — a hook that crashes before printing must NOT pass as
# "silent". Written inside run_hook's command-substitution subshell (a file, so it
# survives the subshell); read via last_rc.
RC_FILE="${WORK}/.last_hook_rc"
PASS=0
FAIL=0

pin() { printf '%s:%s' "$1" "$2"; } # pin postgres 11 -> the matchable token

run_hook() { # <hook-file> <stdin>   (env via $ENV)
	# SC2086: ${ENV:-} is deliberately unquoted so "KEY=val KEY2=val2" splits into
	# separate env assignments; quoting it would pass one bogus assignment.
	# shellcheck disable=SC2086
	printf '%s' "$2" | env ${ENV:-} sh "${HOOKS}/$1" 2>/dev/null
	# Record the hook's exit code (pipeline rc = the sourced hook's rc) so callers
	# can assert a clean silent-allow, not just empty stdout.
	printf '%s' "$?" >"${RC_FILE}"
}

last_rc() { cat "${RC_FILE}" 2>/dev/null || printf '0'; }

# Direct-sh runner for the non-hook helper scripts (template-reconcile /
# scan-capabilities / scan-invocations / …). Sets `out` + `rc` AND records rc to
# RC_FILE — so assert_empty's rc half asserts THIS invocation, not a stale rc
# left by an earlier run_hook (issue #338).
run_sh() { # <script> [args...]
	out="$(sh "$@" 2>/dev/null)"
	rc=$?
	printf '%s' "${rc}" >"${RC_FILE}"
}

ok() { PASS=$((PASS + 1)); }
bad() {
	FAIL=$((FAIL + 1))
	printf 'FAIL: %s\n' "$1" >&2
}

assert_empty() {
	_ae_rc="$(last_rc)"
	{ [ -z "$2" ] && [ "${_ae_rc}" -eq 0 ]; } && ok ||
		bad "$1 (expected silent + rc 0, got: '$2' rc=${_ae_rc})"
}
assert_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && ok || bad "$1 (expected deny, got: $2)"; }
assert_no_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && bad "$1 (unexpected deny: $2)" || ok; }
# Claude PreToolUse "ask" envelope: the decision wrapped in hookSpecificOutput.
assert_ask() {
	printf '%s' "$2" | grep -q '"permissionDecision":"ask"' &&
		printf '%s' "$2" | grep -q 'hookSpecificOutput' && ok ||
		bad "$1 (expected wrapped ask, got: $2)"
}
# Copilot preToolUse envelope: a flat decision object (no hookSpecificOutput wrapper).
assert_copilot_ask() {
	printf '%s' "$2" | grep -q '"permissionDecision":"ask"' &&
		! printf '%s' "$2" | grep -q 'hookSpecificOutput' && ok ||
		bad "$1 (expected flat copilot ask, got: $2)"
}
assert_ctx() { printf '%s' "$2" | grep -q '"additionalContext"' && ok || bad "$1 (expected additionalContext, got: $2)"; }
# SessionStart raw-text hooks print directly to stdout (the runtime wraps it as
# additionalContext); assert the emitted text contains a marker substring.
assert_has() { printf '%s' "$2" | grep -q -- "$3" && ok || bad "$1 (expected to contain '$3', got: $2)"; }
assert_block() { printf '%s' "$2" | grep -q '"decision":"block"' && ok || bad "$1 (expected block, got: $2)"; }
assert_no_block() { printf '%s' "$2" | grep -q '"decision":"block"' && bad "$1 (unexpected block: $2)" || ok; }
assert_eq() { [ "$2" = "$3" ] && ok || bad "$1 (want '$3', got '$2')"; }
assert_rc() { [ "$2" -eq "$3" ] && ok || bad "$1 (want rc $3, got $2)"; }

new_repo() {
	_r="${WORK}/$1"
	mkdir -p "${_r}"
	printf '' >"${_r}/.git"
	printf '%s' "${_r}"
}

# Real git repo on a named branch, with a GitHub tracker, for the Stop hook.
git_repo() { # <name> <branch>  -> prints repo path
	_r="${WORK}/$1"
	mkdir -p "${_r}"
	(cd "${_r}" &&
		git init -q &&
		git config user.email t@e.com &&
		git config user.name t &&
		git commit -q --allow-empty -m init &&
		git checkout -q -B "$2") >/dev/null 2>&1
	mkdir -p "${_r}/spec"
	printf 'system: github\n' >"${_r}/spec/tracker.md"
	printf '%s' "${_r}"
}

json_write() { # <cwd> <session> <file_path> <content>
	printf '{"session_id":"%s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' \
		"$2" "$1" "$3" "$4"
}

stop_json() { # <cwd> <session> [stop_hook_active=false]
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop","stop_hook_active":%s}' \
		"$2" "$1" "${3:-false}"
}

session_json() { # <cwd> <session>
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart"}' "$2" "$1"
}

# Write a product CLAUDE.md carrying the machine-readable delivery-mode marker,
# plus prose that names BOTH modes — so the tests prove the matcher is anchored to
# the marker line and never matches the explanatory prose word "solo trunk".
claude_md_mode() { # <repo_root> <solo-trunk|pr-flow>
	printf '## Delivery mode\n\n<!-- steer:delivery-mode=%s -->\n\nProse names solo trunk (pre-MVP) and PR flow both.\n' "$2" >"$1/CLAUDE.md"
}

json_notebook() { # <cwd> <session> <notebook_path>
	printf '{"session_id":"%s","cwd":"%s","tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s","new_source":"x"}}' \
		"$2" "$1" "$3"
}

managed_spine() { # <repo_root>  -> stamp a complete, version-stamped spec spine
	mkdir -p "$1/spec"
	printf '1.0.0\n' >"$1/spec/.version"
	for _sf in vision.md users.md glossary.md tracker.md HISTORY.md; do
		printf 'x\n' >"$1/spec/${_sf}"
	done
}

# Fully bootstrapped state (managed spine + declared tracker + root mise.toml)
# so the merged write hook's spec/scaffold dimension stays silent and a test
# isolates the issue-first dimension. Tracker system defaults to github.
bootstrapped_repo() { # <repo_root> [tracker-system]
	managed_spine "$1"
	printf 'system: %s\n' "${2:-github}" >"$1/spec/tracker.md"
	: >"$1/mise.toml"
}

. "${HOOKS}/lib/json.sh"
. "${HOOKS}/lib/classify.sh"
. "${HOOKS}/lib/report-fault.sh"

# --- extraction (lib/json.sh) ---
# Force the no-jq fallback for this whole block: CI/dev usually HAS jq, so without
# this override the hand-rolled grep/sed extractor (the fragile path these cases
# exist to pin) would ship untested. The real steer_have_jq is restored after.
steer_have_jq() { return 1; }
STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"src/a.ts","content":"say \"hi\" and \"file_path\":\"DECOY.ts\""}}'
assert_eq "extract: escaped quotes / decoy file_path" "$(steer_field file_path)" "src/a.ts"

# JSON "a\\nb.ts" decodes to a-backslash-n-b (a literal backslash + 'n'), NOT a
# newline — the escaped-backslash case.
STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"a\\nb.ts","content":"x"}}'
assert_eq "extract: escaped backslash preserved" "$(steer_field file_path)" 'a\nb.ts'

STEER_INPUT='{"tool_name":"Write","tool_input":{"file_path":"real.ts","content":"\"file_path\":\"fake.ts\""}}'
assert_eq "extract: repeated file_path not shadowed" "$(steer_field file_path)" "real.ts"

# A top-level decoy of the same name, BEFORE tool_input, must not win — the no-jq
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

# --- classifier ---
assert_eq "classify ts" "$(steer_classify_path src/app.ts)" "implementation"
assert_eq "classify tf" "$(steer_classify_path infra/main.tf)" "operations"
assert_eq "classify compose" "$(steer_classify_path compose.yaml)" "operations"
assert_eq "classify .env" "$(steer_classify_path .env)" "operations"
assert_eq "classify Makefile" "$(steer_classify_path Makefile)" "operations"
assert_eq "classify toml" "$(steer_classify_path mise.toml)" "operations"
assert_eq "classify Dockerfile" "$(steer_classify_path Dockerfile)" "operations"
assert_eq "classify md" "$(steer_classify_path README.md)" "documentation"
assert_eq "classify lock" "$(steer_classify_path uv.lock)" "lockfile"
assert_eq "classify generated" "$(steer_classify_path dist/app.js)" "generated"
assert_eq "classify spec" "$(steer_classify_path spec/features/x/intent.md)" "spec"
assert_eq "classify unknown" "$(steer_classify_path data.bin)" "unknown"

# --- check-version-pins.sh (deterministic, policy-driven; uses the bundled
#     policy/versions.yml via CLAUDE_PLUGIN_ROOT — no network, no jq) ---

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11)")")"
assert_deny "version-pins: denied major denied" "${out}"

# Floor-only policy: a supported-but-older major (≥ minimum_supported, not denied)
# is silent — there is no advisory "behind the target" tier.
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 16)")")"
assert_no_deny "version-pins: above-floor not denied" "${out}"
assert_empty "version-pins: above-floor silent (no advisory tier)" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 18)")")"
assert_empty "version-pins: above-floor major silent" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin python 3.9)")")"
assert_deny "version-pins: below minimum_supported denied (python 3.9)" "${out}"

out="$(run_hook check-version-pins.sh "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"compose.yaml\",\"old_string\":\"$(pin postgres 11)\",\"new_string\":\"$(pin postgres 18)\"}}")"
assert_empty "version-pins: upgrade edit silent (F13, old value ignored)" "${out}"

# Copilot target (STEER_HOOK_TARGET=copilot): same detection, but a flat
# permissionDecision envelope with "ask" instead of the Claude deny wrapper.
out="$(ENV="STEER_HOOK_TARGET=copilot" run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11)")")"
assert_copilot_ask "version-pins: copilot target emits flat ask, not deny" "${out}"

# Copilot target on a clean pin stays silent (no spurious ask).
out="$(ENV="STEER_HOOK_TARGET=copilot" run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 16)")")"
assert_empty "version-pins: copilot target silent on supported pin" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11) # steer:allow-pin vendor LTS")")"
assert_empty "version-pins: steer:allow-pin bypass" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11) # pin-ok: legacy alias")")"
assert_empty "version-pins: legacy pin-ok bypass" "${out}"

# Regression: a three-segment pin (extracted at major.minor) must still honor a
# same-line marker — the boundary class excludes only digits, not the dot.
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11).2.1 # steer:allow-pin three-segment")")"
assert_empty "version-pins: steer:allow-pin bypass honors 3-segment pin" "${out}"

out="$(run_hook check-version-pins.sh "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker run $(pin postgres 11)\"}}")"
assert_empty "version-pins: Bash skipped (CI scanner is the backstop)" "${out}"

# NotebookEdit new_source is inspected like any write — a denied pin in a notebook
# cell is caught, not silently passed (issue #271: NotebookEdit was a dead matcher).
out="$(run_hook check-version-pins.sh "{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"a.ipynb\",\"new_source\":\"image: $(pin postgres 11)\"}}")"
assert_deny "version-pins: NotebookEdit new_source denied pin caught" "${out}"

# A steer:allow-pin justification on a DIFFERENT line must NOT suppress a deny for a
# pin elsewhere — the same-line discipline only holds if multi-line content survives
# unescaping (issue #271). '\n' in the JSON value is a real newline in the content.
out="$(run_hook check-version-pins.sh "$(json_write /tmp sML compose.yaml "image: $(pin postgres 11)\nother: fine # steer:allow-pin unrelated")")"
assert_deny "version-pins: allow-pin on a different line does not suppress deny" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 NOTES.md "we used $(pin postgres 11) once")")"
assert_empty "version-pins: docs exempt" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin node 18)")")"
assert_deny "version-pins: node denied major denied" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin redis 7)")")"
assert_no_deny "version-pins: at floor (redis 7) not denied" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: foo:1")")"
assert_empty "version-pins: unknown product not enforced" "${out}"

# Repo-local policy/versions.yml overrides the bundled default.
RP="$(new_repo repoPolicy)"
mkdir -p "${RP}/policy"
printf 'schema: 1\nproducts:\n  postgres:\n    minimum_supported: "20"\n    denied: []\n' >"${RP}/policy/versions.yml"
out="$(run_hook check-version-pins.sh "$(json_write "${RP}" sP compose.yaml "image: $(pin postgres 17)")")"
assert_deny "version-pins: repo-local policy enforced (pg17 below local min 20)" "${out}"
# The same repo-local policy is honored when editing from a SUBDIR — the hook
# resolves the work-tree root before reading policy/versions.yml (#277 item 4). A
# subdir with no policy/ would otherwise fall through to the laxer bundled default.
mkdir -p "${RP}/apps/web"
out="$(run_hook check-version-pins.sh "$(json_write "${RP}/apps/web" sPsub compose.yaml "image: $(pin postgres 17)")")"
assert_deny "version-pins: repo-local policy enforced from a subdir" "${out}"
# Escaping the pin's dot (#277 item 5) must not break allow-pin marker matching on
# a legitimately-marked dotted pin.
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin python 3.9) # steer:allow-pin vendor LTS")")"
assert_empty "version-pins: dotted pin still honors its own allow-pin marker" "${out}"

# --- spec/scaffold dimension of check-write-nudges.sh (no /spec spine) ---
# Two dimensions (issue #171): the /spec SPINE nudge fires once per session+repo;
# the SCAFFOLD nudge is sticky — it re-fires on each NEW feature file while the
# repo has no root mise.toml, and self-clears the moment a mise.toml exists.
unset ENV
R1="$(new_repo repoA)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R1}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: first code write nudges" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "spec-before-code: first write carries scaffold clause (${out})"
printf '%s' "${out}" | grep -q 'Spec-first check' && ok || bad "spec-before-code: first write carries spine clause (${out})"

# Second DISTINCT file, same session+repo, still no mise.toml: spine fired once
# already, but the SCAFFOLD nudge re-fires — and ONLY the scaffold clause.
out="$(run_hook check-write-nudges.sh "$(json_write "${R1}" sA src/other.ts 'y')")"
assert_ctx "spec-before-code: new file re-fires scaffold nudge" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "spec-before-code: re-fire carries scaffold clause (${out})"
printf '%s' "${out}" | grep -q 'Spec-first check' && bad "spec-before-code: spine clause must NOT repeat (${out})" || ok

# SAME file written again → no dimension due → silent (scaffold dedup, never nag).
out="$(run_hook check-write-nudges.sh "$(json_write "${R1}" sA src/other.ts 'y2')")"
assert_empty "spec-before-code: same file again is silent (scaffold dedup)" "${out}"

# Root mise.toml present (scaffold landed) but no spine: the SPINE nudge fires
# once, the SCAFFOLD dimension stays silent — proving the sticky nudge self-clears.
R1b="$(new_repo repoAmise)"
printf '[tools]\n' >"${R1b}/mise.toml"
out="$(run_hook check-write-nudges.sh "$(json_write "${R1b}" sAm src/app.ts 'x')")"
assert_ctx "spec-before-code: scaffold present still nudges spine" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && bad "spec-before-code: no scaffold clause once mise.toml present (${out})" || ok
out="$(run_hook check-write-nudges.sh "$(json_write "${R1b}" sAm src/other.ts 'y')")"
assert_empty "spec-before-code: scaffold present + spine fired -> later files silent" "${out}"

# Writing mise.toml IS the act of scaffolding — never scaffold-nudge that write.
R1c="$(new_repo repoAmk)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R1c}" sMk src/app.ts 'x')")"
assert_ctx "spec-before-code: prime spine nudge before mise.toml write" "${out}"
out="$(run_hook check-write-nudges.sh "$(json_write "${R1c}" sMk mise.toml '[tools]')")"
assert_empty "spec-before-code: writing mise.toml is not scaffold-nudged" "${out}"

R2="$(new_repo repoB)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R2}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: second repo, same session, nudges" "${out}"

R3="$(new_repo repoC)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R3}" sC compose.yaml 'services: {}')")"
assert_ctx "spec-before-code: operations write nudges" "${out}"

R4="$(new_repo repoD)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R4}" sD README.md '# hi')")"
assert_empty "spec-before-code: docs exempt" "${out}"

# Bare spec/ (no .version) is NOT a managed spine — must still nudge (foreign),
# per the spec/.version predicate. An empty/foreign/partial spec/ no longer
# silences the spec-first nudge.
R5="$(new_repo repoE)"
mkdir -p "${R5}/spec"
out="$(run_hook check-write-nudges.sh "$(json_write "${R5}" sE src/app.ts 'x')")"
assert_ctx "spec-before-code: bare spec/ without .version still nudges" "${out}"

# Complete, version-stamped spine -> managed -> silent.
R5b="$(new_repo repoEok)"
managed_spine "${R5b}"
out="$(run_hook check-write-nudges.sh "$(json_write "${R5b}" sEok src/app.ts 'x')")"
assert_empty "spec-before-code: complete .version spine -> silent" "${out}"

# .version present but a spine file missing -> damaged -> nudge.
R5c="$(new_repo repoEdmg)"
mkdir -p "${R5c}/spec"
printf '1.0.0\n' >"${R5c}/spec/.version"
printf 'x\n' >"${R5c}/spec/vision.md"
out="$(run_hook check-write-nudges.sh "$(json_write "${R5c}" sEdmg src/app.ts 'x')")"
assert_ctx "spec-before-code: damaged spine (missing files) nudges" "${out}"

# NotebookEdit (notebook_path) is governed like an ordinary code write.
R5n="$(new_repo repoEnb)"
out="$(run_hook check-write-nudges.sh "$(json_notebook "${R5n}" sEnb analysis.ipynb)")"
assert_ctx "spec-before-code: NotebookEdit write nudges" "${out}"

# Invocation from a SUBDIRECTORY resolves the repo root (cwd may be apps/web).
R5s="$(new_repo repoEsub)"
mkdir -p "${R5s}/apps/web/src"
out="$(run_hook check-write-nudges.sh "$(json_write "${R5s}/apps/web" sEsub src/app.ts 'x')")"
assert_ctx "spec-before-code: subdir cwd resolves root and nudges" "${out}"

R6="${WORK}/repoWT"
mkdir -p "${R6}"
printf 'gitdir: /elsewhere\n' >"${R6}/.git"
out="$(run_hook check-write-nudges.sh "$(json_write "${R6}" sWT src/app.ts 'x')")"
assert_ctx "spec-before-code: .git-as-file worktree engages" "${out}"

R7="$(new_repo repoSpace)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R7}" sSp 'src/my file.ts' 'x')")"
assert_ctx "spec-before-code: path with spaces" "${out}"

# --- issue-first dimension of check-write-nudges.sh (GitHub tracker).
#     Fixtures are bootstrapped (bootstrapped_repo) so the spec/scaffold dimension
#     stays silent and these cases isolate issue-first. ---
R8="$(new_repo repoGH)"
bootstrapped_repo "${R8}"
out="$(run_hook check-write-nudges.sh "$(json_write "${R8}" sGH src/app.ts 'x')")"
assert_ctx "issue-first: github repo code write nudges" "${out}"
out="$(run_hook check-write-nudges.sh "$(json_write "${R8}" sGH src/two.ts 'x')")"
assert_empty "issue-first: one nudge per session+repo" "${out}"
# Control chars in a path must not break the JSON envelope (#277 item 6): a newline
# in file_path is flattened to a space in the emitted nudge (fresh session so the
# once-per-session marker doesn't suppress it). The flattened "src/a b.ts" only
# appears if the sanitizer stripped the newline.
out="$(run_hook check-write-nudges.sh '{"session_id":"sNL","cwd":"'"${R8}"'","tool_name":"Write","tool_input":{"file_path":"src/a\nb.ts","content":"x"}}')"
assert_ctx "issue-first: control-char path still nudges" "${out}"
printf '%s' "${out}" | grep -q 'src/a b.ts' && ok ||
	bad "issue-first: newline in path flattened to a space (got: ${out})"

R9="$(new_repo repoJira)"
bootstrapped_repo "${R9}" jira
out="$(run_hook check-write-nudges.sh "$(json_write "${R9}" sJ src/app.ts 'x')")"
assert_empty "issue-first: non-github tracker silent" "${out}"

# No tracker.md at all: the issue-first dimension stays silent. (The spine
# dimension legitimately reports the incomplete spec/ here — that is nudge 1's
# job — so assert the absence of the issue nudge, not total silence.)
R10="$(new_repo repoNoTracker)"
mkdir -p "${R10}/spec"
out="$(run_hook check-write-nudges.sh "$(json_write "${R10}" sN src/app.ts 'x')")"
printf '%s' "${out}" | grep -q 'Issue-first' && bad "issue-first: no tracker must not issue-nudge (got: ${out})" || ok

# Solo-trunk mode: issue-first still nudges, but with trunk wording (no /steer:work,
# no issue branch — close the issue from the commit instead).
R8st="$(new_repo repoGHsolo)"
bootstrapped_repo "${R8st}"
claude_md_mode "${R8st}" solo-trunk
out="$(run_hook check-write-nudges.sh "$(json_write "${R8st}" sGHst src/app.ts 'x')")"
assert_ctx "issue-first: solo-trunk repo still nudges" "${out}"
printf '%s' "${out}" | grep -q 'solo-trunk mode' && ok || bad "issue-first: solo-trunk wording present (got: ${out})"
printf '%s' "${out}" | grep -q '/steer:work' && bad "issue-first: solo-trunk must NOT mention /steer:work (got: ${out})" || ok

# PR-flow repo whose CLAUDE.md prose names "solo trunk" still gets PR-flow wording
# — proves the marker matcher is anchored, not a substring of the prose.
R8pf="$(new_repo repoGHpr)"
bootstrapped_repo "${R8pf}"
claude_md_mode "${R8pf}" pr-flow
out="$(run_hook check-write-nudges.sh "$(json_write "${R8pf}" sGHpf src/app.ts 'x')")"
assert_ctx "issue-first: pr-flow repo nudges (prose mentions solo trunk)" "${out}"
printf '%s' "${out}" | grep -q '/steer:work' && ok || bad "issue-first: pr-flow keeps /steer:work (got: ${out})"
printf '%s' "${out}" | grep -q 'solo-trunk mode' && bad "issue-first: pr-flow must NOT use solo wording (got: ${out})" || ok

# Plugin-maintenance branch exemption (needs a real git repo for branch detection).
# /steer:sync writes operations-class scaffold on its own feat/sync branch ->
# silent (rule 36 carve-out); app source on feat/sync still nudges.
if command -v git >/dev/null 2>&1; then
	RSY="$(git_repo repoSyncPre feat/sync)"
	bootstrapped_repo "${RSY}"
	out="$(run_hook check-write-nudges.sh "$(json_write "${RSY}" sSY1 compose.yaml 'x')")"
	assert_empty "issue-first: feat/sync operations write exempt" "${out}"
	out="$(run_hook check-write-nudges.sh "$(json_write "${RSY}" sSY2 src/app.ts 'x')")"
	assert_ctx "issue-first: feat/sync app source still nudges" "${out}"

	# Hotfix fast-path exemption (rule 62): app source on a hotfix/<n> branch is the
	# sanctioned after-the-fact lane -> silent at the point of action (the issue is
	# filed in the post-incident follow-up).
	RHF="$(git_repo repoHotfixPre hotfix/42-outage)"
	bootstrapped_repo "${RHF}"
	out="$(run_hook check-write-nudges.sh "$(json_write "${RHF}" sHF1 src/app.ts 'x')")"
	assert_empty "issue-first: hotfix branch app source exempt" "${out}"
fi

# --- issue-create contract guard of check-bash-actions.sh (GitHub tracker) ---
# Builds Bash / MCP PreToolUse inputs. The command body is a JSON string, so any
# double quotes inside the gh command are escaped to \" by the helper.
bash_json() { # <cwd> <session> <command>
	_cmd="$(printf '%s' "$3" | sed 's/\\/\\\\/g; s/"/\\"/g')"
	printf '{"session_id":"%s","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' \
		"$2" "$1" "${_cmd}"
}
mcp_json() { # <cwd> <session> <tool_name> <body>
	printf '{"session_id":"%s","cwd":"%s","tool_name":"%s","tool_input":{"title":"x","body":"%s"}}' \
		"$2" "$1" "$3" "$4"
}

RC8="$(new_repo repoCreateGH)"
mkdir -p "${RC8}/spec"
printf 'system: github\n' >"${RC8}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC1 'gh issue create --title x --body y')")"
assert_ctx "issue-create: gh issue create nudges" "${out}"
printf '%s' "${out}" | grep -q '/steer:tracker-sync create' && ok || bad "issue-create: nudge points at tracker-sync (got: ${out})"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC1 'gh issue create --title z')")"
assert_empty "issue-create: one nudge per session+repo" "${out}"

# gh api REST POST to .../issues (creation) nudges; a POST to .../issues/<n>/...
# (comment / sub-resource) does not.
RC8b="$(new_repo repoCreateApi)"
mkdir -p "${RC8b}/spec"
printf 'system: github\n' >"${RC8b}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8b}" sC2 'gh api repos/o/r/issues -f title=x -f body=y')")"
assert_ctx "issue-create: gh api POST /issues nudges" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8b}" sC2b 'gh api repos/o/r/issues/123/comments -f body=hi')")"
assert_empty "issue-create: gh api comment on /issues/<n> silent" "${out}"

# GraphQL createIssue mutation nudges.
RC8c="$(new_repo repoCreateGql)"
mkdir -p "${RC8c}/spec"
printf 'system: github\n' >"${RC8c}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8c}" sC3 'gh api graphql -f query=mutation{createIssue(input:{}){issue{number}}}')")"
assert_ctx "issue-create: graphql createIssue nudges" "${out}"

# A create whose payload ALREADY carries steer markers is the /steer:tracker-sync
# render path — stay silent (contract is being applied, not bypassed).
RC8d="$(new_repo repoCreateContractful)"
mkdir -p "${RC8d}/spec"
printf 'system: github\n' >"${RC8d}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8d}" sC4 'gh issue create --body <!-- steer:kind=task -->')")"
assert_empty "issue-create: payload with steer markers silent" "${out}"

# A /steer:report self-report files UPSTREAM to element22llc/e22-plugins, never the
# product tracker. The guard must stay silent even on the label-less fallback
# create, which carries no `steer:` marker — routing it through tracker-sync would
# target the wrong repo.
RC8f="$(new_repo repoSelfReport)"
mkdir -p "${RC8f}/spec"
printf 'system: github\n' >"${RC8f}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8f}" sC4b 'gh issue create --repo element22llc/e22-plugins --title "[steer] x" --label bug --body-file /tmp/b')")"
assert_empty "issue-create: steer self-report upstream create stays silent" "${out}"

# gh's documented `-R` alias for `--repo` is the same self-report create and must
# be exempt too (#339) — pre-fix it got a false-positive nudge at the wrong repo.
RC8h="$(new_repo repoSelfReportR)"
mkdir -p "${RC8h}/spec"
printf 'system: github\n' >"${RC8h}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8h}" sC4c 'gh issue create -R element22llc/e22-plugins --title "[steer] x" --body-file /tmp/b')")"
assert_empty "issue-create: steer self-report via -R alias stays silent" "${out}"

# The self-report guard matches the --repo FLAG, not a bare mention: a legitimate
# PRODUCT create whose body merely references the plugin repo must STILL be nudged
# (routed through /steer:tracker-sync), not silently suppressed.
RC8g="$(new_repo repoProdMention)"
mkdir -p "${RC8g}/spec"
printf 'system: github\n' >"${RC8g}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8g}" sC4d 'gh issue create --title bump --body "see element22llc/e22-plugins#123"')")"
assert_ctx "issue-create: product create only mentioning plugin repo still nudges" "${out}"

# MCP create-issue tool nudges; an MCP comment/list tool whose name merely
# contains "issue" does not.
RC8e="$(new_repo repoCreateMcp)"
mkdir -p "${RC8e}/spec"
printf 'system: github\n' >"${RC8e}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5 mcp__github__create_issue y)")"
assert_ctx "issue-create: MCP create_issue nudges" "${out}"
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5b mcp__github__add_issue_comment y)")"
assert_empty "issue-create: MCP add_issue_comment silent" "${out}"
# The hosted GitHub MCP server renamed create_issue -> issue_write; the guard must
# fire on the current write path (#264). Distinct session ids so the once-per-repo
# marker set by earlier cases does not suppress these.
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5c mcp__github__issue_write y)")"
assert_ctx "issue-create: MCP issue_write nudges (renamed create tool)" "${out}"
# sub_issue_write links a relationship to an EXISTING issue (no body) — not a create.
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5d mcp__github__sub_issue_write y)")"
assert_empty "issue-create: MCP sub_issue_write silent (relationship, not create)" "${out}"

# Non-create Bash, non-GitHub tracker, and no-tracker repos are all silent.
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC6 'gh issue list --json number')")"
assert_empty "issue-create: gh issue list silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC7 'ls -la')")"
assert_empty "issue-create: plain bash silent" "${out}"
RC9="$(new_repo repoCreateJira)"
mkdir -p "${RC9}/spec"
printf 'system: jira\n' >"${RC9}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC9}" sC8 'gh issue create --title x')")"
assert_empty "issue-create: non-github tracker silent" "${out}"
RC10="$(new_repo repoCreateNoTracker)"
mkdir -p "${RC10}/spec"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC10}" sC9 'gh issue create --title x')")"
assert_empty "issue-create: no tracker silent" "${out}"
# A Bash call whose command TEXT embeds a create_issue tool_name must NOT be misread
# as an MCP create: steer_tool reads the top-level .tool_name ("Bash"), not the
# tool_input slice steer_field would search (#277 item 3). Without the fix this
# writes-a-fixture command spuriously nudges.
embed_cmd='printf "%s" "{\"tool_name\":\"mcp__github__create_issue\"}" > fx.json'
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC10 "${embed_cmd}")")"
assert_empty "issue-create: Bash cmd embedding a create_issue tool_name stays silent" "${out}"

# --- reconcile-issue-first.sh (Stop hook, real git working tree) ---
if command -v git >/dev/null 2>&1; then
	# D: Bash-mediated source change on a number-free branch (main) -> reported.
	S1="$(git_repo stopMain main)"
	mkdir -p "${S1}/src"
	printf 'export const x = 1\n' >"${S1}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S1}" stS1)")"
	assert_block "stop-reconcile: governed change on main reported" "${out}"
	# fires at most once per session+repo (marker set by the call above)
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S1}" stS1)")"
	assert_no_block "stop-reconcile: silent on second Stop (once per session)" "${out}"

	# E: same change on an issue-referenced branch -> already governed, silent.
	S2="$(git_repo stopIssue issue/123-example)"
	mkdir -p "${S2}/src"
	printf 'export const x = 1\n' >"${S2}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S2}" stS2)")"
	assert_no_block "stop-reconcile: issue branch silent" "${out}"

	# F: exempt-only changes (spec + docs) -> silent.
	S3="$(git_repo stopExempt main)"
	printf '# notes\n' >"${S3}/README.md"
	mkdir -p "${S3}/spec/features/example"
	printf '# intent\n' >"${S3}/spec/features/example/intent.md"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S3}" stS3)")"
	assert_no_block "stop-reconcile: exempt-only changes silent" "${out}"

	# Loop guard: stop_hook_active=true never blocks, even with a governed change.
	S4="$(git_repo stopLoop main)"
	mkdir -p "${S4}/src"
	printf 'x\n' >"${S4}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S4}" stS4 true)")"
	assert_no_block "stop-reconcile: stop_hook_active=true never blocks (loop guard)" "${out}"

	# Non-GitHub tracker -> out of scope, silent.
	S5="$(git_repo stopJira main)"
	printf 'system: jira\n' >"${S5}/spec/tracker.md"
	mkdir -p "${S5}/src"
	printf 'x\n' >"${S5}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S5}" stS5)")"
	assert_no_block "stop-reconcile: non-github tracker silent" "${out}"

	# Clean working tree -> nothing to reconcile, silent.
	S6="$(git_repo stopClean main)"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S6}" stS6)")"
	assert_no_block "stop-reconcile: clean tree silent" "${out}"

	# G: a date branch (release/2026-06) is NOT issue-governed -> reported. The old
	# broad regex wrongly treated any embedded number as an issue ref.
	S7="$(git_repo stopRelease main)"
	git -C "${S7}" checkout -q -b release/2026-06
	mkdir -p "${S7}/src"
	printf 'x\n' >"${S7}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S7}" stS7)")"
	assert_block "stop-reconcile: date branch release/2026-06 reported (not issue-governed)" "${out}"

	# H: marker-first — a non-issue branch with a spec/.work/<branch> marker is
	# governed via the marker even though its name carries no issue number.
	S8="$(git_repo stopMarker main)"
	git -C "${S8}" checkout -q -b prototype-x
	mkdir -p "${S8}/spec/.work"
	: >"${S8}/spec/.work/prototype-x"
	mkdir -p "${S8}/src"
	printf 'x\n' >"${S8}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S8}" stS8)")"
	assert_no_block "stop-reconcile: spec/.work marker governs non-issue branch" "${out}"

	# I: .md marker governs via slash→underscore key AND the current session is
	# stamped at the head of the session list, preserving the issue:/branch: header
	# and the prior session id.
	S9="$(git_repo stopMdMarker main)"
	git -C "${S9}" checkout -q -b proto/x
	mkdir -p "${S9}/spec/.work"
	MD9="${S9}/spec/.work/proto_x.md"
	printf '# Work marker — issue 123\n\n- issue: 123\n- branch: proto/x\n\n## Claude Code sessions (newest first)\n\n- sess-old-0002\n' >"${MD9}"
	mkdir -p "${S9}/src"
	printf 'x\n' >"${S9}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S9}" sess-new-0001)")"
	assert_no_block "stop-reconcile: .md marker governs (slash→underscore key)" "${out}"
	hsess9="$(awk '/^## Claude Code sessions/{f=1;next} f&&/^-[[:space:]]/{s=$0;sub(/^-[[:space:]]+/,"",s);sub(/[[:space:]].*$/,"",s);print s;exit}' "${MD9}")"
	assert_eq "stop-reconcile: current session stamped at head of .md marker" "${hsess9}" "sess-new-0001"
	grep -q '^- issue: 123$' "${MD9}" && ok || bad "stop-reconcile: .md marker issue: line preserved"
	grep -q '^- branch: proto/x$' "${MD9}" && ok || bad "stop-reconcile: .md marker branch: line preserved"
	grep -q '^- sess-old-0002$' "${MD9}" && ok || bad "stop-reconcile: prior session retained in .md marker"

	# J: re-stamping the same session is a byte-for-byte no-op (head unchanged).
	cp "${MD9}" "${MD9}.before"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S9}" sess-new-0001)")"
	assert_no_block "stop-reconcile: re-stamp same session stays silent" "${out}"
	cmp -s "${MD9}" "${MD9}.before" && ok || bad "stop-reconcile: re-stamp same session is a no-op"

	# K: an empty session id (fail-open) leaves the .md marker untouched but still
	# governs the branch (no block).
	S10="$(git_repo stopMdEmptySid main)"
	git -C "${S10}" checkout -q -b proto2/x
	mkdir -p "${S10}/spec/.work"
	MD10="${S10}/spec/.work/proto2_x.md"
	printf '# Work marker — issue 7\n\n- issue: 7\n- branch: proto2/x\n\n## Claude Code sessions (newest first)\n\n- sess-old-0003\n' >"${MD10}"
	cp "${MD10}" "${MD10}.before"
	mkdir -p "${S10}/src"
	printf 'x\n' >"${S10}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S10}" '')")"
	assert_no_block "stop-reconcile: .md marker governs with empty session id" "${out}"
	cmp -s "${MD10}" "${MD10}.before" && ok || bad "stop-reconcile: empty session id leaves .md marker intact"

	# L: solo-trunk mode — a governed change on main is STILL surfaced (issue-first
	# holds), but with trunk wording: reference the issue in the commit, no /steer:work.
	S11="$(git_repo stopSolo main)"
	claude_md_mode "${S11}" solo-trunk
	mkdir -p "${S11}/src"
	printf 'export const x = 1\n' >"${S11}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S11}" stS11)")"
	assert_block "stop-reconcile: solo-trunk governed change on main still surfaced" "${out}"
	printf '%s' "${out}" | grep -q 'solo-trunk mode' && ok || bad "stop-reconcile: solo-trunk wording present (got: ${out})"
	printf '%s' "${out}" | grep -q '/steer:work' && bad "stop-reconcile: solo-trunk must NOT mention /steer:work (got: ${out})" || ok

	# M: solo-trunk advisory is independent of any prior committed issue ref — the
	# new work is uncommitted at Stop time, so there is no commit-scan to silence it.
	S12="$(git_repo stopSoloPriorRef main)"
	claude_md_mode "${S12}" solo-trunk
	git -C "${S12}" commit -q --allow-empty -m 'feat: earlier work (#99)'
	mkdir -p "${S12}/src"
	printf 'export const y = 2\n' >"${S12}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S12}" stS12)")"
	assert_block "stop-reconcile: solo-trunk advisory independent of prior commit issue ref" "${out}"

	# N: PR-flow repo whose CLAUDE.md prose names "solo trunk" reconciles normally
	# with PR-flow wording (matcher anchored to the marker line, not the prose).
	S13="$(git_repo stopPrProse main)"
	claude_md_mode "${S13}" pr-flow
	mkdir -p "${S13}/src"
	printf 'export const x = 1\n' >"${S13}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S13}" stS13)")"
	assert_block "stop-reconcile: pr-flow repo (prose says solo trunk) reported normally" "${out}"
	printf '%s' "${out}" | grep -q '/steer:work' && ok || bad "stop-reconcile: pr-flow keeps /steer:work (got: ${out})"

	# O: /steer:sync runs on feat/sync. Operations-class scaffold reconciliation
	# (compose/mise) is structural plugin-maintenance, not feature work -> silent
	# (rule 36 carve-out), even though those paths nudge on every other branch.
	S14="$(git_repo stopSyncBranch feat/sync)"
	printf 'services: {}\n' >"${S14}/compose.yaml"
	printf '[env]\n' >"${S14}/mise.toml"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S14}" stS14)")"
	assert_no_block "stop-reconcile: feat/sync scaffold reconciliation silent" "${out}"

	# O2: the feat/sync-<ver> variant is exempt the same way.
	S15="$(git_repo stopSyncVer main)"
	git -C "${S15}" checkout -q -b feat/sync-2.8.0
	printf 'services: {}\n' >"${S15}/compose.yaml"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S15}" stS15)")"
	assert_no_block "stop-reconcile: feat/sync-<ver> variant exempt" "${out}"

	# P: but a feat/sync turn that touched app source violates sync's contract
	# (structure only, never app code) -> still reported, not exempted.
	S16="$(git_repo stopSyncAppSrc feat/sync)"
	mkdir -p "${S16}/src"
	printf 'export const x = 1\n' >"${S16}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S16}" stS16)")"
	assert_block "stop-reconcile: feat/sync app source still reported (sync must not touch app code)" "${out}"

	# Q: hotfix fast-path (rule 62). A governed change on a hotfix/<n> branch files
	# its issue after-the-fact by design, so it still surfaces a one-time advisory
	# but REFRAMED as the mandatory post-incident follow-up — never the standard
	# "branch does not reference an issue" nag.
	SHF="$(git_repo stopHotfix hotfix/42-outage)"
	mkdir -p "${SHF}/src"
	printf 'export const x = 1\n' >"${SHF}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${SHF}" stSHF)")"
	assert_block "stop-reconcile: hotfix branch governed change surfaces follow-up advisory" "${out}"
	printf '%s' "${out}" | grep -q 'hotfix lane' && ok || bad "stop-reconcile: hotfix advisory wording present (got: ${out})"
	printf '%s' "${out}" | grep -q 'does not reference a GitHub issue' && bad "stop-reconcile: hotfix must not use the standard issue nag (got: ${out})" || ok
else
	printf 'SKIP: git unavailable, reconcile-issue-first.sh Stop tests skipped\n' >&2
fi

# ---------------------------------------------------------------------------
# check-open-questions.sh — structured Q-NNN parser + gate classification
# (SessionStart hook: emits plain markdown, wrapped into additionalContext by
#  the harness — assert on content, not on JSON shape.)
# ---------------------------------------------------------------------------
oq_repo() {
	_r="${WORK}/$1"
	mkdir -p "${_r}/spec/features/$2"
	printf '' >"${_r}/.git"
	printf '%s' "${_r}"
}
oq_grep() { printf '%s' "$3" | grep -q "$2" && ok || bad "$1 (got: $3)"; }

# Placeholder-marked seed (the bundled template) must NOT fire on a fresh scaffold.
OQ1="$(oq_repo oq1 seed)"
cp "${PLUGIN}/templates/spec/feature-intent.md" "${OQ1}/spec/features/seed/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ1}" oq1)")"
assert_empty "open-questions: placeholder seed -> silent" "${out}"

# Real open blocking question at intent-approval on a draft feature -> blocks now.
OQ2="$(oq_repo oq2 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — real one\n- status: open\n- impact: blocking\n- required_before: intent-approval\n'
} >"${OQ2}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ2}" oq2)")"
oq_grep "open-questions: open blocking question classified blocking-now" 'block work now' "${out}"

# Resolved question -> not counted -> silent.
OQ3="$(oq_repo oq3 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — done\n- status: resolved\n- impact: blocking\n- required_before: intent-approval\n'
} >"${OQ3}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ3}" oq3)")"
assert_empty "open-questions: resolved question -> silent" "${out}"

# Non-blocking open question -> backlog (fires, classified non-blocking).
OQ4="$(oq_repo oq4 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — later\n- status: open\n- impact: non-blocking\n- required_before: implementation\n'
} >"${OQ4}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ4}" oq4)")"
oq_grep "open-questions: non-blocking question classified backlog" 'non-blocking' "${out}"

# Malformed block (missing status/impact) -> needs-attention, never silently dropped.
OQ5="$(oq_repo oq5 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — broken\n- impact: blocking\n'
} >"${OQ5}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ5}" oq5)")"
oq_grep "open-questions: malformed block flagged" 'malformed' "${out}"

# Blocking question for a LATER gate (production-release) on a draft feature ->
# blocks a later transition, not now (shared lifecycle ordering).
OQ6="$(oq_repo oq6 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — prod\n- status: open\n- impact: blocking\n- required_before: production-release\n'
} >"${OQ6}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ6}" oq6)")"
oq_grep "open-questions: distant gate classified later-transition" 'later transition' "${out}"

# Retired SPEC-QUESTIONS.md present -> migration notice.
OQ7="$(oq_repo oq7 f)"
printf '# questions\n' >"${OQ7}/spec/SPEC-QUESTIONS.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ7}" oq7)")"
oq_grep "open-questions: retired SPEC-QUESTIONS.md migration notice" 'SPEC-QUESTIONS.md' "${out}"

# Legacy `- [ ]` checkbox still detected for one deprecation window.
OQ8="$(oq_repo oq8 f)"
printf '> Status: draft\n\n## Open questions\n\n- [ ] a real legacy question\n' >"${OQ8}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ8}" oq8)")"
oq_grep "open-questions: legacy checkbox still detected" 'open question' "${out}"

# Staleness escalation (STEER_TODAY pins "today" for hermetic age math; sentinel
# created dates make the threshold decision deterministic on any run date).
oq_ngrep() { printf '%s' "$3" | grep -q "$2" && bad "$1 (unexpected: $3)" || ok; }

# Blocking question created long ago, not promoted -> escalated as rotted.
OQ9="$(oq_repo oq9 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — old\n- created: 2000-01-01\n- status: open\n- impact: blocking\n- owner: product\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ9}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ9}" oq9)")"
oq_grep "open-questions: stale blocking question escalated" 'rotted' "${out}"

# Same question but created in the future -> aged negative -> NOT escalated
# (still fires the normal blocking-now notice, just no rot line).
OQ10="$(oq_repo oq10 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — future\n- created: 2099-12-31\n- status: open\n- impact: blocking\n- owner: product\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ10}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ10}" oq10)")"
oq_ngrep "open-questions: fresh question not escalated" 'rotted' "${out}"

# Stale but already promoted (has tracker: ref) -> on someone's plate -> NOT escalated.
OQ11="$(oq_repo oq11 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — promoted\n- created: 2000-01-01\n- status: open\n- impact: blocking\n- owner: product\n- tracker: #42\n'
} >"${OQ11}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ11}" oq11)")"
oq_ngrep "open-questions: promoted stale question not re-escalated" 'rotted' "${out}"

# Missing created: with no usable git (fake .git) -> blame fails open: counted as
# blocking-now, never crashes, no rot line.
OQ12="$(oq_repo oq12 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 — no created\n- status: open\n- impact: blocking\n- owner: development\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ12}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ12}" oq12)")"
oq_grep "open-questions: missing-created still counted (blame fail-open)" 'block work now' "${out}"
oq_ngrep "open-questions: missing-created not escalated when git unavailable" 'rotted' "${out}"

# ---------------------------------------------------------------------------
# orient-session.sh — natural-language orientation (SessionStart, managed only)
# (emits plain markdown wrapped into additionalContext by the harness — assert on
#  content, not JSON shape.)
# ---------------------------------------------------------------------------
# Managed, version-stamped spine -> orient.
OR1="$(new_repo orient1)"
managed_spine "${OR1}"
out="$(run_hook orient-session.sh "$(session_json "${OR1}" or1)")"
oq_grep "orient: managed spine emits orientation" 'need to know skill names' "${out}"

# Managed spine + in-progress PO build (BUILD-STATUS.md with an open handoff box)
# -> steer DETERMINISTICALLY back into /steer:build, not the generic orientation.
OR1B="$(new_repo orient1b)"
managed_spine "${OR1B}"
printf '# Build status\n\n## Handoff gate\n\n- [ ] PR proposed/opened:\n' >"${OR1B}/spec/BUILD-STATUS.md"
out="$(run_hook orient-session.sh "$(session_json "${OR1B}" or1b)")"
oq_grep "orient: in-progress build resumes /steer:build" 'Resume the guided build' "${out}"
oq_ngrep "orient: in-progress build skips generic orientation" 'need to know skill names' "${out}"

# Managed spine + handed-off build (every handoff box checked, no '- [ ]' line)
# -> back to the generic orientation; the resume nudge must NOT keep firing once
# the dev has taken over.
OR1C="$(new_repo orient1c)"
managed_spine "${OR1C}"
printf '# Build status\n\n## Handoff gate\n\n- [x] PR proposed/opened: #1\n' >"${OR1C}/spec/BUILD-STATUS.md"
out="$(run_hook orient-session.sh "$(session_json "${OR1C}" or1c)")"
oq_grep "orient: handed-off build falls back to orientation" 'need to know skill names' "${out}"
oq_ngrep "orient: handed-off build does not nag resume" 'Resume the guided build' "${out}"

# Bare/foreign spec/ (no .version) -> check-unmanaged-repo.sh owns it -> silent.
OR2="$(new_repo orient2)"
mkdir -p "${OR2}/spec"
out="$(run_hook orient-session.sh "$(session_json "${OR2}" or2)")"
assert_empty "orient: foreign spine silent (owned by unmanaged hook)" "${out}"

# No spec/ at all -> unmanaged -> silent.
OR3="$(new_repo orient3)"
out="$(run_hook orient-session.sh "$(session_json "${OR3}" or3)")"
assert_empty "orient: unmanaged repo silent" "${out}"

# .version present but a spine file missing -> damaged -> silent (sync owns it).
OR4="$(new_repo orient4)"
mkdir -p "${OR4}/spec"
printf '1.0.0\n' >"${OR4}/spec/.version"
printf 'x\n' >"${OR4}/spec/vision.md"
out="$(run_hook orient-session.sh "$(session_json "${OR4}" or4)")"
assert_empty "orient: damaged spine silent" "${out}"

# ---------------------------------------------------------------------------
# check-unmanaged-repo.sh — greenfield bootstrap nudge (SessionStart).
# Resolves the repo root from the payload `cwd` like its sibling SessionStart
# hooks (#331) — the suite deliberately does NOT cd into the fixture, so the
# hook process cwd (this repo, which has .claude-plugin/) diverges from the
# payload cwd; anchoring on the process cwd would self-silence every case
# below. new_repo drops a .git file the upward walk anchors on.
# ---------------------------------------------------------------------------
# No /spec spine -> nudge leads with the PO build path, still offers init/adopt.
UM1="$(new_repo unmanaged1)"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM1}" um1)")"
oq_grep "unmanaged: nudge offers /steer:build for a non-technical owner" '/steer:build' "${out}"
oq_grep "unmanaged: nudge still offers /steer:init for a developer" '/steer:init' "${out}"
oq_grep "unmanaged: nudge still offers /steer:adopt for existing code" '/steer:adopt' "${out}"

# Managed spine -> silent (the notice clears itself once /spec exists).
UM2="$(new_repo unmanaged2)"
managed_spine "${UM2}"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM2}" um2)")"
assert_empty "unmanaged: managed spine silent" "${out}"

# Payload cwd in a SUBDIRECTORY of an unmanaged repo -> the upward walk still
# anchors on the repo root and the nudge fires.
UM3="$(new_repo unmanaged3)"
mkdir -p "${UM3}/apps/web"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM3}/apps/web" um3)")"
oq_grep "unmanaged: payload subdir cwd still resolves the repo root" '/steer:init' "${out}"

# ---------------------------------------------------------------------------
# scripts/scan-version-pins.sh — CI version-pin scanner (deterministic policy)
# (pins assembled via pin() so this file's source carries no name:NN literal.)
# ---------------------------------------------------------------------------
SCAN="${PLUGIN}/scripts/scan-version-pins.sh"
BUNDLED_POLICY="${PLUGIN}/policy/versions.yml"
scan() { # <dir>  -> sets `rc`; uses the bundled policy
	STEER_POLICY_FILE="${BUNDLED_POLICY}" sh "${SCAN}" "$1" >/dev/null 2>&1
	rc=$?
}

SD="${WORK}/scan1"
mkdir -p "${SD}"
printf 'services:\n  db:\n    image: %s\n' "$(pin postgres 11)" >"${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: denied pin -> exit 1" "${rc}" 1

printf 'services:\n  db:\n    image: %s # steer:allow-pin vendor LTS\n' "$(pin postgres 11)" >"${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: suppressed pin -> exit 0" "${rc}" 0

printf 'FROM %s\n' "$(pin node 22)" >"${SD}/Dockerfile"
rm -f "${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: supported pin -> exit 0" "${rc}" 0

# Templated / variable values are NOT resolved -> never false-positived.
printf 'services:\n  db:\n    image: postgres:${PG_MAJOR}\n' >"${SD}/compose.yaml"
rm -f "${SD}/Dockerfile"
scan "${SD}"
assert_rc "scan: templated value not flagged" "${rc}" 0

# Excluded dependency trees are skipped even with a denied pin inside.
mkdir -p "${SD}/node_modules/x"
printf 'image: %s\n' "$(pin postgres 11)" >"${SD}/node_modules/x/compose.yaml"
rm -f "${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: excluded dir (node_modules) skipped" "${rc}" 0

# Bash-mediated pin in a committed script IS caught (the hook can't see it).
printf '#!/bin/sh\ndocker run %s\n' "$(pin postgres 11)" >"${SD}/run.sh"
scan "${SD}"
assert_rc "scan: committed Bash pin caught -> exit 1" "${rc}" 1
rm -f "${SD}/run.sh"

# No policy file -> config error.
SDNP="${WORK}/scan-nopolicy"
mkdir -p "${SDNP}"
printf 'image: %s\n' "$(pin postgres 11)" >"${SDNP}/compose.yaml"
sh "${SCAN}" "${SDNP}" >/dev/null 2>&1
assert_rc "scan: missing policy -> exit 2" "$?" 2

# ---------------------------------------------------------------------------
# scripts/template-reconcile.sh — read-only structural diff (not a hook)
# ---------------------------------------------------------------------------
RECON="${PLUGIN}/scripts/template-reconcile.sh"
RDIR="${WORK}/recon"
mkdir -p "${RDIR}"

printf '## A\n- [ ] one\n' >"${RDIR}/existing.md"
printf '## A\n## B\n- [ ] one\n- [ ] two\n' >"${RDIR}/bundled.md"

run_sh "${RECON}" "${RDIR}/existing.md" "${RDIR}/bundled.md"
assert_rc "reconcile: gaps run exits 0" "${rc}" 0
printf '%s' "${out}" | grep -q '## B' && ok || bad "reconcile: missing heading reported (got: ${out})"
printf '%s' "${out}" | grep -q -- '- \[ \] two' && ok || bad "reconcile: missing checklist item reported (got: ${out})"
printf '%s' "${out}" | grep -q '## A' && bad "reconcile: shared anchor wrongly reported (got: ${out})" || ok

# identical anchors -> file already current -> silent
run_sh "${RECON}" "${RDIR}/bundled.md" "${RDIR}/bundled.md"
assert_rc "reconcile: current run exits 0" "${rc}" 0
assert_empty "reconcile: current file -> silent" "${out}"

# checkbox state normalized: [x] in existing vs [ ] in bundled is NOT a diff
printf '## A\n- [x] one\n' >"${RDIR}/checked.md"
printf '## A\n- [ ] one\n' >"${RDIR}/unchecked.md"
run_sh "${RECON}" "${RDIR}/checked.md" "${RDIR}/unchecked.md"
assert_rc "reconcile: checkbox-normalization exits 0" "${rc}" 0
assert_empty "reconcile: [x] vs [ ] not reported" "${out}"

# placeholder-marked seed anchors are never reported as missing (issue #231):
# a completed intent that filled in / deleted the `### Q-001 — [...]` stub must
# not be flagged for the deleted placeholder.
printf '## Open questions\n_No open questions._\n' >"${RDIR}/done.md"
printf '## Open questions\n### Q-001 — [decide] <!-- steer:placeholder -->\n' >"${RDIR}/seed.md"
run_sh "${RECON}" "${RDIR}/done.md" "${RDIR}/seed.md"
assert_rc "reconcile: placeholder-skip exits 0" "${rc}" 0
assert_empty "reconcile: deleted placeholder seed not reported" "${out}"
# a renamed real question (marker deleted) is also not chased back to the stub
printf '## Open questions\n### Q-001 — should we ship X?\n' >"${RDIR}/real.md"
run_sh "${RECON}" "${RDIR}/real.md" "${RDIR}/seed.md"
assert_rc "reconcile: filled-in placeholder run exits 0" "${rc}" 0
assert_empty "reconcile: filled-in placeholder not reported" "${out}"
# a genuinely-missing (non-placeholder) heading is still reported
printf '## Open questions\n### Q-002 — real and unmarked\n' >"${RDIR}/seed2.md"
run_sh "${RECON}" "${RDIR}/done.md" "${RDIR}/seed2.md"
printf '%s' "${out}" | grep -q 'Q-002' && ok || bad "reconcile: real missing heading still reported (got: ${out})"

# usage + unreadable inputs
run_sh "${RECON}" "${RDIR}/existing.md"
assert_rc "reconcile: wrong arg count -> exit 2" "${rc}" 2
run_sh "${RECON}" "${RDIR}/nope.md" "${RDIR}/bundled.md"
assert_rc "reconcile: unreadable input -> exit 3" "${rc}" 3

# ---------------------------------------------------------------------------
# scripts/scan-capabilities.sh — read-only capability detector (not a hook)
# ---------------------------------------------------------------------------
CAPSCAN="${PLUGIN}/scripts/scan-capabilities.sh"
CAPS_MD="${PLUGIN}/templates/reference/CAPABILITIES.md"
capscan() { run_sh "${CAPSCAN}" "$1" "${PLUGIN}"; }
capstatus() { printf '%s\n' "$1" | awk -F '\t' -v id="$2" '$1==id {print $2}'; }

# Empty repo: capability-critical files absent; stack fingerprint emitted.
CR0="${WORK}/cap0"
mkdir -p "${CR0}"
capscan "${CR0}"
assert_eq "cap: empty repo plugin-enabled absent" "$(capstatus "${out}" plugin-enabled-local)" "absent"
assert_eq "cap: empty repo in-ci absent" "$(capstatus "${out}" in-ci-plugin-loading)" "absent"
assert_eq "cap: empty repo stack=none" "$(capstatus "${out}" stack)" "none"

# settings.json wiring: true -> wired, false -> disabled, present-no-steer -> mis-wired.
CR1="${WORK}/cap1"
mkdir -p "${CR1}/.claude"
printf '{"enabledPlugins":{"steer@e22-plugins":true}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: steer true -> present-wired" "$(capstatus "${out}" plugin-enabled-local)" "present-wired"
printf '{"enabledPlugins":{"steer@e22-plugins":false}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: steer false -> disabled (respected)" "$(capstatus "${out}" plugin-enabled-local)" "disabled"
printf '{"enabledPlugins":{}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: settings present, no steer -> mis-wired" "$(capstatus "${out}" plugin-enabled-local)" "mis-wired"

# claude.yml: plugin_marketplaces marker required (a stock template is mis-wired).
CR2="${WORK}/cap2"
mkdir -p "${CR2}/.github/workflows"
printf 'jobs:\n  claude:\n    steps: []\n' >"${CR2}/.github/workflows/claude.yml"
capscan "${CR2}"
assert_eq "cap: stock claude.yml -> mis-wired" "$(capstatus "${out}" in-ci-plugin-loading)" "mis-wired"
printf 'with:\n  plugin_marketplaces: e22-plugins\n' >>"${CR2}/.github/workflows/claude.yml"
capscan "${CR2}"
assert_eq "cap: claude.yml with marketplace -> present-wired" "$(capstatus "${out}" in-ci-plugin-loading)" "present-wired"

# version-pin-enforcement: policy + byte-identical scripts -> wired; drift -> mis-wired.
CR3="${WORK}/cap3"
mkdir -p "${CR3}/policy" "${CR3}/scripts"
printf 'minimum_supported:\n' >"${CR3}/policy/versions.yml"
cp "${PLUGIN}/scripts/scan-version-pins.sh" "${CR3}/scripts/scan-version-pins.sh"
cp "${PLUGIN}/hooks/lib/version-policy.sh" "${CR3}/scripts/version-policy.sh"
capscan "${CR3}"
assert_eq "cap: verbatim scripts -> present-wired" "$(capstatus "${out}" version-pin-enforcement)" "present-wired"
printf '# local edit\n' >>"${CR3}/scripts/scan-version-pins.sh"
capscan "${CR3}"
assert_eq "cap: drifted verbatim script -> mis-wired" "$(capstatus "${out}" version-pin-enforcement)" "mis-wired"
rm -f "${CR3}/policy/versions.yml"
capscan "${CR3}"
assert_eq "cap: missing policy -> absent" "$(capstatus "${out}" version-pin-enforcement)" "absent"

# node-tooling conditionality: Python-only n/a; Node without biome absent; with biome wired.
CR4="${WORK}/cap4"
mkdir -p "${CR4}"
printf '[project]\n' >"${CR4}/pyproject.toml"
capscan "${CR4}"
assert_eq "cap: python stack -> node-tooling n/a" "$(capstatus "${out}" node-tooling)" "n/a"
assert_eq "cap: python fingerprint" "$(capstatus "${out}" stack)" "python"
rm -f "${CR4}/pyproject.toml"
printf '{}\n' >"${CR4}/package.json"
capscan "${CR4}"
assert_eq "cap: node without biome -> absent" "$(capstatus "${out}" node-tooling)" "absent"
printf '{}\n' >"${CR4}/biome.json"
capscan "${CR4}"
assert_eq "cap: node with biome -> present-wired" "$(capstatus "${out}" node-tooling)" "present-wired"

# github-issue-forms: gated on the tracker system in spec/tracker.md.
CR5="${WORK}/cap5"
mkdir -p "${CR5}/spec"
printf 'system: jira\n' >"${CR5}/spec/tracker.md"
capscan "${CR5}"
assert_eq "cap: non-github tracker -> issue-forms n/a" "$(capstatus "${out}" github-issue-forms)" "n/a"
printf 'system: github\n' >"${CR5}/spec/tracker.md"
capscan "${CR5}"
assert_eq "cap: github tracker, no forms -> absent" "$(capstatus "${out}" github-issue-forms)" "absent"
mkdir -p "${CR5}/.github/ISSUE_TEMPLATE"
printf 'blank_issues_enabled: false\n' >"${CR5}/.github/ISSUE_TEMPLATE/config.yml"
capscan "${CR5}"
assert_eq "cap: github tracker with forms -> present-wired" "$(capstatus "${out}" github-issue-forms)" "present-wired"

# github-issue-permissions: gated on the tracker system; wired when the gh-issue
# allow-list is present in .claude/settings.json (write verb is the marker).
CR5b="${WORK}/cap5b"
mkdir -p "${CR5b}/spec"
printf 'system: jira\n' >"${CR5b}/spec/tracker.md"
capscan "${CR5b}"
assert_eq "cap: non-github tracker -> issue-perms n/a" "$(capstatus "${out}" github-issue-permissions)" "n/a"
printf 'system: github\n' >"${CR5b}/spec/tracker.md"
capscan "${CR5b}"
assert_eq "cap: github tracker, no settings -> absent" "$(capstatus "${out}" github-issue-permissions)" "absent"
mkdir -p "${CR5b}/.claude"
printf '{"permissions":{"allow":["Bash(gh issue list:*)","Bash(gh issue view:*)"]}}\n' >"${CR5b}/.claude/settings.json"
capscan "${CR5b}"
assert_eq "cap: read-only-era settings -> mis-wired" "$(capstatus "${out}" github-issue-permissions)" "mis-wired"
printf '{"permissions":{"allow":["Bash(gh issue create:*)","Bash(gh issue view:*)"]}}\n' >"${CR5b}/.claude/settings.json"
capscan "${CR5b}"
assert_eq "cap: settings with gh issue create -> present-wired" "$(capstatus "${out}" github-issue-permissions)" "present-wired"

# toolchain-pin: mise.toml without lock is mis-wired; both -> wired.
CR6="${WORK}/cap6"
mkdir -p "${CR6}"
printf '[tools]\n' >"${CR6}/mise.toml"
capscan "${CR6}"
assert_eq "cap: mise.toml without lock -> mis-wired" "$(capstatus "${out}" toolchain-pin)" "mis-wired"
printf '\n' >"${CR6}/mise.lock"
capscan "${CR6}"
assert_eq "cap: mise.toml + lock -> present-wired" "$(capstatus "${out}" toolchain-pin)" "present-wired"

# worktree-port-isolation: n/a without a runtime; with a runtime, deriver +
# mise [env]._.source -> wired; deriver present but mise unwired -> mis-wired.
CR7="${WORK}/cap7"
mkdir -p "${CR7}/scripts"
capscan "${CR7}"
assert_eq "cap: no runtime -> worktree isolation n/a" "$(capstatus "${out}" worktree-port-isolation)" "n/a"
printf '{}\n' >"${CR7}/package.json"
capscan "${CR7}"
assert_eq "cap: node stack, no deriver -> absent" "$(capstatus "${out}" worktree-port-isolation)" "absent"
printf 'export X=1\n' >"${CR7}/scripts/worktree-env.sh"
printf '[tools]\n' >"${CR7}/mise.toml"
capscan "${CR7}"
assert_eq "cap: deriver present, mise unwired -> mis-wired" "$(capstatus "${out}" worktree-port-isolation)" "mis-wired"
printf '[env]\n_.source = "scripts/worktree-env.sh"\n' >>"${CR7}/mise.toml"
capscan "${CR7}"
assert_eq "cap: deriver + mise sources it -> present-wired" "$(capstatus "${out}" worktree-port-isolation)" "present-wired"

# delivery-mode-declared: no CLAUDE.md -> absent; present without the marker ->
# mis-wired (implicit fail-open pr-flow); marker present -> wired.
CR8="${WORK}/cap8"
mkdir -p "${CR8}"
capscan "${CR8}"
assert_eq "cap: no CLAUDE.md -> delivery-mode absent" "$(capstatus "${out}" delivery-mode-declared)" "absent"
printf '# Product\n\nsome prose\n' >"${CR8}/CLAUDE.md"
capscan "${CR8}"
assert_eq "cap: CLAUDE.md without marker -> mis-wired" "$(capstatus "${out}" delivery-mode-declared)" "mis-wired"
printf '<!-- steer:delivery-mode=solo-trunk -->\n' >>"${CR8}/CLAUDE.md"
capscan "${CR8}"
assert_eq "cap: CLAUDE.md with marker -> present-wired" "$(capstatus "${out}" delivery-mode-declared)" "present-wired"

# app-knowledge-docs: the app guide is instantiated from a spec template, so
# additive reconciliation can never create it — the capability is its backfill
# path. Absent when spec/app/README.md is missing; present-wired once it exists.
CR9="${WORK}/cap9"
mkdir -p "${CR9}"
capscan "${CR9}"
assert_eq "cap: no app guide -> app-knowledge-docs absent" "$(capstatus "${out}" app-knowledge-docs)" "absent"
mkdir -p "${CR9}/spec/app"
printf '# App guide\n' >"${CR9}/spec/app/README.md"
capscan "${CR9}"
assert_eq "cap: app guide present -> present-wired" "$(capstatus "${out}" app-knowledge-docs)" "present-wired"

# Idempotency: repairing a mis-wired settings.json makes the re-scan present-wired.
printf '{"enabledPlugins":{"steer@e22-plugins":true}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: repaired settings -> present-wired on re-scan" "$(capstatus "${out}" plugin-enabled-local)" "present-wired"

# Every capability id the detector emits is documented in CAPABILITIES.md.
# `stack` and `profile` are informational fingerprints, not capabilities — exempt.
capscan "${CR0}"
printf '%s\n' "${out}" | awk -F '\t' '$1!="stack" && $1!="profile"{print $1}' | while IFS= read -r _id; do
	grep -q "### ${_id} " "${CAPS_MD}" || printf 'UNDOC %s\n' "${_id}"
done >"${WORK}/cap-undoc"
assert_empty "cap: all emitted ids documented in CAPABILITIES.md" "$(cat "${WORK}/cap-undoc")"

# Exit-code contract: gaps on stdout (exit 0); usage -> 2; unreadable root -> 3.
sh "${CAPSCAN}" "${CR0}" "${PLUGIN}" >/dev/null 2>&1
assert_rc "cap: gaps run exits 0" "$?" 0
sh "${CAPSCAN}" a b c >/dev/null 2>&1
assert_rc "cap: too many args -> exit 2" "$?" 2
sh "${CAPSCAN}" "${WORK}/cap-nope" "${PLUGIN}" >/dev/null 2>&1
assert_rc "cap: unreadable repo-root -> exit 3" "$?" 3

# ---------------------------------------------------------------------------
# scripts/scan-invocations.sh — read-only invalid-invocation detector (not a hook)
# ---------------------------------------------------------------------------
INVSCAN="${PLUGIN}/scripts/scan-invocations.sh"
INV_MD="${PLUGIN}/templates/reference/INVOCATION.md"
invscan() { run_sh "${INVSCAN}" "$1" "${PLUGIN}"; }
invclass() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$3==t {print $4; exit}'; }
invfix() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$3==t {print $5; exit}'; }

# A fixture managed repo carrying one occurrence of each class plus tokens that
# MUST NOT be flagged (a valid skill, a correct /steer:reference <mode>, the
# marketplace id) and a provenance file that must not be scanned at all.
IR0="${WORK}/inv0"
mkdir -p "${IR0}/.github" "${IR0}/spec"
{
	printf '# Manual\n'
	printf 'Adopted via /e22-adopt in the past.\n'          # legacy-e22 -> /steer:adopt
	printf 'Full prose: /steer:conventions here.\n'          # reference-mode
	printf 'New spec: /steer:spec-scaffold <id>.\n'          # noncallable-gateway
	printf 'Try /steer:bogus for nothing.\n'                 # unknown
	printf 'Run /steer:sync to update.\n'                    # valid -> no emit
	printf 'Correct: /steer:reference conventions.\n'        # valid -> no emit
	printf 'Marketplace element22llc/e22-plugins stays.\n'   # not flagged
} >"${IR0}/CLAUDE.md"
printf 'See /steer:design-sources for exports.\n' >"${IR0}/README.md"       # reference-mode
printf 'Contributor guide: /steer:conventions applies.\n' >"${IR0}/.github/pull_request_template.md"
printf '2026-06-08: reverse-engineered by /e22-adopt.\n' >"${IR0}/spec/HISTORY.md"  # provenance, NOT scanned

invscan "${IR0}"
assert_eq "inv: /e22-adopt -> legacy-e22" "$(invclass "${out}" /e22-adopt)" "legacy-e22"
assert_eq "inv: /e22-adopt fix -> /steer:adopt" "$(invfix "${out}" /e22-adopt)" "/steer:adopt"
assert_eq "inv: /steer:conventions -> reference-mode" "$(invclass "${out}" /steer:conventions)" "reference-mode"
assert_eq "inv: /steer:conventions fix -> reference form" "$(invfix "${out}" /steer:conventions)" "/steer:reference conventions"
assert_eq "inv: /steer:design-sources -> reference-mode (README)" "$(invclass "${out}" /steer:design-sources)" "reference-mode"
assert_eq "inv: /steer:spec-scaffold -> noncallable-gateway" "$(invclass "${out}" /steer:spec-scaffold)" "noncallable-gateway"
assert_eq "inv: /steer:bogus -> unknown" "$(invclass "${out}" /steer:bogus)" "unknown"
# Valid invocations and the marketplace id emit nothing.
printf '%s' "${out}" | grep -q '/steer:sync' && bad "inv: valid /steer:sync must not be flagged" || ok
printf '%s' "${out}" | grep -q 'e22-plugins' && bad "inv: marketplace id must not be flagged" || ok
# The /steer:reference <mode> correct form resolves via the `reference` skill, so
# no line carries the token `/steer:reference`.
assert_eq "inv: correct /steer:reference not flagged" "$(invclass "${out}" /steer:reference)" ""
# Provenance file is out of scope entirely — no finding cites HISTORY.md.
printf '%s' "${out}" | grep -q 'spec/HISTORY.md' && bad "inv: provenance HISTORY.md must not be scanned" || ok

# Clean repo (the current scaffold CLAUDE.md) -> silent.
IR1="${WORK}/inv1"
mkdir -p "${IR1}"
cp "${PLUGIN}/templates/scaffold/CLAUDE.md" "${IR1}/CLAUDE.md"
invscan "${IR1}"
assert_empty "inv: clean scaffold CLAUDE.md -> silent" "${out}"

# Every class the detector emits is documented in INVOCATION.md.
invscan "${IR0}"
printf '%s\n' "${out}" | awk -F '\t' '{print $4}' | sort -u | while IFS= read -r _cls; do
	[ -n "${_cls}" ] || continue
	grep -q "\`${_cls}\`" "${INV_MD}" || printf 'UNDOC %s\n' "${_cls}"
done >"${WORK}/inv-undoc"
assert_empty "inv: all emitted classes documented in INVOCATION.md" "$(cat "${WORK}/inv-undoc")"

# Exit-code contract: findings on stdout (exit 0); usage -> 2; unreadable root -> 3.
sh "${INVSCAN}" "${IR0}" "${PLUGIN}" >/dev/null 2>&1
assert_rc "inv: findings run exits 0" "$?" 0
sh "${INVSCAN}" a b c >/dev/null 2>&1
assert_rc "inv: too many args -> exit 2" "$?" 2
sh "${INVSCAN}" "${WORK}/inv-nope" "${PLUGIN}" >/dev/null 2>&1
assert_rc "inv: unreadable repo-root -> exit 3" "$?" 3

# ---------------------------------------------------------------------------
# scripts/scan-prereqs.sh — offline cases for the pure parts (os/stack
# fingerprint, shadowed classification). The detector probes the host PATH, so
# each case runs it under a HERMETIC PATH: a dir of symlinked core utilities
# plus only the tools the case plants — every verdict is deterministic on any
# host or CI runner.
# ---------------------------------------------------------------------------
PREREQS="${PLUGIN}/scripts/scan-prereqs.sh"
PQ_CORE="${WORK}/pq-core"
mkdir -p "${PQ_CORE}"
for _t in sh uname head tr ls grep; do
	ln -s "$(command -v "${_t}")" "${PQ_CORE}/${_t}"
done

fake_tool() { # <dir> <name> <output-line>  — a stub that answers any args with $3
	printf '#!/bin/sh\necho "%s"\n' "$3" >"$1/$2"
	chmod +x "$1/$2"
}
pqscan() { # <PATH-value> <repo> [extra env assignments...]
	_pq_path="$1"
	_pq_repo="$2"
	shift 2
	out="$(env "$@" PATH="${_pq_path}" sh "${PREREQS}" "${_pq_repo}" 2>/dev/null)"
	rc=$?
	printf '%s' "${rc}" >"${RC_FILE}"
}
pqstatus() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$1==t {print $2; exit}'; }
pqdetail() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$1==t {print $3; exit}'; }

# --- os fingerprint (fake uname pins the kernel name per case) ---
PQ_OS="${WORK}/pq-os-bin"
mkdir -p "${PQ_OS}"
fake_tool "${PQ_OS}" uname "Darwin"
# fake uname shadows the core one -> prepend
PQR="${WORK}/pq-repo"
mkdir -p "${PQR}"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}"
assert_rc "prereqs: normal run exits 0" "${rc}" 0
assert_eq "prereqs: os Darwin -> darwin" "$(pqstatus "${out}" os)" "darwin"
fake_tool "${PQ_OS}" uname "Linux"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: os Linux (no WSL) -> linux" "$(pqstatus "${out}" os)" "linux"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}" WSL_DISTRO_NAME=Ubuntu
assert_eq "prereqs: os Linux + WSL_DISTRO_NAME -> wsl2" "$(pqstatus "${out}" os)" "wsl2"
fake_tool "${PQ_OS}" uname "MINGW64_NT-10.0"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: os MINGW -> windows" "$(pqstatus "${out}" os)" "windows"

# --- stack fingerprint drives n/a verdicts ---
PQ_PY="${WORK}/pq-py"
mkdir -p "${PQ_PY}"
printf '[project]\n' >"${PQ_PY}/pyproject.toml"
pqscan "${PQ_CORE}" "${PQ_PY}"
assert_eq "prereqs: python-only repo -> node n/a" "$(pqstatus "${out}" node)" "n/a"
assert_eq "prereqs: python-only repo -> pnpm n/a" "$(pqstatus "${out}" pnpm)" "n/a"
PQ_NODE="${WORK}/pq-node"
mkdir -p "${PQ_NODE}"
printf '{}\n' >"${PQ_NODE}/package.json"
pqscan "${PQ_CORE}" "${PQ_NODE}"
assert_eq "prereqs: node-only repo -> uv n/a" "$(pqstatus "${out}" uv)" "n/a"

# --- required tools + runtime classification against a controlled PATH ---
# Nothing planted: git/mise missing; runtimes unmanaged (no mise to provide them).
pqscan "${PQ_CORE}" "${PQR}"
assert_eq "prereqs: bare PATH -> git missing" "$(pqstatus "${out}" git)" "missing"
assert_eq "prereqs: bare PATH -> mise missing" "$(pqstatus "${out}" mise)" "missing"
assert_eq "prereqs: no mise -> node unmanaged" "$(pqstatus "${out}" node)" "unmanaged"

# mise present, runtime absent -> via-mise.
PQ_MISEBIN="${WORK}/pq-misebin"
mkdir -p "${PQ_MISEBIN}"
fake_tool "${PQ_MISEBIN}" mise "mise 0.0-fake"
pqscan "${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: mise present, node absent -> via-mise" "$(pqstatus "${out}" node)" "via-mise"

# mise present + runtime resolving OUTSIDE the mise data dir -> shadowed (advisory).
PQ_SHADOW="${WORK}/pq-shadowbin"
mkdir -p "${PQ_SHADOW}"
fake_tool "${PQ_SHADOW}" node "v0.0-fake"
pqscan "${PQ_SHADOW}:${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: non-mise node while mise present -> shadowed" "$(pqstatus "${out}" node)" "shadowed"
assert_has "prereqs: shadowed detail names the fix" "$(pqdetail "${out}" node)" "mise exec"

# ... and the shadow source is classified (a ~/.nvm path reads as nvm).
PQ_NVM="${WORK}/.nvm/versions/bin"
mkdir -p "${PQ_NVM}"
fake_tool "${PQ_NVM}" node "v0.0-fake"
pqscan "${PQ_NVM}:${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_has "prereqs: nvm path classified as nvm shadow" "$(pqdetail "${out}" node)" "(nvm)"

# A mise-managed resolution (path contains /mise/) is NOT shadowed -> ok.
PQ_MISED="${WORK}/mise/installs/node/bin"
mkdir -p "${PQ_MISED}"
fake_tool "${PQ_MISED}" node "v0.0-fake"
pqscan "${PQ_MISED}:${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: mise-managed node -> ok" "$(pqstatus "${out}" node)" "ok"

# --- docker requiredness rides on compose presence ---
pqscan "${PQ_CORE}" "${PQR}"
assert_has "prereqs: no compose -> docker advisory" "$(pqdetail "${out}" docker)" "advisory"
printf 'services:\n' >"${PQR}/compose.yaml"
pqscan "${PQ_CORE}" "${PQR}"
assert_eq "prereqs: compose + no docker -> missing" "$(pqstatus "${out}" docker)" "missing"
assert_has "prereqs: compose -> docker required" "$(pqdetail "${out}" docker)" "required"
rm -f "${PQR}/compose.yaml"

# --- exit-code contract ---
sh "${PREREQS}" a b >/dev/null 2>&1
assert_rc "prereqs: too many args -> exit 2" "$?" 2
sh "${PREREQS}" "${WORK}/pq-nope" >/dev/null 2>&1
assert_rc "prereqs: unreadable repo-root -> exit 3" "$?" 3

# ---------------------------------------------------------------------------
# scripts/check-policy-freshness.sh — offline cases for the pure parts
# (norm_cycle granularity, bump-up-only, apply_floor in-place edit). The live
# feed is stubbed: a fake `curl` emits canned per-product cycle lists and a
# fake `jq` is a stdin passthrough, so only the script's own logic is under
# test — no network, deterministic.
# ---------------------------------------------------------------------------
FRESH="${PLUGIN}/scripts/check-policy-freshness.sh"
FR_BIN="${WORK}/fresh-bin"
mkdir -p "${FR_BIN}"
cat >"${FR_BIN}/curl" <<'EOF'
#!/bin/sh
for _a in "$@"; do _url="${_a}"; done
case "${_url}" in
*postgresql*) printf '14\n15\n16\n' ;; # floor 13 EOL'd -> lowest supported 14
*mysql*) printf '8.4\n9.1.2\n' ;;      # major.minor floor; 9.1.2 must normalize to 9.1
*mariadb*) printf '10.11\n11.4\n' ;;   # major-only floor; 10.11 must normalize to 10
*) exit 22 ;;
esac
EOF
printf '#!/bin/sh\ncat\n' >"${FR_BIN}/jq"
chmod +x "${FR_BIN}/curl" "${FR_BIN}/jq"
freshrun() { # [args...] — run with the stubbed feed; sets out + rc (+ RC_FILE)
	out="$(env PATH="${FR_BIN}:${PATH}" sh "${FRESH}" "$@" 2>/dev/null)"
	rc=$?
	printf '%s' "${rc}" >"${RC_FILE}"
}

FR_POL="${WORK}/fresh-policy.yml"
fresh_policy() {
	cat >"${FR_POL}" <<'EOF'
products:
  postgres:
    minimum_supported: "13"
  mysql:
    minimum_supported: "8.0"
  mariadb:
    minimum_supported: "10"
  valkey:
    minimum_supported: "7"
EOF
}
fresh_policy

# Read-only mode: behind floors reported, exit 1, file untouched.
freshrun "${FR_POL}"
assert_rc "freshness: bumps due -> exit 1" "${rc}" 1
assert_has "freshness: postgres floor bump reported" "${out}" "postgres: minimum_supported 13 → 14"
assert_has "freshness: major.minor floor normalized (9.1.2 -> 8.4 wins)" "${out}" "mysql: minimum_supported 8.0 → 8.4"
# norm_cycle keeps the floor's granularity: upstream "10.11" reads as major "10",
# equal to the current floor -> NO bump (a finer cycle must never over-deny).
printf '%s' "${out}" | grep -q 'mariadb' && bad "freshness: major-only floor must not bump from 10.11 (got: ${out})" || ok
grep -q 'minimum_supported: "13"' "${FR_POL}" && ok || bad "freshness: read-only run must not edit the policy file"

# --write: floors bumped in place (product-scoped), exit 1.
freshrun --write "${FR_POL}"
assert_rc "freshness: --write applies -> exit 1" "${rc}" 1
grep -q 'minimum_supported: "14"' "${FR_POL}" && ok || bad "freshness: postgres floor not bumped to 14"
grep -q 'minimum_supported: "8.4"' "${FR_POL}" && ok || bad "freshness: mysql floor not bumped to 8.4"
grep -q 'minimum_supported: "10"' "${FR_POL}" && ok || bad "freshness: mariadb floor must stay 10 (apply_floor scoped per product)"
grep -q 'minimum_supported: "7"' "${FR_POL}" && ok || bad "freshness: no-feed product (valkey) must be skipped untouched"

# Idempotent: floors now current -> exit 0, silent.
freshrun "${FR_POL}"
assert_rc "freshness: floors current -> exit 0" "${rc}" 0
assert_empty "freshness: floors current -> silent" "${out}"

# Missing policy file -> config error.
freshrun "${WORK}/fresh-nope.yml"
assert_rc "freshness: missing policy -> exit 2" "${rc}" 2

# ---------------------------------------------------------------------------
# Self-fault recording (lib/report-fault.sh) + surfacing (surface-faults.sh).
# ---------------------------------------------------------------------------

# Recording is deduped by source|signature so a recurring fault is logged once.
RF1="$(new_repo rf1)"
steer_record_fault "${RF1}" "inject-standards.sh" "rules directory missing"
steer_record_fault "${RF1}" "inject-standards.sh" "rules directory missing"
assert_eq "fault: identical faults deduped to one record" \
	"$(grep -c '' "${RF1}/.claude/steer-faults.log")" "1"
steer_record_fault "${RF1}" "other.sh" "different symptom"
assert_eq "fault: distinct faults both recorded" \
	"$(grep -c '' "${RF1}/.claude/steer-faults.log")" "2"

# A signature carrying the delimiter/newline is sanitized, never breaks the row.
RF1b="$(new_repo rf1b)"
steer_record_fault "${RF1b}" "x|y" "a|b"
assert_eq "fault: one record despite embedded delimiter" \
	"$(grep -c '' "${RF1b}/.claude/steer-faults.log")" "1"

# No log -> surface stays silent.
RF2="$(new_repo rf2)"
out="$(run_hook surface-faults.sh "$(session_json "${RF2}" rf2)")"
assert_empty "surface: no fault log -> silent" "${out}"

# A recorded, unsurfaced fault -> notice in context, marker advanced.
RF3="$(new_repo rf3)"
steer_record_fault "${RF3}" "inject-standards.sh" "rules directory missing"
out="$(run_hook surface-faults.sh "$(session_json "${RF3}" rf3)")"
oq_grep "surface: unreported fault raises a notice" 'self-fault' "${out}"
oq_grep "surface: notice points at /steer:report" 'steer:report' "${out}"
assert_eq "surface: marker records count surfaced" \
	"$(cat "${RF3}/.claude/steer-faults.surfaced")" "1"

# Second run with no new fault -> silent (surfaced once, never a per-session nag).
out="$(run_hook surface-faults.sh "$(session_json "${RF3}" rf3)")"
assert_empty "surface: already-surfaced fault stays silent" "${out}"

# A newly-recorded fault after surfacing -> only the new one is raised.
steer_record_fault "${RF3}" "surface-faults.sh" "brand new symptom"
out="$(run_hook surface-faults.sh "$(session_json "${RF3}" rf3)")"
oq_grep "surface: new fault raised after prior surface" 'brand new symptom' "${out}"
printf '%s' "${out}" | grep -q 'rules directory missing' &&
	bad "surface: must not re-raise already-surfaced fault (got: ${out})" || ok

# Inside the plugin's own tree (.claude-plugin present) -> never nag.
RF4="$(new_repo rf4)"
mkdir -p "${RF4}/.claude-plugin"
steer_record_fault "${RF4}" "inject-standards.sh" "rules directory missing"
out="$(run_hook surface-faults.sh "$(session_json "${RF4}" rf4)")"
assert_empty "surface: silent inside the plugin's own repo" "${out}"

# ----- inject-standards.sh: missing-rules fail-soft (banner + rc 0, #319) -----
# SessionStart stdout becomes additionalContext ONLY on exit 0, so the fallback
# banner must always ship with a clean exit. A fake plugin root (hook libs, no
# rules/) exercises the degraded path via the CLAUDE_PLUGIN_ROOT override.
FAKEPLUGIN="${WORK}/fakeplugin"
mkdir -p "${FAKEPLUGIN}/hooks"
cp -R "${HOOKS}/lib" "${FAKEPLUGIN}/hooks/lib"
# Consumer root that looks like the plugin's own tree (.claude-plugin present):
# pre-fix the record-fault guard chain's failed test leaked rc 1 here, dropping
# the banner exactly in the degraded scenario it exists for.
NR1="$(new_repo norules_plugintree)"
mkdir -p "${NR1}/.claude-plugin"
out="$(ENV="CLAUDE_PLUGIN_ROOT=${FAKEPLUGIN}" run_hook inject-standards.sh "$(session_json "${NR1}" nr1)")"
assert_has "inject: missing rules dir still emits fallback banner (plugin tree)" "${out}" 'rules directory was not found'
assert_rc "inject: missing-rules fail-soft exits 0 (plugin tree)" "$(last_rc)" 0
# Ordinary consumer repo: banner + rc 0, and the defect is recorded for
# surface-faults.sh to offer /steer:report.
NR2="$(new_repo norules_consumer)"
out="$(ENV="CLAUDE_PLUGIN_ROOT=${FAKEPLUGIN}" run_hook inject-standards.sh "$(session_json "${NR2}" nr2)")"
assert_has "inject: missing rules dir emits fallback banner (consumer repo)" "${out}" 'rules directory was not found'
assert_rc "inject: missing-rules fail-soft exits 0 (consumer repo)" "$(last_rc)" 0
grep -q 'rules directory missing' "${NR2}/.claude/steer-faults.log" 2>/dev/null &&
	ok || bad "inject: missing rules dir records a self-fault in the consumer repo"

# ----- inject-standards.sh: conditional (inject-when) rule scoping -----
# 36-issue-first carries inject-when=tracker-github; 52-deployment inject-when=has-iac|has-apps.
# A scoped rule is injected only when its predicate holds; always-on rules
# (e.g. 00-router) appear regardless; the marker line never leaks into output.

# GitHub tracker -> issue-first injected, its marker stripped.
CRI_GH="$(new_repo cri_gh)"
mkdir -p "${CRI_GH}/spec"
printf 'system: github\n' >"${CRI_GH}/spec/tracker.md"
out="$(run_hook inject-standards.sh "$(session_json "${CRI_GH}" cri_gh)")"
oq_grep "inject: github repo includes issue-first rule" 'Issue-first (GitHub-adopted repos)' "${out}"
oq_grep "inject: always-on router present (github repo)" 'You are the router' "${out}"
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject: inject-when marker line must be stripped from output" || ok

# Non-GitHub tracker -> issue-first skipped.
CRI_JIRA="$(new_repo cri_jira)"
mkdir -p "${CRI_JIRA}/spec"
printf 'system: jira\n' >"${CRI_JIRA}/spec/tracker.md"
out="$(run_hook inject-standards.sh "$(session_json "${CRI_JIRA}" cri_jira)")"
printf '%s' "${out}" | grep -q 'Issue-first (GitHub-adopted repos)' &&
	bad "inject: non-github repo must omit issue-first rule" || ok
oq_grep "inject: always-on router present (jira repo)" 'You are the router' "${out}"

# /infra present -> deployment AND infra-stack fragment injected (has-infra + has-iac).
CRI_INFRA="$(new_repo cri_infra)"
mkdir -p "${CRI_INFRA}/infra"
out="$(run_hook inject-standards.sh "$(session_json "${CRI_INFRA}" cri_infra)")"
oq_grep "inject: repo with /infra includes deployment rule" 'auto-deploys non-prod' "${out}"
oq_grep "inject: repo with /infra includes infra-stack fragment" 'Stack — infrastructure / IaC' "${out}"

# Root-level IaC (Ansible site.yml, no /infra dir) -> infra-stack fragment injected
# via has-iac. This is the case steer used to skip entirely.
CRI_ANSIBLE="$(new_repo cri_ansible)"
printf -- '- hosts: all\n' >"${CRI_ANSIBLE}/site.yml"
out="$(run_hook inject-standards.sh "$(session_json "${CRI_ANSIBLE}" cri_ansible)")"
oq_grep "inject: root-level Ansible repo includes infra-stack fragment" 'Stack — infrastructure / IaC' "${out}"
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject: inject-when marker line must be stripped (ansible repo)" || ok

# App repo (package.json, no /infra, no IaC) -> deployment rule injected via the
# has-apps arm of has-iac|has-apps, but NOT the infra-stack fragment (has-iac only).
CRI_APP="$(new_repo cri_app)"
printf '{}\n' >"${CRI_APP}/package.json"
out="$(run_hook inject-standards.sh "$(session_json "${CRI_APP}" cri_app)")"
oq_grep "inject: app repo (no /infra) includes deployment rule" 'auto-deploys non-prod' "${out}"
printf '%s' "${out}" | grep -q 'Stack — infrastructure / IaC' &&
	bad "inject: app repo without IaC must omit infra-stack fragment" || ok

# No /infra, no IaC, no GitHub tracker -> all scoped rules skipped.
CRI_BARE="$(new_repo cri_bare)"
out="$(run_hook inject-standards.sh "$(session_json "${CRI_BARE}" cri_bare)")"
printf '%s' "${out}" | grep -q 'auto-deploys non-prod' &&
	bad "inject: repo without /infra must omit deployment rule" || ok
printf '%s' "${out}" | grep -q 'Stack — infrastructure / IaC' &&
	bad "inject: repo without IaC must omit infra-stack fragment" || ok
printf '%s' "${out}" | grep -q 'Issue-first (GitHub-adopted repos)' &&
	bad "inject: repo without github tracker must omit issue-first rule" || ok
oq_grep "inject: always-on router present (bare repo)" 'You are the router' "${out}"

# ----- inject-standards.sh + orient-session.sh: knowledge-work mode -----
# A non-git folder with no code/config markers (the typical Claude Cowork
# product-owner case) is classified 'knowledge': only the unmarked, always-on
# PO-relevant rules inject, every code/infra/tracker-scoped rule is skipped, and
# orient-session emits a plain-language confirmation.
KW="${WORK}/kw_plain"
mkdir -p "${KW}"
printf '# my notes\n' >"${KW}/notes.md"
out="$(run_hook inject-standards.sh "$(session_json "${KW}" kw_plain)")"
oq_grep "inject(kw): knowledge-mode banner present" 'knowledge-work mode' "${out}"
oq_grep "inject(kw): always-on router present" 'You are the router' "${out}"
oq_grep "inject(kw): spec-workflow rule present" 'Spec workflow' "${out}"
oq_grep "inject(kw): secrets rule present" 'Secrets handling' "${out}"
printf '%s' "${out}" | grep -q '## Stack' &&
	bad "inject(kw): code-only stack rule must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'isolate runtime, clean up after' &&
	bad "inject(kw): worktrees rule must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'A change is done when' &&
	bad "inject(kw): code-flavored Definition of Done must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'End-of-session checklist' &&
	bad "inject(kw): code-flavored end-of-session checklist must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject(kw): no inject-when marker may leak in knowledge mode" || ok
out="$(run_hook orient-session.sh "$(session_json "${KW}" kw_plain)")"
oq_grep "orient(kw): knowledge-work confirmation emitted" 'knowledge-work folder' "${out}"

# Fail-safe guard: a non-git folder that DOES carry a code marker (package.json)
# is 'code' mode — full ruleset, no knowledge banner, no knowledge confirmation.
KWC="${WORK}/kw_pkg"
mkdir -p "${KWC}"
printf '{}\n' >"${KWC}/package.json"
out="$(run_hook inject-standards.sh "$(session_json "${KWC}" kw_pkg)")"
oq_grep "inject(kw-pkg): code-mode includes stack rule" '## Stack' "${out}"
printf '%s' "${out}" | grep -q 'knowledge-work mode' &&
	bad "inject(kw-pkg): non-git folder with package.json must be code mode" || ok
out="$(run_hook orient-session.sh "$(session_json "${KWC}" kw_pkg)")"
printf '%s' "${out}" | grep -q 'knowledge-work folder' &&
	bad "orient(kw-pkg): code-mode folder must not emit knowledge confirmation" || ok

# ----- scope.sh: trait predicates + repo-root.sh: profile reader -----
. "${HOOKS}/lib/scope.sh"
. "${HOOKS}/lib/repo-root.sh"

TRAITS_INFRA="$(new_repo traits_infra)"
mkdir -p "${TRAITS_INFRA}/infra"
steer_inject_when_ok has-infra "${TRAITS_INFRA}" && ok || bad "scope: has-infra true when /infra exists"
steer_inject_when_ok has-iac "${TRAITS_INFRA}" && ok || bad "scope: has-iac true when /infra exists"
steer_inject_when_ok has-apps "${TRAITS_INFRA}" && bad "scope: has-apps false for infra repo" || ok

TRAITS_ANSIBLE="$(new_repo traits_ansible)"
printf 'x\n' >"${TRAITS_ANSIBLE}/ansible.cfg"
steer_inject_when_ok has-iac "${TRAITS_ANSIBLE}" && ok || bad "scope: has-iac true for root ansible.cfg"
steer_inject_when_ok has-infra "${TRAITS_ANSIBLE}" && bad "scope: has-infra false without /infra dir" || ok

TRAITS_TF="$(new_repo traits_tf)"
printf 'terraform {}\n' >"${TRAITS_TF}/main.tf"
steer_inject_when_ok has-iac "${TRAITS_TF}" && ok || bad "scope: has-iac true for root *.tf"

TRAITS_APP="$(new_repo traits_app)"
printf '{}\n' >"${TRAITS_APP}/package.json"
printf 'services:\n' >"${TRAITS_APP}/compose.yaml"
steer_inject_when_ok has-apps "${TRAITS_APP}" && ok || bad "scope: has-apps true with package.json"
steer_inject_when_ok has-compose "${TRAITS_APP}" && ok || bad "scope: has-compose true with compose.yaml"
steer_inject_when_ok has-iac "${TRAITS_APP}" && bad "scope: has-iac false for plain app repo" || ok

# tracker-github matches the WORD github (`github\b`, #339), never a value that
# merely starts with it — `system: githubbish` is not a GitHub tracker.
TRAITS_GHISH="$(new_repo traits_ghish)"
mkdir -p "${TRAITS_GHISH}/spec"
printf 'system: githubbish\n' >"${TRAITS_GHISH}/spec/tracker.md"
steer_tracker_is_github "${TRAITS_GHISH}" && bad "scope: tracker-github must reject system: githubbish" || ok
TRAITS_GH="$(new_repo traits_gh)"
mkdir -p "${TRAITS_GH}/spec"
printf 'system: github\n' >"${TRAITS_GH}/spec/tracker.md"
steer_tracker_is_github "${TRAITS_GH}" && ok || bad "scope: tracker-github true for system: github"

# OR markers (token|token): inject when ANY arm holds.
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_APP}" && ok || bad "scope: OR marker true via has-apps arm"
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_INFRA}" && ok || bad "scope: OR marker true via has-iac arm"
TRAITS_OR_NONE="$(new_repo traits_or_none)"
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_OR_NONE}" && bad "scope: OR marker false when no arm holds" || ok

# work-mode classifier: non-git + no markers -> knowledge; git or any code marker
# -> code; fail-safe defaults to code. /spec is deliberately NOT a code marker.
WM_KW="${WORK}/wm_kw"
mkdir -p "${WM_KW}"
printf 'x\n' >"${WM_KW}/doc.md"
assert_eq "work_mode: bare non-git folder -> knowledge" "$(steer_work_mode "${WM_KW}")" "knowledge"
WM_SPEC="${WORK}/wm_spec"
mkdir -p "${WM_SPEC}/spec"
printf 'x\n' >"${WM_SPEC}/spec/intent.md"
assert_eq "work_mode: /spec is not a code marker -> knowledge" "$(steer_work_mode "${WM_SPEC}")" "knowledge"
WM_PKG="${WORK}/wm_pkg"
mkdir -p "${WM_PKG}"
printf '{}\n' >"${WM_PKG}/package.json"
assert_eq "work_mode: package.json -> code" "$(steer_work_mode "${WM_PKG}")" "code"
WM_TF="${WORK}/wm_tf"
mkdir -p "${WM_TF}"
printf 'terraform {}\n' >"${WM_TF}/main.tf"
assert_eq "work_mode: *.tf -> code" "$(steer_work_mode "${WM_TF}")" "code"
# Loose source file with NO manifest must still read as code (fail-safe — a
# manifest-only scan would mis-classify a non-git script folder as knowledge).
WM_SRC="${WORK}/wm_src"
mkdir -p "${WM_SRC}"
printf 'print(1)\n' >"${WM_SRC}/run.py"
assert_eq "work_mode: loose source, no manifest -> code" "$(steer_work_mode "${WM_SRC}")" "code"
WM_GIT="$(new_repo wm_git)"
assert_eq "work_mode: git repo -> code" "$(steer_work_mode "${WM_GIT}")" "code"
WM_SUB="${WM_GIT}/apps/web"
mkdir -p "${WM_SUB}"
assert_eq "work_mode: subdir of git repo -> code" "$(steer_work_mode "${WM_SUB}")" "code"
# code-project predicate is always true at the predicate layer (knowledge folders
# skip marked rules in the inject loop before this runs, so it only fires in code).
steer_inject_when_ok code-project "${WM_GIT}" && ok || bad "scope: code-project predicate true"

# profile reader: marker -> value; absent -> app (back-compat).
PROF_INFRA="$(new_repo prof_infra)"
printf '## Profile\n<!-- steer:profile=infra -->\n' >"${PROF_INFRA}/CLAUDE.md"
assert_eq "profile: marker=infra" "$(steer_repo_profile "${PROF_INFRA}")" "infra"
PROF_NONE="$(new_repo prof_none)"
assert_eq "profile: no CLAUDE.md -> app" "$(steer_repo_profile "${PROF_NONE}")" "app"
PROF_BARE="$(new_repo prof_bare)"
printf '# title\n' >"${PROF_BARE}/CLAUDE.md"
assert_eq "profile: CLAUDE.md without marker -> app" "$(steer_repo_profile "${PROF_BARE}")" "app"

# --- check-graduation.sh: solo-trunk graduation detector (SessionStart) ---
# Fires only in solo-trunk AND when a local signal is present; silent otherwise.

# solo-trunk + a prod branch -> nudge (real git repo so show-ref resolves the ref).
GRAD_PROD="$(git_repo grad_prod main)"
git -C "${GRAD_PROD}" branch prod >/dev/null 2>&1
claude_md_mode "${GRAD_PROD}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_PROD}" sg1)")"
assert_has "graduation: solo-trunk + prod branch nudges" "${out}" "graduate"

# solo-trunk + infra/ tree -> nudge.
GRAD_INFRA="$(new_repo grad_infra)"
mkdir -p "${GRAD_INFRA}/infra"
claude_md_mode "${GRAD_INFRA}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_INFRA}" sg2)")"
assert_has "graduation: solo-trunk + infra/ nudges" "${out}" "graduate"

# solo-trunk + a deploy workflow -> nudge.
GRAD_DEPLOY="$(new_repo grad_deploy)"
mkdir -p "${GRAD_DEPLOY}/.github/workflows"
printf 'name: deploy\n' >"${GRAD_DEPLOY}/.github/workflows/deploy.yml"
claude_md_mode "${GRAD_DEPLOY}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_DEPLOY}" sg3)")"
assert_has "graduation: solo-trunk + deploy workflow nudges" "${out}" "graduate"

# solo-trunk with no signal -> silent (a fresh pre-MVP repo gets zero noise).
GRAD_NONE="$(new_repo grad_none)"
claude_md_mode "${GRAD_NONE}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_NONE}" sg4)")"
assert_empty "graduation: solo-trunk + no signal silent" "${out}"

# pr-flow with a signal -> silent (already graduated; mode gate wins).
GRAD_PRFLOW="$(new_repo grad_prflow)"
mkdir -p "${GRAD_PRFLOW}/infra"
claude_md_mode "${GRAD_PRFLOW}" pr-flow
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_PRFLOW}" sg5)")"
assert_empty "graduation: pr-flow silent despite signal" "${out}"

# cwd not inside a repo -> silent (no root to anchor on).
GRAD_NOREPO="${WORK}/grad_norepo"
mkdir -p "${GRAD_NOREPO}"
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_NOREPO}" sg6)")"
assert_empty "graduation: no repo silent" "${out}"

# --- trunk-push graduation gate of check-bash-actions.sh (PreToolUse, Bash) ---
# Signals shared with check-graduation.sh via lib/graduation.sh. "ask" — not
# deny — only when ALL hold: Bash git push + solo-trunk + a graduation signal.

# solo-trunk + infra/ signal + git push -> wrapped ask naming /steer:protect.
TP_HOT="$(new_repo tp_hot)"
mkdir -p "${TP_HOT}/infra"
claude_md_mode "${TP_HOT}" solo-trunk
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp1 'git push origin main')")"
assert_ask "trunk-push: solo-trunk + signal + push asks" "${out}"
assert_has "trunk-push: ask names the graduation path" "${out}" "/steer:protect"

# same repo, copilot target -> flat ask envelope (no hookSpecificOutput).
ENV="STEER_HOOK_TARGET=copilot"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp2 'git push')")"
ENV=""
assert_copilot_ask "trunk-push: copilot flat ask" "${out}"

# compound command (`… && git push`) still matches.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp3 'mise run check && git push')")"
assert_ask "trunk-push: compound command push asks" "${out}"

# `git -C <dir> push` form matches.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4 "git -C ${TP_HOT} push")")"
assert_ask "trunk-push: git -C push asks" "${out}"

# One ask per session+repo: a REPEAT push in the same session downgrades to a
# non-blocking additionalContext reminder (never a second ask), so an
# autonomous run is not stalled on every push.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4b 'git push origin main')")"
assert_ask "trunk-push: first push in fresh session asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4b 'git push origin main')")"
assert_ctx "trunk-push: repeat push same session downgrades to context" "${out}"
printf '%s' "${out}" | grep -q '"permissionDecision"' && bad "trunk-push: repeat push must not re-ask (got: ${out})" || ok
assert_has "trunk-push: repeat reminder still names the graduation path" "${out}" "/steer:protect"

# A NEW session re-asks (the marker is session-keyed, not repo-permanent).
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4c 'git push origin main')")"
assert_ask "trunk-push: new session asks again" "${out}"

# Copilot repeat: the copilot envelope carries decisions only -> silent allow.
ENV="STEER_HOOK_TARGET=copilot"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4d 'git push')")"
assert_copilot_ask "trunk-push: copilot first push flat ask" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4d 'git push')")"
ENV=""
assert_empty "trunk-push: copilot repeat push silent" "${out}"

# non-push git command -> silent (hot-path early exit).
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp5 'git status')")"
assert_empty "trunk-push: non-push git silent" "${out}"

# "push" only as an argument (not the git subcommand) -> silent.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp6 'git commit -m "push the button"')")"
assert_empty "trunk-push: push in message silent" "${out}"

# non-Bash tool -> silent even in the hot repo.
out="$(run_hook check-bash-actions.sh "$(json_write "${TP_HOT}" tp7 src/app.ts 'x')")"
assert_empty "trunk-push: non-Bash tool silent" "${out}"

# solo-trunk with NO signal -> silent (pre-MVP trunk autonomy holds).
TP_FRESH="$(new_repo tp_fresh)"
claude_md_mode "${TP_FRESH}" solo-trunk
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_FRESH}" tp8 'git push origin main')")"
assert_empty "trunk-push: solo-trunk no signal silent" "${out}"

# pr-flow + signal -> silent (branch pushes; the server wall owns the merge gate).
TP_PR="$(new_repo tp_pr)"
mkdir -p "${TP_PR}/infra"
claude_md_mode "${TP_PR}" pr-flow
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_PR}" tp9 'git push -u origin issue/12-x')")"
assert_empty "trunk-push: pr-flow silent despite signal" "${out}"

# no CLAUDE.md marker at all -> pr-flow default -> silent.
TP_BARE="$(new_repo tp_bare)"
mkdir -p "${TP_BARE}/infra"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_BARE}" tp10 'git push')")"
assert_empty "trunk-push: unmarked repo (pr-flow default) silent" "${out}"

# cwd not inside a repo -> silent.
TP_NOREPO="${WORK}/tp_norepo"
mkdir -p "${TP_NOREPO}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_NOREPO}" tp11 'git push')")"
assert_empty "trunk-push: no repo silent" "${out}"

# ---------------------------------------------------------------------------
# check-template-drift.sh — root-anchored spec/template drift detector
# (SessionStart; emits plain markdown wrapped as additionalContext by the harness.
#  Reads cwd from the payload and resolves the work-tree root — issue #270.)
# ---------------------------------------------------------------------------
INTENT_TPL="${PLUGIN}/templates/spec/feature-intent.md"

# (a) an instantiated intent.md missing template headings -> notice fires, names the
#     drifted file and lists a missing section.
TD1="$(new_repo td1)"
mkdir -p "${TD1}/spec/features/f"
printf '# Some feature\n\njust a title, no template sections\n' >"${TD1}/spec/features/f/intent.md"
out="$(run_hook check-template-drift.sh "$(session_json "${TD1}" td1)")"
assert_has "template-drift: drifted intent.md flagged" "${out}" "template drift detected"
assert_has "template-drift: names the drifted file" "${out}" "spec/features/f"
assert_has "template-drift: lists a missing template heading" "${out}" "## Open questions"

# (b) a fully reconciled file (verbatim current template) -> silent.
TD2="$(new_repo td2)"
mkdir -p "${TD2}/spec/features/f"
cp "${INTENT_TPL}" "${TD2}/spec/features/f/intent.md"
out="$(run_hook check-template-drift.sh "$(session_json "${TD2}" td2)")"
assert_empty "template-drift: reconciled intent.md silent" "${out}"

# (c) the placeholder-marked heading (### Q-001 … steer:placeholder) is never
#     reported, even when the file is otherwise empty of headings (TD1 reused).
out="$(run_hook check-template-drift.sh "$(session_json "${TD1}" td1c)")"
printf '%s' "${out}" | grep -q 'Q-001' && bad "template-drift: placeholder heading must not be reported (got: ${out})" || ok

# (d) invocation from a SUBDIRECTORY resolves the repo root -> same drift report as
#     from root (regression: the hook used cwd-relative paths and silently no-op'd).
TD3="$(new_repo td3)"
mkdir -p "${TD3}/spec/features/f" "${TD3}/apps/web"
printf '# Some feature\n\njust a title\n' >"${TD3}/spec/features/f/intent.md"
out="$(run_hook check-template-drift.sh "$(session_json "${TD3}/apps/web" td3)")"
assert_has "template-drift: subdir cwd resolves root and reports drift" "${out}" "## Open questions"

# ---------------------------------------------------------------------------
# session-checks.sh — consolidated SessionStart orchestrator. Sequencing only:
# the five checks stay individually authoritative (tested above); these cases
# pin the orchestration contract — aggregation, separation, silence, rc 0.
# ---------------------------------------------------------------------------

# (a) one fixture tripping TWO checks: spec/ without .version (unmanaged-repo
#     notice) + a title-only feature intent (template-drift report). Both
#     notices must appear in one combined output, in registration order
#     (drift before unmanaged), separated cleanly.
SC1="$(new_repo scBoth)"
mkdir -p "${SC1}/spec/features/f"
printf '# Some feature\n\njust a title\n' >"${SC1}/spec/features/f/intent.md"
out="$(run_hook session-checks.sh "$(session_json "${SC1}" sc1)")"
assert_has "session-checks: aggregates template-drift notice" "${out}" "## Open questions"
assert_has "session-checks: aggregates unmanaged-repo notice" "${out}" "no spec-spine marker"
_drift_pos="$(printf '%s' "${out}" | grep -n 'Open questions' | head -1 | cut -d: -f1)"
_unmgd_pos="$(printf '%s' "${out}" | grep -n 'no spec-spine marker' | head -1 | cut -d: -f1)"
[ "${_drift_pos:-0}" -lt "${_unmgd_pos:-0}" ] && ok ||
	bad "session-checks: registration order preserved (drift at ${_drift_pos:-?}, unmanaged at ${_unmgd_pos:-?})"

# (b) a healthy managed repo -> every check silent -> orchestrator silent, rc 0.
SC2="$(new_repo scClean)"
managed_spine "${SC2}"
out="$(run_hook session-checks.sh "$(session_json "${SC2}" sc2)")"
assert_empty "session-checks: healthy managed repo silent" "${out}"

# (c) rc 0 even when checks emit notices — a notice is context, not a failure.
out="$(run_hook session-checks.sh "$(session_json "${SC1}" sc1c)")"
assert_eq "session-checks: rc 0 with notices" "$(last_rc)" "0"

# (d) hooks.json registers the orchestrator (not the five checks individually)
#     for startup|resume|clear — the consolidation this section exists to pin.
_hj="${HOOKS}/hooks.json"
grep -q 'session-checks\.sh' "${_hj}" && ok || bad "session-checks: registered in hooks.json"
for _solo in check-template-drift check-open-questions check-unmanaged-repo surface-faults check-graduation; do
	grep -q "${_solo}\.sh" "${_hj}" && bad "session-checks: ${_solo}.sh must not be registered directly" || ok
done

printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
