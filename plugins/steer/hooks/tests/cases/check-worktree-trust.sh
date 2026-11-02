#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# check-worktree-trust.sh (SessionStart) - inherits the primary checkout's
# `mise trust` into a linked worktree. `mise trust` is path-based, so a new
# worktree is untrusted and every `mise run ...` there fails until someone trusts
# it (#416); inheriting grants nothing new because trust is path-keyed, not
# content-hashed. A stubbed `mise` reports the trust states these cases need and
# records its argv, so each case asserts exactly what the hook did - including
# the boundary case that must write NOTHING.
# ---------------------------------------------------------------------------
. "${HERE}/lib-worktree.sh"

# (a) untrusted worktree + trusted primary -> trust inherited, notice emitted.
# shellcheck disable=SC2046  # deliberate word split: wt_pair prints two paths
set -- $(wt_pair wtTrustA)
WTA_P="$1"
WTA_W="$2"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=${WTA_P}" \
	run_hook check-worktree-trust.sh "$(session_json "${WTA_W}" wt1)")"
assert_has "worktree-trust: inherits and says so" "${out}" "inherited the primary checkout"
grep -q "mise trust -q -C ${WTA_W}" "${WT_LOG}" && ok ||
	bad "worktree-trust: trust applied to the worktree (log: $(cat "${WT_LOG}"))"

# (b) untrusted worktree + UNTRUSTED primary -> the boundary: no trust written,
#     and the notice routes the first-time decision to the human.
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustB)
WTB_W="$2"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=" \
	run_hook check-worktree-trust.sh "$(session_json "${WTB_W}" wt2)")"
assert_has "worktree-trust: untrusted primary names the setup command" "${out}" 'mise trust && mise install'
grep -q 'trust -q' "${WT_LOG}" &&
	bad "worktree-trust: must NOT create trust when the primary is untrusted" || ok

# (b2) the worktree's branch introduced mise.toml and the primary has none: no
#      prior decision about this config exists anywhere, so the notice must say
#      that rather than "the repo was never set up", and still write nothing.
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustB2)
WTB2_P="$1"
WTB2_W="$2"
rm -f "${WTB2_P}/mise.toml"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=" \
	run_hook check-worktree-trust.sh "$(session_json "${WTB2_W}" wt2b)")"
assert_has "worktree-trust: primary without mise config says so" "${out}" "no mise config at all"
grep -q 'trust -q' "${WT_LOG}" &&
	bad "worktree-trust: must NOT create trust for a config with no prior decision" || ok

# (c) worktree already trusted (resumed session) -> silent, no write.
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustC)
WTC_P="$1"
WTC_W="$2"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=${WTC_P}:${WTC_W}" \
	run_hook check-worktree-trust.sh "$(session_json "${WTC_W}" wt3)")"
assert_empty "worktree-trust: already-trusted worktree silent" "${out}"
grep -q 'trust -q' "${WT_LOG}" &&
	bad "worktree-trust: no re-trust of an already-trusted worktree" || ok

# (d) primary checkout (not a worktree) -> silent, and mise never invoked.
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustD)
WTD_P="$1"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=" \
	run_hook check-worktree-trust.sh "$(session_json "${WTD_P}" wt4)")"
assert_empty "worktree-trust: plain checkout silent" "${out}"
[ -s "${WT_LOG}" ] &&
	bad "worktree-trust: plain checkout must not invoke mise (log: $(cat "${WT_LOG}"))" || ok

# (e) worktree with no mise config -> silent (nothing to trust).
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustE)
WTE_P="$1"
WTE_W="$2"
rm -f "${WTE_W}/mise.toml"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=${WTE_P}" \
	run_hook check-worktree-trust.sh "$(session_json "${WTE_W}" wt5)")"
assert_empty "worktree-trust: no mise config silent" "${out}"

