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
PASS=0
FAIL=0

pin() { printf '%s:%s' "$1" "$2"; } # pin postgres 11 -> the matchable token

run_hook() { # <hook-file> <stdin>   (env via $ENV)
	# SC2086: ${ENV:-} is deliberately unquoted so "KEY=val KEY2=val2" splits into
	# separate env assignments; quoting it would pass one bogus assignment.
	# shellcheck disable=SC2086
	printf '%s' "$2" | env ${ENV:-} sh "${HOOKS}/$1" 2>/dev/null
}

ok() { PASS=$((PASS + 1)); }
bad() {
	FAIL=$((FAIL + 1))
	printf 'FAIL: %s\n' "$1" >&2
}

assert_empty() { [ -z "$2" ] && ok || bad "$1 (expected silent, got: $2)"; }
assert_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && ok || bad "$1 (expected deny, got: $2)"; }
assert_no_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && bad "$1 (unexpected deny: $2)" || ok; }
# Copilot preToolUse envelope: a flat decision object (no hookSpecificOutput wrapper).
assert_copilot_ask() {
	printf '%s' "$2" | grep -q '"permissionDecision":"ask"' &&
		! printf '%s' "$2" | grep -q 'hookSpecificOutput' && ok ||
		bad "$1 (expected flat copilot ask, got: $2)"
}
assert_ctx() { printf '%s' "$2" | grep -q '"additionalContext"' && ok || bad "$1 (expected additionalContext, got: $2)"; }
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

# --- check-code-before-spec.sh (no /spec spine) ---
# Two dimensions (issue #171): the /spec SPINE nudge fires once per session+repo;
# the SCAFFOLD nudge is sticky — it re-fires on each NEW feature file while the
# repo has no root mise.toml, and self-clears the moment a mise.toml exists.
unset ENV
R1="$(new_repo repoA)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: first code write nudges" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "spec-before-code: first write carries scaffold clause (${out})"
printf '%s' "${out}" | grep -q 'Spec-first check' && ok || bad "spec-before-code: first write carries spine clause (${out})"

# Second DISTINCT file, same session+repo, still no mise.toml: spine fired once
# already, but the SCAFFOLD nudge re-fires — and ONLY the scaffold clause.
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1}" sA src/other.ts 'y')")"
assert_ctx "spec-before-code: new file re-fires scaffold nudge" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "spec-before-code: re-fire carries scaffold clause (${out})"
printf '%s' "${out}" | grep -q 'Spec-first check' && bad "spec-before-code: spine clause must NOT repeat (${out})" || ok

# SAME file written again → no dimension due → silent (scaffold dedup, never nag).
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1}" sA src/other.ts 'y2')")"
assert_empty "spec-before-code: same file again is silent (scaffold dedup)" "${out}"

# Root mise.toml present (scaffold landed) but no spine: the SPINE nudge fires
# once, the SCAFFOLD dimension stays silent — proving the sticky nudge self-clears.
R1b="$(new_repo repoAmise)"
printf '[tools]\n' >"${R1b}/mise.toml"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1b}" sAm src/app.ts 'x')")"
assert_ctx "spec-before-code: scaffold present still nudges spine" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && bad "spec-before-code: no scaffold clause once mise.toml present (${out})" || ok
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1b}" sAm src/other.ts 'y')")"
assert_empty "spec-before-code: scaffold present + spine fired -> later files silent" "${out}"

# Writing mise.toml IS the act of scaffolding — never scaffold-nudge that write.
R1c="$(new_repo repoAmk)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1c}" sMk src/app.ts 'x')")"
assert_ctx "spec-before-code: prime spine nudge before mise.toml write" "${out}"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R1c}" sMk mise.toml '[tools]')")"
assert_empty "spec-before-code: writing mise.toml is not scaffold-nudged" "${out}"

R2="$(new_repo repoB)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R2}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: second repo, same session, nudges" "${out}"

R3="$(new_repo repoC)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R3}" sC compose.yaml 'services: {}')")"
assert_ctx "spec-before-code: operations write nudges" "${out}"

R4="$(new_repo repoD)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R4}" sD README.md '# hi')")"
assert_empty "spec-before-code: docs exempt" "${out}"

# Bare spec/ (no .version) is NOT a managed spine — must still nudge (foreign),
# per the spec/.version predicate. An empty/foreign/partial spec/ no longer
# silences the spec-first nudge.
R5="$(new_repo repoE)"
mkdir -p "${R5}/spec"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R5}" sE src/app.ts 'x')")"
assert_ctx "spec-before-code: bare spec/ without .version still nudges" "${out}"

