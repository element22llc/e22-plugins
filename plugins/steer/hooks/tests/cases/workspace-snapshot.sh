#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# workspace-snapshot.sh - one-shot read-only local reconstruction for
# /steer:next. Local dimensions only; explicit "none" per empty dimension.
# ---------------------------------------------------------------------------
SNAP="${PLUGIN}/scripts/workspace-snapshot.sh"

# (a) populated managed repo: every local dimension surfaces in one output.
WS1="$(new_repo wsFull)"
managed_spine "${WS1}"
printf 'system: github\n' >"${WS1}/spec/tracker.md"
mkdir -p "${WS1}/spec/features/checkout" "${WS1}/spec/decisions" "${WS1}/spec/.work"
{
	printf '> Status: draft\n\n## Open questions\n\n'
	printf '### Q-001 Which payment provider?\n- status: open\n- impact: blocking\n- required_before: intent-approval\n'
	printf '### Q-999 Placeholder <!-- steer:placeholder -->\n- status: open\n'
} >"${WS1}/spec/features/checkout/intent.md"
printf '# ADR\n\n- **Status:** Proposed\n' >"${WS1}/spec/decisions/0001-stack.md"
# Blockquote form - what the bundled adr.md template actually writes.
printf '# ADR\n\n> Status: Accepted\n> Ratified via: in-session\n' >"${WS1}/spec/decisions/0002-event-bus.md"
# Template never filled in: the whole enum must not read as a real state.
printf '# ADR\n\n> Status: Proposed | Accepted | Superseded by [link] | Deprecated\n' >"${WS1}/spec/decisions/0003-unfilled.md"
printf -- '- issue: 42\n- branch: issue/42-checkout\n' >"${WS1}/spec/.work/issue_42.md"
run_sh "${SNAP}" "${WS1}"
assert_rc "snapshot: managed repo exits 0" "${rc}" 0
assert_has "snapshot: spine state reported" "${out}" "state: managed"
# The stamp is comment-first; the snapshot must report the VERSION, never the
# comment line (/steer:next compares this against the plugin version).
assert_has "snapshot: spec version extracted, not the comment" "${out}" "spec/.version: 1.0.0 ("
printf '%s' "${out}" | grep -q 'spec/.version: #' && bad "snapshot: reported the managed-by comment as the version" || ok
assert_has "snapshot: feature status surfaced" "${out}" "checkout: status=draft contract=no"
assert_has "snapshot: real open question surfaced" "${out}" "Q-001"
assert_has "snapshot: question fields surfaced" "${out}" "impact: blocking"
assert_has "snapshot: open-question summary carried from the hook" "${out}" "summary: \*\*1 open question"
assert_has "snapshot: proposed ADR surfaced" "${out}" "0001-stack.md: Proposed"
assert_has "snapshot: blockquote ADR status surfaced" "${out}" "0002-event-bus.md: Accepted"
assert_has "snapshot: unfilled ADR template flagged" "${out}" "0003-unfilled.md: unresolved-template"
assert_has "snapshot: work claim surfaced" "${out}" "issue_42.md"
assert_has "snapshot: claim detail surfaced" "${out}" "issue/42-checkout"
assert_has "snapshot: tracker system declared, live state deferred" "${out}" "system: github"
assert_has "snapshot: tracker defers to tracker-sync" "${out}" "/steer:tracker-sync"
printf '%s' "${out}" | grep -q 'Q-999' && bad "snapshot: placeholder question must be excluded (got Q-999)" || ok

