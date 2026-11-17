#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# check-open-questions.sh - structured Q-NNN parser + gate classification
# (SessionStart hook: emits plain markdown, wrapped into additionalContext by
#  the harness - assert on content, not on JSON shape.)
# ---------------------------------------------------------------------------
oq_repo() {
	_r="${WORK}/$1"
	mkdir -p "${_r}/spec/features/$2"
	printf '' >"${_r}/.git"
	printf '%s' "${_r}"
}

# Placeholder-marked seed (the bundled template) must NOT fire on a fresh scaffold.
OQ1="$(oq_repo oq1 seed)"
cp "${PLUGIN}/templates/spec/feature-intent.md" "${OQ1}/spec/features/seed/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ1}" oq1)")"
assert_empty "open-questions: placeholder seed -> silent" "${out}"

# Real open blocking question at intent-approval on a draft feature -> blocks now.
OQ2="$(oq_repo oq2 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - real one\n- status: open\n- impact: blocking\n- required_before: intent-approval\n'
} >"${OQ2}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ2}" oq2)")"
oq_grep "open-questions: open blocking question classified blocking-now" 'block work now' "${out}"

# Resolved question -> not counted -> silent.
OQ3="$(oq_repo oq3 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - done\n- status: resolved\n- impact: blocking\n- required_before: intent-approval\n'
} >"${OQ3}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ3}" oq3)")"
assert_empty "open-questions: resolved question -> silent" "${out}"

# Non-blocking open question -> backlog (fires, classified non-blocking).
OQ4="$(oq_repo oq4 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - later\n- status: open\n- impact: non-blocking\n- required_before: implementation\n'
} >"${OQ4}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ4}" oq4)")"
oq_grep "open-questions: non-blocking question classified backlog" 'non-blocking' "${out}"

# Malformed block (missing status/impact) -> needs-attention, never silently dropped.
OQ5="$(oq_repo oq5 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - broken\n- impact: blocking\n'
} >"${OQ5}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ5}" oq5)")"
oq_grep "open-questions: malformed block flagged" 'malformed' "${out}"

# Blocking question for a LATER gate (production-release) on a draft feature ->
# blocks a later transition, not now (shared lifecycle ordering).
OQ6="$(oq_repo oq6 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - prod\n- status: open\n- impact: blocking\n- required_before: production-release\n'
} >"${OQ6}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ6}" oq6)")"
oq_grep "open-questions: distant gate classified later-transition" 'later transition' "${out}"

# Retired SPEC-QUESTIONS.md present -> migration notice.
OQ7="$(oq_repo oq7 f)"
printf '# questions\n' >"${OQ7}/spec/SPEC-QUESTIONS.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ7}" oq7)")"
oq_grep "open-questions: retired SPEC-QUESTIONS.md migration notice" 'SPEC-QUESTIONS.md' "${out}"

# Legacy `- [ ]` checkbox: the deprecation window is closed - still counted, but
# as its own bucket naming the converter, never as silent non-blocking backlog.
OQ8="$(oq_repo oq8 f)"
printf '> Status: draft\n\n## Open questions\n\n- [ ] a real legacy question\n' >"${OQ8}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ8}" oq8)")"
oq_grep "open-questions: legacy checkbox still detected" 'open question' "${out}"
oq_grep "open-questions: legacy checkbox reported in its own bucket" 'retired `- \[ \]` format' "${out}"
oq_grep "open-questions: legacy checkbox names the converter" '/steer:setup sync' "${out}"
oq_ngrep "open-questions: legacy checkbox no longer counted as backlog" 'non-blocking' "${out}"

# Staleness escalation (STEER_TODAY pins "today" for hermetic age math; sentinel
# created dates make the threshold decision deterministic on any run date).

