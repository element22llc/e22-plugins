#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- spec/scaffold dimension of check-write-nudges.sh (no /spec spine) ---
# Two dimensions (issue #171): the /spec SPINE nudge fires once per session+repo;
# the SCAFFOLD nudge is sticky - it re-fires on each NEW feature file while the
# repo has no root mise.toml, and self-clears the moment a mise.toml exists.
unset ENV
R1="$(new_repo repoA)"
out="$(run_hook check-write-nudges.sh "$(json_write "${R1}" sA src/app.ts 'x')")"
assert_ctx "spec-before-code: first code write nudges" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "spec-before-code: first write carries scaffold clause (${out})"
printf '%s' "${out}" | grep -q 'Spec-first check' && ok || bad "spec-before-code: first write carries spine clause (${out})"

# A worktree under .claude/worktrees/ is a repo of its own: the ancestor .claude/
# must not classify its code as spec (which would exempt it from every nudge).
RW="${WORK}/host/.claude/worktrees/wt"
mkdir -p "${RW}" && git -C "${RW}" init -q
out="$(run_hook check-write-nudges.sh "$(json_write "${RW}" sW "${RW}/src/app.ts" 'x')")"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "write-nudges: a worktree under .claude/ still nudges (${out})"

# Second DISTINCT file, same session+repo, still no mise.toml: spine fired once
# already, but the SCAFFOLD nudge re-fires - and ONLY the scaffold clause.
out="$(run_hook check-write-nudges.sh "$(json_write "${R1}" sA src/other.ts 'y')")"
assert_ctx "spec-before-code: new file re-fires scaffold nudge" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && ok || bad "spec-before-code: re-fire carries scaffold clause (${out})"
printf '%s' "${out}" | grep -q 'Spec-first check' && bad "spec-before-code: spine clause must NOT repeat (${out})" || ok

# SAME file written again -> no dimension due -> silent (scaffold dedup, never nag).
out="$(run_hook check-write-nudges.sh "$(json_write "${R1}" sA src/other.ts 'y2')")"
assert_empty "spec-before-code: same file again is silent (scaffold dedup)" "${out}"

# Root mise.toml present (scaffold landed) but no spine: the SPINE nudge fires
# once, the SCAFFOLD dimension stays silent - proving the sticky nudge self-clears.
R1b="$(new_repo repoAmise)"
printf '[tools]\n' >"${R1b}/mise.toml"
out="$(run_hook check-write-nudges.sh "$(json_write "${R1b}" sAm src/app.ts 'x')")"
assert_ctx "spec-before-code: scaffold present still nudges spine" "${out}"
printf '%s' "${out}" | grep -q 'Scaffold check' && bad "spec-before-code: no scaffold clause once mise.toml present (${out})" || ok
out="$(run_hook check-write-nudges.sh "$(json_write "${R1b}" sAm src/other.ts 'y')")"
assert_empty "spec-before-code: scaffold present + spine fired -> later files silent" "${out}"

# Writing mise.toml IS the act of scaffolding - never scaffold-nudge that write.
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

# Bare spec/ (no .version) is NOT a managed spine - must still nudge (foreign),
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

# A declared guest (advisory mode) gets neither nudge: both re-assert rules
# advisory omits (bootstrap, issue-first), so a code write stays silent.
R7a="$(new_repo repoAdv)"
mkdir -p "${R7a}/.claude"
printf '{ "env": { "STEER_MODE": "advisory" } }\n' >"${R7a}/.claude/settings.local.json"
out="$(run_hook check-write-nudges.sh "$(json_write "${R7a}" sAdv src/app.ts 'x')")"
assert_empty "write-nudges(adv): unmanaged guest repo gets no bootstrap nudge" "${out}"
R7b="$(new_repo repoAdvGH)"
bootstrapped_repo "${R7b}"
mkdir -p "${R7b}/.claude"
printf '{ "env": { "STEER_MODE": "advisory" } }\n' >"${R7b}/.claude/settings.local.json"
out="$(run_hook check-write-nudges.sh "$(json_write "${R7b}" sAdvGH src/app.ts 'x')")"
assert_empty "write-nudges(adv): github-tracker guest repo gets no issue-first nudge" "${out}"

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
# dimension legitimately reports the incomplete spec/ here - that is nudge 1's
# job - so assert the absence of the issue nudge, not total silence.)
R10="$(new_repo repoNoTracker)"
mkdir -p "${R10}/spec"
out="$(run_hook check-write-nudges.sh "$(json_write "${R10}" sN src/app.ts 'x')")"
printf '%s' "${out}" | grep -q 'Issue-first' && bad "issue-first: no tracker must not issue-nudge (got: ${out})" || ok