# Complete, version-stamped spine -> managed -> silent.
R5b="$(new_repo repoEok)"
managed_spine "${R5b}"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R5b}" sEok src/app.ts 'x')")"
assert_empty "spec-before-code: complete .version spine -> silent" "${out}"

# .version present but a spine file missing -> damaged -> nudge.
R5c="$(new_repo repoEdmg)"
mkdir -p "${R5c}/spec"
printf '1.0.0\n' >"${R5c}/spec/.version"
printf 'x\n' >"${R5c}/spec/vision.md"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R5c}" sEdmg src/app.ts 'x')")"
assert_ctx "spec-before-code: damaged spine (missing files) nudges" "${out}"

# NotebookEdit (notebook_path) is governed like an ordinary code write.
R5n="$(new_repo repoEnb)"
out="$(run_hook check-code-before-spec.sh "$(json_notebook "${R5n}" sEnb analysis.ipynb)")"
assert_ctx "spec-before-code: NotebookEdit write nudges" "${out}"

# Invocation from a SUBDIRECTORY resolves the repo root (cwd may be apps/web).
R5s="$(new_repo repoEsub)"
mkdir -p "${R5s}/apps/web/src"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R5s}/apps/web" sEsub src/app.ts 'x')")"
assert_ctx "spec-before-code: subdir cwd resolves root and nudges" "${out}"

R6="${WORK}/repoWT"
mkdir -p "${R6}"
printf 'gitdir: /elsewhere\n' >"${R6}/.git"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R6}" sWT src/app.ts 'x')")"
assert_ctx "spec-before-code: .git-as-file worktree engages" "${out}"

R7="$(new_repo repoSpace)"
out="$(run_hook check-code-before-spec.sh "$(json_write "${R7}" sSp 'src/my file.ts' 'x')")"
assert_ctx "spec-before-code: path with spaces" "${out}"

# --- check-issue-before-mutation.sh (GitHub tracker) ---
R8="$(new_repo repoGH)"
mkdir -p "${R8}/spec"
printf 'system: github\n' >"${R8}/spec/tracker.md"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R8}" sGH src/app.ts 'x')")"
assert_ctx "issue-first: github repo code write nudges" "${out}"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R8}" sGH src/two.ts 'x')")"
assert_empty "issue-first: one nudge per session+repo" "${out}"

R9="$(new_repo repoJira)"
mkdir -p "${R9}/spec"
printf 'system: jira\n' >"${R9}/spec/tracker.md"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R9}" sJ src/app.ts 'x')")"
assert_empty "issue-first: non-github tracker silent" "${out}"

R10="$(new_repo repoNoTracker)"
mkdir -p "${R10}/spec"
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R10}" sN src/app.ts 'x')")"
assert_empty "issue-first: no tracker silent" "${out}"

# Solo-trunk mode: issue-first still nudges, but with trunk wording (no /steer:work,
# no issue branch — close the issue from the commit instead).
R8st="$(new_repo repoGHsolo)"
mkdir -p "${R8st}/spec"
printf 'system: github\n' >"${R8st}/spec/tracker.md"
claude_md_mode "${R8st}" solo-trunk
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R8st}" sGHst src/app.ts 'x')")"
assert_ctx "issue-first: solo-trunk repo still nudges" "${out}"
printf '%s' "${out}" | grep -q 'solo-trunk mode' && ok || bad "issue-first: solo-trunk wording present (got: ${out})"
printf '%s' "${out}" | grep -q '/steer:work' && bad "issue-first: solo-trunk must NOT mention /steer:work (got: ${out})" || ok

# PR-flow repo whose CLAUDE.md prose names "solo trunk" still gets PR-flow wording
# — proves the marker matcher is anchored, not a substring of the prose.
R8pf="$(new_repo repoGHpr)"
mkdir -p "${R8pf}/spec"
printf 'system: github\n' >"${R8pf}/spec/tracker.md"
claude_md_mode "${R8pf}" pr-flow
out="$(run_hook check-issue-before-mutation.sh "$(json_write "${R8pf}" sGHpf src/app.ts 'x')")"
assert_ctx "issue-first: pr-flow repo nudges (prose mentions solo trunk)" "${out}"
printf '%s' "${out}" | grep -q '/steer:work' && ok || bad "issue-first: pr-flow keeps /steer:work (got: ${out})"
printf '%s' "${out}" | grep -q 'solo-trunk mode' && bad "issue-first: pr-flow must NOT use solo wording (got: ${out})" || ok

