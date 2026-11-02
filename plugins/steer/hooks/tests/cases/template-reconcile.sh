#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/template-reconcile.sh - read-only structural diff (not a hook)
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
# a completed intent that filled in / deleted the `### Q-001 - [...]` stub must
# not be flagged for the deleted placeholder.
printf '## Open questions\n_No open questions._\n' >"${RDIR}/done.md"
printf '## Open questions\n### Q-001 - [decide] <!-- steer:placeholder -->\n' >"${RDIR}/seed.md"
run_sh "${RECON}" "${RDIR}/done.md" "${RDIR}/seed.md"
assert_rc "reconcile: placeholder-skip exits 0" "${rc}" 0
assert_empty "reconcile: deleted placeholder seed not reported" "${out}"
# a renamed real question (marker deleted) is also not chased back to the stub
printf '## Open questions\n### Q-001 - should we ship X?\n' >"${RDIR}/real.md"
run_sh "${RECON}" "${RDIR}/real.md" "${RDIR}/seed.md"
assert_rc "reconcile: filled-in placeholder run exits 0" "${rc}" 0
assert_empty "reconcile: filled-in placeholder not reported" "${out}"
# a genuinely-missing (non-placeholder) heading is still reported
printf '## Open questions\n### Q-002 - real and unmarked\n' >"${RDIR}/seed2.md"
run_sh "${RECON}" "${RDIR}/done.md" "${RDIR}/seed2.md"
printf '%s' "${out}" | grep -q 'Q-002' && ok || bad "reconcile: real missing heading still reported (got: ${out})"

# usage + unreadable inputs
run_sh "${RECON}" "${RDIR}/existing.md"
assert_rc "reconcile: wrong arg count -> exit 2" "${rc}" 2
run_sh "${RECON}" "${RDIR}/nope.md" "${RDIR}/bundled.md"
assert_rc "reconcile: unreadable input -> exit 3" "${rc}" 3

finish