# Blocking question created long ago, not promoted -> escalated as rotted.
OQ9="$(oq_repo oq9 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - old\n- created: 2000-01-01\n- status: open\n- impact: blocking\n- owner: product\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ9}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ9}" oq9)")"
oq_grep "open-questions: stale blocking question escalated" 'rotted' "${out}"

# Same question but created in the future -> aged negative -> NOT escalated
# (still fires the normal blocking-now notice, just no rot line).
OQ10="$(oq_repo oq10 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - future\n- created: 2099-12-31\n- status: open\n- impact: blocking\n- owner: product\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ10}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ10}" oq10)")"
oq_ngrep "open-questions: fresh question not escalated" 'rotted' "${out}"

# Stale but already promoted (has tracker: ref) -> on someone's plate -> NOT escalated.
OQ11="$(oq_repo oq11 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - promoted\n- created: 2000-01-01\n- status: open\n- impact: blocking\n- owner: product\n- tracker: #42\n'
} >"${OQ11}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ11}" oq11)")"
oq_ngrep "open-questions: promoted stale question not re-escalated" 'rotted' "${out}"

# Missing created: with no usable git (fake .git) -> blame fails open: counted as
# blocking-now, never crashes, no rot line.
OQ12="$(oq_repo oq12 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - no created\n- status: open\n- impact: blocking\n- owner: development\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ12}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ12}" oq12)")"
oq_grep "open-questions: missing-created still counted (blame fail-open)" 'block work now' "${out}"
oq_ngrep "open-questions: missing-created not escalated when git unavailable" 'rotted' "${out}"

# Escalation wording is tracker-aware. On a NON-GitHub tracker the promotion advice
# must not promise a filed `spec-question` issue or an `owners:` auto-assign - there
# is neither - so it names the manual path instead.
oq_stale_repo() {
	_r="$(oq_repo "$1" f)"
	printf 'system: %s\n' "$2" >"${_r}/spec/tracker.md"
	{
		printf '> Status: draft\n\n## Open questions\n\n'
		printf '### Q-001 - old\n- created: 2000-01-01\n- status: open\n- impact: blocking\n- owner: product\n- required_before: intent-approval\n- tracker:\n'
	} >"${_r}/spec/features/f/intent.md"
	printf '%s' "${_r}"
}

OQ13="$(oq_stale_repo oq13 jira)"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ13}" oq13)")"
oq_grep "open-questions: non-GitHub tracker still escalates" 'rotted' "${out}"
oq_ngrep "open-questions: non-GitHub escalation drops the owners-map claim" 'owners:' "${out}"
oq_ngrep "open-questions: non-GitHub escalation drops the spec-question claim" 'spec-question' "${out}"
oq_grep "open-questions: non-GitHub escalation names the manual path" 'promotion is manual' "${out}"
oq_ngrep "open-questions: non-GitHub per-question line drops the owner auto-assign" 'assign its owner' "${out}"
oq_grep "open-questions: non-GitHub per-question line names the tracker ref" 'set its `tracker:` ref' "${out}"

OQ14="$(oq_stale_repo oq14 github)"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ14}" oq14)")"
oq_grep "open-questions: GitHub tracker keeps the owners-map wording" 'owners:' "${out}"
oq_grep "open-questions: GitHub tracker keeps the spec-question wording" 'spec-question' "${out}"
oq_grep "open-questions: GitHub per-question line keeps the owner auto-assign" 'assign its owner' "${out}"