# Plugin-maintenance branch exemption (needs a real git repo for branch detection).
# /steer:sync writes operations-class scaffold on its own feat/sync branch ->
# silent (rule 36 carve-out); app source on feat/sync still nudges.
if command -v git >/dev/null 2>&1; then
	RSY="$(git_repo repoSyncPre feat/sync)"
	out="$(run_hook check-issue-before-mutation.sh "$(json_write "${RSY}" sSY1 compose.yaml 'x')")"
	assert_empty "issue-first: feat/sync operations write exempt" "${out}"
	out="$(run_hook check-issue-before-mutation.sh "$(json_write "${RSY}" sSY2 src/app.ts 'x')")"
	assert_ctx "issue-first: feat/sync app source still nudges" "${out}"
fi

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

out="$(sh "${RECON}" "${RDIR}/existing.md" "${RDIR}/bundled.md" 2>/dev/null)"
rc=$?
assert_rc "reconcile: gaps run exits 0" "${rc}" 0
printf '%s' "${out}" | grep -q '## B' && ok || bad "reconcile: missing heading reported (got: ${out})"
printf '%s' "${out}" | grep -q -- '- \[ \] two' && ok || bad "reconcile: missing checklist item reported (got: ${out})"
printf '%s' "${out}" | grep -q '## A' && bad "reconcile: shared anchor wrongly reported (got: ${out})" || ok

# identical anchors -> file already current -> silent
out="$(sh "${RECON}" "${RDIR}/bundled.md" "${RDIR}/bundled.md" 2>/dev/null)"
rc=$?
assert_rc "reconcile: current run exits 0" "${rc}" 0
assert_empty "reconcile: current file -> silent" "${out}"

# checkbox state normalized: [x] in existing vs [ ] in bundled is NOT a diff
printf '## A\n- [x] one\n' >"${RDIR}/checked.md"
printf '## A\n- [ ] one\n' >"${RDIR}/unchecked.md"
out="$(sh "${RECON}" "${RDIR}/checked.md" "${RDIR}/unchecked.md" 2>/dev/null)"
rc=$?
assert_rc "reconcile: checkbox-normalization exits 0" "${rc}" 0
assert_empty "reconcile: [x] vs [ ] not reported" "${out}"

# usage + unreadable inputs
out="$(sh "${RECON}" "${RDIR}/existing.md" 2>/dev/null)"
rc=$?
assert_rc "reconcile: wrong arg count -> exit 2" "${rc}" 2
out="$(sh "${RECON}" "${RDIR}/nope.md" "${RDIR}/bundled.md" 2>/dev/null)"
rc=$?
assert_rc "reconcile: unreadable input -> exit 3" "${rc}" 3

# ---------------------------------------------------------------------------
# scripts/scan-capabilities.sh — read-only capability detector (not a hook)
# ---------------------------------------------------------------------------
CAPSCAN="${PLUGIN}/scripts/scan-capabilities.sh"
CAPS_MD="${PLUGIN}/templates/reference/CAPABILITIES.md"
capscan() { out="$(sh "${CAPSCAN}" "$1" "${PLUGIN}" 2>/dev/null)"; }
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

# OR markers (token|token): inject when ANY arm holds.
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_APP}" && ok || bad "scope: OR marker true via has-apps arm"
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_INFRA}" && ok || bad "scope: OR marker true via has-iac arm"
TRAITS_OR_NONE="$(new_repo traits_or_none)"
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_OR_NONE}" && bad "scope: OR marker false when no arm holds" || ok

# profile reader: marker -> value; absent -> app (back-compat).
PROF_INFRA="$(new_repo prof_infra)"
printf '## Profile\n<!-- steer:profile=infra -->\n' >"${PROF_INFRA}/CLAUDE.md"
assert_eq "profile: marker=infra" "$(steer_repo_profile "${PROF_INFRA}")" "infra"
PROF_NONE="$(new_repo prof_none)"
assert_eq "profile: no CLAUDE.md -> app" "$(steer_repo_profile "${PROF_NONE}")" "app"
PROF_BARE="$(new_repo prof_bare)"
printf '# title\n' >"${PROF_BARE}/CLAUDE.md"
assert_eq "profile: CLAUDE.md without marker -> app" "$(steer_repo_profile "${PROF_BARE}")" "app"

printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