# Solo-trunk mode: issue-first still nudges, but with trunk wording (no /steer:work,
# no issue branch - close the issue from the commit instead).
R8st="$(new_repo repoGHsolo)"
bootstrapped_repo "${R8st}"
claude_md_mode "${R8st}" solo-trunk
out="$(run_hook check-write-nudges.sh "$(json_write "${R8st}" sGHst src/app.ts 'x')")"
assert_ctx "issue-first: solo-trunk repo still nudges" "${out}"
printf '%s' "${out}" | grep -q 'solo-trunk mode' && ok || bad "issue-first: solo-trunk wording present (got: ${out})"
printf '%s' "${out}" | grep -q '/steer:work' && bad "issue-first: solo-trunk must NOT mention /steer:work (got: ${out})" || ok

# PR-flow repo whose CLAUDE.md prose names "solo trunk" still gets PR-flow wording
# - proves the marker matcher is anchored, not a substring of the prose.
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

	# Hotfix fast-path exemption (rule 61): app source on a hotfix/<n> branch is the
	# sanctioned after-the-fact lane -> silent at the point of action (the issue is
	# filed in the post-incident follow-up).
	RHF="$(git_repo repoHotfixPre hotfix/42-outage)"
	bootstrapped_repo "${RHF}"
	out="$(run_hook check-write-nudges.sh "$(json_write "${RHF}" sHF1 src/app.ts 'x')")"
	assert_empty "issue-first: hotfix branch app source exempt" "${out}"
fi

# ----- the nudge text names the tracker the repo actually has -----
# The issue-first nudge enforces a named file; naming one the repo does not have
# teaches the reader the wrong location.
WN_OS="$(new_repo wn_os)"
mkdir -p "${WN_OS}/openspec/changes" "${WN_OS}/openspec/steer" "${WN_OS}/src"
printf 'system: github\n' >"${WN_OS}/openspec/steer/tracker.md"
out="$(run_hook check-write-nudges.sh "$(json_write "${WN_OS}" wnos1 src/app.ts 'x')")"
oq_grep "nudge: openspec repo's issue-first text names the namespaced tracker" 'openspec/steer/tracker.md' "${out}"
printf '%s' "${out}" | grep -q "repo's /spec/tracker.md" &&
	bad "nudge: openspec repo must not be told its tracker is /spec/tracker.md" || ok

# A COMPLETE openspec spine must not trigger the spine dimension - it would tell
# an OpenSpec repo it has "no /spec spine" and push /steer:init at write time.
printf '%s' "${out}" | grep -q 'no /spec spine' &&
	bad "nudge: complete openspec spine must not get the no-spine bootstrap nudge" || ok
# The scaffold dimension still fires (no root mise.toml) and SHOULD - the
# toolchain applies here too. What must not appear is the imperative "Run
# /steer:setup"; naming it inside the explicit warn-off sentence is the point.
printf '%s' "${out}" | grep -q 'Run /steer:setup:' &&
	bad "nudge: openspec repo must never be told to Run /steer:setup" || ok
oq_grep "nudge: openspec scaffold text warns off the bootstrap modes" 'do not run /steer:setup init or /steer:setup adopt' "${out}"

# The native repo keeps the native text.
WN_NAT="$(new_repo wn_nat)"
mkdir -p "${WN_NAT}/spec" "${WN_NAT}/src"
printf 'system: github\n' >"${WN_NAT}/spec/tracker.md"
out="$(run_hook check-write-nudges.sh "$(json_write "${WN_NAT}" wnnat1 src/app.ts 'x')")"
oq_grep "nudge: native repo's issue-first text names spec/tracker.md" 'spec/tracker.md' "${out}"

finish