# Non-blocking questions expire too (60d), and sooner (14d) once the feature is live.
oq_nb() { # <name> <feature-status> <created>
	_r="$(oq_repo "$1" f)"
	{
		printf '> Status: %s\n\n## Open questions\n\n' "$2"
		printf '### Q-001 - polish\n- created: %s\n- status: open\n- impact: non-blocking\n- owner: design\n- tracker:\n' "$3"
	} >"${_r}/spec/features/f/intent.md"
	printf '%s' "${_r}"
}
OQ15="$(oq_nb oq15 approved 2026-04-01)"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ15}" oq15)")"
oq_grep "open-questions: non-blocking open 79d escalated" 'rotted' "${out}"
oq_grep "open-questions: stale non-blocking line carries the cue" 'stale: promote' "${out}"
OQ16="$(oq_nb oq16 approved 2026-05-20)"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ16}" oq16)")"
oq_ngrep "open-questions: non-blocking open 30d not escalated" 'rotted' "${out}"
OQ17="$(oq_nb oq17 live 2026-05-20)"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ17}" oq17)")"
oq_grep "open-questions: non-blocking open 30d in a live feature escalated" 'rotted' "${out}"

# A question filled in the template's shape keeps each field's trailing comment,
# so an empty `tracker:` still reads as un-promoted and the question still ages.
OQ17T="$(oq_repo oq17t f)"
{
	printf '> Status: approved\n\n## Open questions\n\n'
	printf '### Q-001 - polish\n- created: 2026-04-01\n- status: open            # open | resolved\n- impact: non-blocking    # blocking | non-blocking\n- owner: design           # product | design\n- tracker:                # issue ref once promoted (e.g. #142), else empty\n'
} >"${OQ17T}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ17T}" oq17t)")"
oq_grep "open-questions: template-commented empty tracker still escalates" 'rotted' "${out}"

# The notice is bounded: one summary line and the top 3, blocking-now first,
# however many questions there are.
OQ18="$(oq_repo oq18 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	for _n in 1 2 3 4 5; do
		printf '### Q-00%s - nb %s\n- created: 2026-06-0%s\n- status: open\n- impact: non-blocking\n- owner: product\n- tracker:\n\n' "${_n}" "${_n}" "${_n}"
	done
	printf '### Q-009 - the blocker\n- created: 2026-06-18\n- status: open\n- impact: blocking\n- owner: product\n- required_before: intent-approval\n- tracker:\n'
} >"${OQ18}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ18}" oq18)")"
oq_grep "open-questions: bounded list says how many it shows" 'Most urgent 3 of 6' "${out}"
assert_eq "open-questions: bounded list names exactly 3" "$(printf '%s\n' "${out}" | grep -c '^- `Q-')" "3"
assert_eq "open-questions: blocking-now ranks first" "$(printf '%s\n' "${out}" | grep '^- `Q-' | head -n 1 | cut -c1-9)" '- `Q-009`'
assert_eq "open-questions: then oldest first" "$(printf '%s\n' "${out}" | grep '^- `Q-' | sed -n 2p | cut -c1-9)" '- `Q-001`'
oq_grep "open-questions: PO-dominated backlog points at the bundle" 'questions bundle' "${out}"

# An access/tooling/decision ask goes to the client whatever its owner, so a
# backlog of dev-owned `kind: access` questions still points at the bundle.
OQ18K="$(oq_repo oq18k f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	for _n in 1 2 3; do
		printf '### Q-00%s - grant %s\n- created: 2026-06-0%s\n- status: open\n- impact: non-blocking\n- owner: development\n- kind: access\n- tracker:\n\n' "${_n}" "${_n}" "${_n}"
	done
} >"${OQ18K}/spec/features/f/intent.md"
out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ18K}" oq18k)")"
oq_grep "open-questions: client-facing kinds point at the bundle" 'questions bundle' "${out}"
oq_ngrep "open-questions: no per-file listing" 'spec/features/f/intent.md` -' "${out}"

# Unowned-dominated backlog points at triage.
OQ19="$(oq_repo oq19 f)"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 - who knows\n- status: open\n- impact: non-blocking\n- owner:\n- tracker:\n'
} >"${OQ19}/spec/features/f/intent.md"
out="$(run_hook check-open-questions.sh "$(session_json "${OQ19}" oq19)")"
oq_grep "open-questions: unowned backlog points at triage" 'no `owner:`' "${out}"
oq_grep "open-questions: unowned question shown as such" 'no owner' "${out}"