# (f) mise absent from PATH -> silent (nothing to do, and nothing to blame).
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustF)
WTF_W="$2"
out="$(ENV="PATH=/usr/bin:/bin" run_hook check-worktree-trust.sh "$(session_json "${WTF_W}" wt6)")"
assert_empty "worktree-trust: no mise on PATH silent" "${out}"

# (g) cwd outside any work tree -> silent.
WT_NOREPO="${WORK}/wtTrustNoRepo"
mkdir -p "${WT_NOREPO}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG}" \
	run_hook check-worktree-trust.sh "$(session_json "${WT_NOREPO}" wt7)")"
assert_empty "worktree-trust: no repo silent" "${out}"

# (j) REGRESSION: mise lists ancestors FIRST. An ancestor whose home-relative
#     tail is also a suffix of the worktree path - a repo under `~/work` with a
#     worktree named `work` - matched before the worktree's own line, so taking
#     the first match returned the ANCESTOR's state and silently restored the
#     original bug. The deepest (longest-tail) line must win.
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustAnc)
WTJ_P="$1"
WTJ_W="$2"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=${WTJ_P} HOME=${WORK} MISE_STUB_ANCESTORS=~/feat-x" \
	run_hook check-worktree-trust.sh "$(session_json "${WTJ_W}" wt9)")"
assert_has "worktree-trust: ancestor line does not mask the worktree" "${out}" "inherited the primary checkout"
grep -q "mise trust -q -C ${WTJ_W}" "${WT_LOG}" && ok ||
	bad "worktree-trust: trust applied despite a matching ancestor line"

# (k) REGRESSION: a config-less PRIMARY whose ANCESTOR is trusted must not be
#     read as trusted. A matcher that accepted an ancestor's line here skipped the
#     "primary has no mise config at all" notice and fell through to
#     `mise trust -q -C`, CREATING trust - the one thing this hook must never do.
#     The primary sits at ~/ancnest/ancnest so the ancestor ~/ancnest has tail
#     `/ancnest`, which is also a SUFFIX of the primary's path - the exact shape
#     that defeated the suffix matcher.
# shellcheck disable=SC2046
set -- $(wt_pair ancnest/ancnest)
WTK_P="$1"
WTK_W="$2"
rm -f "${WTK_P}/mise.toml" # primary's config is new on the worktree's branch
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED= HOME=${WORK} MISE_STUB_ANCESTORS=~/ancnest" \
	run_hook check-worktree-trust.sh "$(session_json "${WTK_W}" wt10)")"
assert_has "worktree-trust: config-less primary still asks the human" "${out}" "no mise config at all"
grep -q 'trust -q' "${WT_LOG}" &&
	bad "worktree-trust: must NOT create trust from an ancestor's state" || ok

# (h) the check is registered in the session-checks roster (it ships as part of
#     the one SessionStart registration, not its own).
grep -q 'check-worktree-trust\.sh' "${HOOKS}/session-checks.sh" && ok ||
	bad "worktree-trust: listed in the session-checks roster"

# (i) REGRESSION: the repo lives under $HOME, so `mise trust --show` abbreviates
#     both paths to `~/...`. Matching only the absolute path made the hook read ''
#     for every such worktree - the normal layout - and exit silently, inheriting
#     nothing and printing neither fallback notice. Same assertions as (a).
# shellcheck disable=SC2046
set -- $(wt_pair wtTrustHome)
WTI_P="$1"
WTI_W="$2"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=${WTI_P} HOME=${WORK}" \
	run_hook check-worktree-trust.sh "$(session_json "${WTI_W}" wt8)")"
assert_has "worktree-trust: inherits under \$HOME (~-abbreviated --show)" "${out}" "inherited the primary checkout"
grep -q "mise trust -q -C ${WTI_W}" "${WT_LOG}" && ok ||
	bad "worktree-trust: trust applied under \$HOME (log: $(cat "${WT_LOG}"))"
unset ENV

finish
