#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# remove-question-seeds.sh + the scaffold's ci-spec.sh gate share one rule: an
# unfilled seed goes once its feature is past draft or has a real question.
SEED="${PLUGIN}/templates/spec/feature-intent.md"
SD="${WORK}/seeds"
mkdir -p "${SD}/spec/features/done" "${SD}/spec/features/fresh" "${SD}/spec/features/mixed"
printf '' >"${SD}/.git"
sed 's/^> Status: draft | approved | live$/> Status: approved/' "${SEED}" >"${SD}/spec/features/done/intent.md"
sed 's/^> Status: draft | approved | live$/> Status: draft/' "${SEED}" >"${SD}/spec/features/fresh/intent.md"
{
	sed 's/^> Status: draft | approved | live$/> Status: draft/' "${SEED}"
	printf '\n### Q-002 - real\n\n- status: open\n- impact: non-blocking\n'
} >"${SD}/spec/features/mixed/intent.md"
grep -q '^> Status: approved$' "${SD}/spec/features/done/intent.md" && ok || bad "seeds: fixture Status rewrite (template header changed?)"
run_sh "${PLUGIN}/scripts/remove-question-seeds.sh" --list "${SD}"
oq_grep "seeds: approved feature's seed listed" 'spec/features/done/intent.md:[0-9]*: Q-001' "${out}"
oq_grep "seeds: seed beside a real question listed" 'spec/features/mixed/intent.md' "${out}"
oq_ngrep "seeds: a draft's lone seed is still the example" 'features/fresh' "${out}"
run_sh "${PLUGIN}/scripts/remove-question-seeds.sh" --apply "${SD}"
grep -q 'steer:placeholder -->$' "${SD}/spec/features/done/intent.md" && bad "seeds: approved seed removed" || ok
grep -q '_Resolution:_ recorded here' "${SD}/spec/features/done/intent.md" && bad "seeds: seed's _Resolution:_ line removed with it" || ok
grep -q '^### Q-002 - real$' "${SD}/spec/features/mixed/intent.md" && ok || bad "seeds: real question kept"
grep -q 'steer:placeholder -->$' "${SD}/spec/features/fresh/intent.md" && ok || bad "seeds: draft seed kept"
assert_eq "seeds: no double blank lines left at the cut" "$(awk 'prev == "" && $0 == "" { n++ } { prev = $0 } END { print n + 0 }' "${SD}/spec/features/done/intent.md")" "0"
run_sh "${PLUGIN}/scripts/remove-question-seeds.sh" --list "${SD}"
assert_empty "seeds: idempotent once applied" "${out}"
# A seed from before the ASCII sweep (em dash separator) still qualifies; one
# with a human's line in it, or the marker on a real title, is refused.
SD2="${WORK}/seeds2"
mkdir -p "${SD2}/spec/features/dash" "${SD2}/spec/features/extra" "${SD2}/spec/features/real"
printf '' >"${SD2}/.git"
sd2() { # <feature> <heading-separator> <extra-line>
	{
		printf '> Status: approved\n\n## Open questions\n\n'
		printf '### Q-001 %s [Anything ambiguous the PO needs to decide] <!-- steer:placeholder -->\n\n' "$2"
		printf -- '- status: open            # open | investigating\n- impact: blocking\n%s\n' "$3"
		printf '_Resolution:_ recorded here when answered, then folded into the normative\nsection of the spec above.\n'
	} >"${SD2}/spec/features/$1/intent.md"
}
sd2 dash "$(printf '\342\200\224')" ''
sd2 extra '-' 'We think this is about billing.'
{
	printf '> Status: approved\n\n## Open questions\n\n'
	printf '### Q-001 - Who owns refunds? <!-- steer:placeholder -->\n- status: open\n- impact: blocking\n'
} >"${SD2}/spec/features/real/intent.md"
out="$(sh "${PLUGIN}/scripts/remove-question-seeds.sh" --list "${SD2}" 2>"${WORK}/seeds2.err")"
oq_grep "seeds: em-dash seed listed" 'features/dash/intent.md' "${out}"
oq_ngrep "seeds: seed with extra content not listed" 'features/extra' "${out}"
oq_ngrep "seeds: marked real question not listed" 'features/real' "${out}"
_err="$(cat "${WORK}/seeds2.err")"
oq_grep "seeds: extra content reported for hand removal" 'extra/intent.md:5: Q-001 has content beyond' "${_err}"
oq_grep "seeds: marked real title reported" 'real/intent.md:5: Q-001 carries the placeholder marker' "${_err}"
sh "${PLUGIN}/scripts/remove-question-seeds.sh" --apply "${SD2}" >/dev/null 2>&1
grep -q 'Anything ambiguous' "${SD2}/spec/features/dash/intent.md" && bad "seeds: em-dash seed removed" || ok
grep -q 'section of the spec above' "${SD2}/spec/features/dash/intent.md" && bad "seeds: wrapped _Resolution:_ removed with it" || ok
grep -q 'about billing' "${SD2}/spec/features/extra/intent.md" && ok || bad "seeds: refused seed left intact"
# The vision and productionization templates seed their own titles; beside a
# real question each is removed, the same as an intent seed.
SD3="${WORK}/seeds3"
mkdir -p "${SD3}/spec"
printf '' >"${SD3}/.git"
sed -n '/^## Open questions/,$p' "${PLUGIN}/templates/spec/vision.md" >"${SD3}/spec/vision.md"
printf '\n### Q-002 - real vision question\n- status: open\n- impact: non-blocking\n' >>"${SD3}/spec/vision.md"
sed -n '/^## Open questions/,$p' "${PLUGIN}/templates/spec/productionization.md" >"${SD3}/spec/PRODUCTIONIZATION.md"
printf '\n### Q-002 - real hardening question\n- status: open\n- impact: non-blocking\n' >>"${SD3}/spec/PRODUCTIONIZATION.md"
out="$(sh "${PLUGIN}/scripts/remove-question-seeds.sh" --list "${SD3}" 2>"${WORK}/seeds3.err")"
oq_grep "seeds: vision seed listed" 'spec/vision.md:' "${out}"
oq_grep "seeds: productionization seed listed" 'spec/PRODUCTIONIZATION.md:' "${out}"
assert_empty "seeds: vision/productionization seeds not refused" "$(cat "${WORK}/seeds3.err")"
sh "${PLUGIN}/scripts/remove-question-seeds.sh" --apply "${SD3}" >/dev/null 2>&1
grep -q 'steer:placeholder -->$' "${SD3}/spec/vision.md" "${SD3}/spec/PRODUCTIONIZATION.md" && bad "seeds: vision/productionization seed removed" || ok
grep -q '^### Q-002 - real hardening question$' "${SD3}/spec/PRODUCTIONIZATION.md" && ok || bad "seeds: productionization real question kept"