# (a2) --brief: the status band's key=value counts over the same repo.
mkdir -p "${WS1}/.claude"
printf '7.2.1|hook|sig\n' >"${WS1}/.claude/steer-faults.log"
run_sh "${SNAP}" --brief "${WS1}"
assert_rc "snapshot --brief: exits 0" "${rc}" 0
assert_has "snapshot --brief: delivery mode" "${out}" "delivery=pr-flow"
assert_has "snapshot --brief: spine state" "${out}" "spine=managed"
assert_has "snapshot --brief: feature count" "${out}" "features=1"
assert_has "snapshot --brief: draft count" "${out}" "drafts=1"
assert_has "snapshot --brief: open questions exclude placeholders" "${out}" "questions=1"
assert_has "snapshot --brief: only real Proposed ADRs counted" "${out}" "proposed_adrs=1"
assert_has "snapshot --brief: claim count" "${out}" "claims=1"
assert_has "snapshot --brief: unfiled fault count" "${out}" "faults=1"
assert_has "snapshot --brief: no declared mode" "${out}" "^mode=$"
assert_has "snapshot --brief: no declared product language" "${out}" "^language=$"
printf '## Product\n\n<!-- steer:product-language=fr -->\n**Main product language:** French\n' >"${WS1}/CLAUDE.md"
run_sh "${SNAP}" --brief "${WS1}"
assert_has "snapshot --brief: declared product language" "${out}" "^language=fr$"
rm -f "${WS1}/CLAUDE.md"
printf '{"env":{"STEER_MODE":"advisory"}}\n' >"${WS1}/.claude/settings.local.json"
run_sh "${SNAP}" --brief "${WS1}"
assert_has "snapshot --brief: declared advisory mode" "${out}" "^mode=advisory$"
printf '%s' "${out}" | grep -q '^##' && bad "snapshot --brief: must not print the Markdown report" || ok
rm -rf "${WS1}/.claude"

# (a3) --items: the records behind those counts, for the mod's pane.
_tab="$(printf '\t')"
run_sh "${SNAP}" --items "${WS1}"
assert_rc "snapshot --items: exits 0" "${rc}" 0
assert_has "snapshot --items: feature record" "${out}" "^F${_tab}checkout${_tab}draft$"
assert_has "snapshot --items: open question record" "${out}" \
	"^Q${_tab}checkout${_tab}Q-001${_tab}open${_tab}blocking${_tab}intent-approval${_tab}Which payment provider?$"
assert_has "snapshot --items: Proposed ADR by number" "${out}" "^A${_tab}1${_tab}"
assert_has "snapshot --items: claim record" "${out}" "^C${_tab}42${_tab}issue/42-checkout$"
printf '%s' "${out}" | grep -q 'Q-999' && bad "snapshot --items: placeholder question must be excluded" || ok
printf '%s' "${out}" | grep -q "^A${_tab}[23]${_tab}" && bad "snapshot --items: only Proposed ADRs listed" || ok
printf '%s' "${out}" | grep -q '=' && bad "snapshot --items: must not print the brief counts" || ok
# Legacy marker shapes: no list dash, a `#` ref, no branch line (title, then file name).
printf 'issue: #715\nbranch: issue/715-bot\n' >"${WS1}/spec/.work/issue_715-bot.md"
printf 'issue: 29\ntitle: docs: fold PR 6\n' >"${WS1}/spec/.work/issue_29-fold"
printf -- '- session\n' >"${WS1}/spec/.work/issue_31-bare.md"
run_sh "${SNAP}" --items "${WS1}"
assert_has "snapshot --items: undashed #ref claim" "${out}" "^C${_tab}715${_tab}issue/715-bot$"
assert_has "snapshot --items: claim without branch shows its title" "${out}" "^C${_tab}29${_tab}docs: fold PR 6$"
assert_has "snapshot --items: bare claim falls back to its file name" "${out}" "^C${_tab}31${_tab}issue_31-bare$"
rm -f "${WS1}/spec/.work/issue_715-bot.md" "${WS1}/spec/.work/issue_29-fold" "${WS1}/spec/.work/issue_31-bare.md"

# (a4) #847: a marker whose branch is gone - deleted locally, or its pushed
# upstream pruned - is finished work, not a claim. A live branch, even one cut
# with no commits yet, stays.
WS3="$(git_repo wsClaims issue/50-live)"
(cd "${WS3}" &&
	git branch -q issue/51-upstream-gone &&
	git remote add origin https://example.invalid/r.git &&
	git config branch.issue/51-upstream-gone.remote origin &&
	git config branch.issue/51-upstream-gone.merge refs/heads/issue/51-upstream-gone) >/dev/null 2>&1