if command -v git >/dev/null 2>&1; then
	# An undated question is aged from ONE whole-file blame of its heading line.
	OQ20="${WORK}/oq20"
	mkdir -p "${OQ20}/spec/features/f"
	git -C "${OQ20}" init -q
	{
		printf '> Status: draft\n\n## Open questions\n\n'
		printf '### Q-001 - undated\n- status: open\n- impact: non-blocking\n- owner: product\n- tracker:\n'
	} >"${OQ20}/spec/features/f/intent.md"
	git -C "${OQ20}" add -A
	GIT_AUTHOR_DATE='2026-01-01T12:00:00Z' GIT_COMMITTER_DATE='2026-01-01T12:00:00Z' \
		git -C "${OQ20}" -c user.name=t -c user.email=t@t commit -qm seed
	out="$(ENV='STEER_TODAY=2026-06-19' run_hook check-open-questions.sh "$(session_json "${OQ20}" oq20)")"
	oq_grep "open-questions: undated question aged from git blame" 'open 169d' "${out}"
	oq_grep "open-questions: blame-aged non-blocking escalates" 'rotted' "${out}"

	# convert-legacy-questions.sh - the ledger's converter.
	CV="${WORK}/cv"
	mkdir -p "${CV}/spec/features/f"
	git -C "${CV}" init -q
	{
		printf '# F\n> Status: approved\n\n## PO acceptance\n\n- [ ] PO reviewed this intent\n\n'
		printf '## Open questions\n\n- [ ] When is the cache\n  recomputed? It drives billing.\n- [ ] [placeholder]\n- [x] answered\n\n'
		printf '### Q-003 - kept\n- status: open\n- impact: blocking\n- [ ] sub-task of Q-003\n'
	} >"${CV}/spec/features/f/intent.md"
	git -C "${CV}" add -A
	GIT_AUTHOR_DATE='2026-03-04T12:00:00Z' GIT_COMMITTER_DATE='2026-03-04T12:00:00Z' \
		git -C "${CV}" -c user.name=t -c user.email=t@t commit -qm seed
	_cvf="${CV}/spec/features/f/intent.md"
	run_sh "${PLUGIN}/scripts/convert-legacy-questions.sh" --list "${CV}"
	assert_eq "convert: --list names only the in-scope item" "${out}" 'spec/features/f/intent.md:10: When is the cache'
	run_sh "${PLUGIN}/scripts/convert-legacy-questions.sh" "${CV}"
	oq_grep "convert: default mode proposes a diff" '^+### Q-004 - When is the cache recomputed?' "${out}"
	grep -q '^- \[ \] When is the cache' "${_cvf}" && ok || bad "convert: default mode writes nothing"
	run_sh "${PLUGIN}/scripts/convert-legacy-questions.sh" --apply "${CV}"
	grep -q '^### Q-004 - When is the cache recomputed?$' "${_cvf}" && ok || bad "convert: id continues past the highest"
	grep -q '^- created: 2026-03-04$' "${_cvf}" && ok || bad "convert: created: from the checkbox line's commit"
	grep -q '^It drives billing\.$' "${_cvf}" && ok || bad "convert: text after the question kept as context"
	grep -q '^- \[ \] PO reviewed this intent$' "${_cvf}" && ok || bad "convert: PO acceptance gate untouched"
	grep -q '^- \[ \] sub-task of Q-003$' "${_cvf}" && ok || bad "convert: in-block sub-task untouched"
	grep -q '^- \[x\] answered$' "${_cvf}" && ok || bad "convert: checked item untouched"
	run_sh "${PLUGIN}/scripts/convert-legacy-questions.sh" --list "${CV}"
	assert_empty "convert: idempotent once applied" "${out}"
else
	printf 'SKIP: git unavailable, open-question blame + converter tests skipped\n' >&2
fi

finish