ci_spec() { # <repo> -> out/rc of the scaffold gate, run from the repo root as CI does
	out="$(cd "$1" && sh "${PLUGIN}/templates/scaffold/scripts/ci-spec.sh" 2>&1)"
	rc=$?
}
CS="${WORK}/cispec"
mkdir -p "${CS}/scripts" "${CS}/spec/features/f"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lib.sh" "${PLUGIN}/templates/scaffold/scripts/spec-questions.sh" "${CS}/scripts/"
ci_spec "${CS}"
assert_eq "ci-spec: no spine -> passes" "${rc}" "0"
oq_grep "ci-spec: no spine -> says why" 'no steer spec spine' "${out}"
printf '7.0.0\n' >"${CS}/spec/.version"
cp "${SD}/spec/features/fresh/intent.md" "${CS}/spec/features/f/intent.md"
ci_spec "${CS}"
assert_eq "ci-spec: a draft's lone seed passes" "${rc}" "0"
cs_case() { # <name> <intent body after the Status line> <want-rc> <grep>
	printf '> Status: %s\n' "$2" >"${CS}/spec/features/f/intent.md"
	ci_spec "${CS}"
	assert_eq "ci-spec: $1 (rc)" "${rc}" "$3"
	[ -z "$4" ] || oq_grep "ci-spec: $1 (message)" "$4" "${out}"
}
cs_case "bare checkbox fails" 'draft

## Open questions

- [ ] old style' 1 'run /steer:setup sync'
cs_case "seed in an approved feature fails" 'approved

## Open questions

### Q-001 - [Anything ambiguous the PO needs to decide] <!-- steer:placeholder -->
- status: open
- impact: blocking' 1 'past draft'
cs_case "blocking question past its gate fails" 'approved

## Open questions

### Q-001 - late
- status: open
- impact: blocking
- required_before: intent-approval' 1 'already passed'
cs_case "blocking question for a later gate passes" 'approved

## Open questions

### Q-001 - later
- status: open
- impact: blocking
- required_before: production-release' 0 ''
cs_case "missing status fails" 'draft

## Open questions

### Q-001 - broken
- impact: blocking' 1 'has no status'
cs_case "malformed created fails" 'draft

## Open questions

### Q-001 - dated
- created: last week
- status: open
- impact: non-blocking' 1 'YYYY-MM-DD'
cs_case "unknown kind fails" 'draft

## Open questions

### Q-001 - creds
- status: open
- impact: non-blocking
- kind: password' 1 'unknown kind: password'
cs_case "known kind passes" 'draft

## Open questions

### Q-001 - grant
- status: open
- impact: non-blocking
- kind: access          # clarification | decision | access | tooling' 0 ''
# Filling in the template's seed as it says (drop the marker, retitle) keeps the
# field comments, so an empty `created:` must still read as empty.
sed 's/ <!-- steer:placeholder -->//; s/\[Anything[^]]*\]/real question/' \
	"${PLUGIN}/templates/spec/feature-intent.md" >"${CS}/spec/features/f/intent.md"
ci_spec "${CS}"
assert_eq "ci-spec: a question filled in the template's shape passes" "${rc}" "0"
cs_case "PO acceptance checkboxes are not questions" 'approved

## PO acceptance

- [ ] PO reviewed this intent

## Open questions

### Q-001 - fine
- status: resolved
- impact: blocking
- required_before: intent-approval' 0 ''

finish