mkdir -p "${WS3}/spec/.work"
for _b in issue/50-live issue/51-upstream-gone issue/52-deleted; do
	printf -- '- issue: %s\n- branch: %s\n' "$(printf '%s' "${_b}" | sed 's|issue/\([0-9]*\).*|\1|')" "${_b}" \
		>"${WS3}/spec/.work/$(printf '%s' "${_b}" | tr '/' '_').md"
done
run_sh "${SNAP}" --brief "${WS3}"
assert_has "snapshot --brief: gone-branch claims not counted" "${out}" "^claims=1$"
run_sh "${SNAP}" --items "${WS3}"
assert_has "snapshot --items: live branch claim listed" "${out}" "^C${_tab}50${_tab}issue/50-live$"
printf '%s' "${out}" | grep -q "^C${_tab}5[12]${_tab}" && bad "snapshot --items: gone-branch claims must be hidden" || ok
run_sh "${SNAP}" "${WS3}"
assert_has "snapshot: deleted-branch claim annotated" "${out}" "issue_52-deleted.md .*(stale: branch gone)"
assert_has "snapshot: upstream-gone claim annotated" "${out}" "issue_51-upstream-gone.md .*(stale: branch gone)"
printf '%s' "${out}" | grep -q 'issue_50-live.md .*stale' && bad "snapshot: live claim must not read stale" || ok
# A live branch written with format drift, or alive only on the remote, keeps its claim.
(cd "${WS3}" &&
	git branch -q issue/53-remote-only &&
	git update-ref refs/remotes/origin/issue/53-remote-only HEAD &&
	git branch -q -D issue/53-remote-only) >/dev/null 2>&1
printf -- '- issue: 50\n- branch: `refs/heads/issue/50-live`  \r\n' >"${WS3}/spec/.work/issue_50-drift.md"
printf -- '- issue: 50\n- branch: issue/50-live # note\n' >"${WS3}/spec/.work/issue_50-comment.md"
printf -- '- issue: 53\n- branch: issue/53-remote-only\n' >"${WS3}/spec/.work/issue_53-remote-only.md"
run_sh "${SNAP}" --brief "${WS3}"
assert_has "snapshot --brief: drifted, commented and remote-only claims kept" "${out}" "^claims=4$"

# (b) empty unmanaged repo: dimensions print explicit "none", never silence.
WS2="$(new_repo wsEmpty)"
run_sh "${SNAP}" "${WS2}"
assert_rc "snapshot: empty repo exits 0" "${rc}" 0
assert_has "snapshot: empty features say none" "${out}" "none"
printf '%s' "${out}" | grep -q 'state: managed' && bad "snapshot: empty repo must not read managed" || ok
run_sh "${SNAP}" --brief "${WS2}"
assert_rc "snapshot --brief: empty repo exits 0" "${rc}" 0
assert_has "snapshot --brief: empty repo zero features" "${out}" "features=0"
assert_has "snapshot --brief: empty repo zero faults" "${out}" "faults=0"

# (c) read-only: a snapshot run creates nothing in the target repo.
_before="$(find "${WS1}" | LC_ALL=C sort)"
run_sh "${SNAP}" "${WS1}"
_after="$(find "${WS1}" | LC_ALL=C sort)"
[ "${_before}" = "${_after}" ] && ok || bad "snapshot: must not create or remove files"

# (d) real git repo: branch + working-tree counters populate.
if command -v git >/dev/null 2>&1; then
	WS3="$(git_repo wsGit feat/snapshot)"
	printf 'x\n' >"${WS3}/loose.txt"
	run_sh "${SNAP}" "${WS3}"
	assert_has "snapshot: git branch reported" "${out}" "branch: feat/snapshot"
	# git_repo leaves spec/tracker.md untracked too -> loose.txt makes 2.
	assert_has "snapshot: untracked count reported" "${out}" "2 untracked"
fi

finish
