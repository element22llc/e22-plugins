#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

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

	# H: marker-first - a non-issue branch with a spec/.work/<branch> marker is
	# governed via the marker even though its name carries no issue number.
	S8="$(git_repo stopMarker main)"
	git -C "${S8}" checkout -q -b prototype-x
	mkdir -p "${S8}/spec/.work"
	: >"${S8}/spec/.work/prototype-x"
	mkdir -p "${S8}/src"
	printf 'x\n' >"${S8}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S8}" stS8)")"
	assert_no_block "stop-reconcile: spec/.work marker governs non-issue branch" "${out}"

	# I: .md marker governs via slash->underscore key AND the current session is
	# stamped at the head of the session list, preserving the issue:/branch: header
	# and the prior session id.
	S9="$(git_repo stopMdMarker main)"
	git -C "${S9}" checkout -q -b proto/x
	mkdir -p "${S9}/spec/.work"
	MD9="${S9}/spec/.work/proto_x.md"
	printf '# Work marker - issue 123\n\n- issue: 123\n- branch: proto/x\n\n## Claude Code sessions (newest first)\n\n- sess-old-0002\n' >"${MD9}"
	mkdir -p "${S9}/src"
	printf 'x\n' >"${S9}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S9}" sess-new-0001)")"
	assert_no_block "stop-reconcile: .md marker governs (slash->underscore key)" "${out}"
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
	printf '# Work marker - issue 7\n\n- issue: 7\n- branch: proto2/x\n\n## Claude Code sessions (newest first)\n\n- sess-old-0003\n' >"${MD10}"
	cp "${MD10}" "${MD10}.before"
	mkdir -p "${S10}/src"
	printf 'x\n' >"${S10}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S10}" '')")"
	assert_no_block "stop-reconcile: .md marker governs with empty session id" "${out}"
	cmp -s "${MD10}" "${MD10}.before" && ok || bad "stop-reconcile: empty session id leaves .md marker intact"

	# L: solo-trunk mode - a governed change on main is STILL surfaced (issue-first
	# holds), but with trunk wording: reference the issue in the commit, no /steer:work.
	S11="$(git_repo stopSolo main)"
	claude_md_mode "${S11}" solo-trunk
	mkdir -p "${S11}/src"
	printf 'export const x = 1\n' >"${S11}/src/app.ts"
	out="$(run_hook reconcile-issue-first.sh "$(stop_json "${S11}" stS11)")"
	assert_block "stop-reconcile: solo-trunk governed change on main still surfaced" "${out}"
	printf '%s' "${out}" | grep -q 'solo-trunk mode' && ok || bad "stop-reconcile: solo-trunk wording present (got: ${out})"
	printf '%s' "${out}" | grep -q '/steer:work' && bad "stop-reconcile: solo-trunk must NOT mention /steer:work (got: ${out})" || ok

	# M: solo-trunk advisory is independent of any prior committed issue ref - the
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

	# Q: hotfix fast-path (rule 61). A governed change on a hotfix/<n> branch files
	# its issue after-the-fact by design, so it still surfaces a one-time advisory
	# but REFRAMED as the mandatory post-incident follow-up - never the standard
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

finish
