#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# orient-session.sh - natural-language orientation (SessionStart, managed only)
# (emits plain markdown wrapped into additionalContext by the harness - assert on
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

# Polyrepo topology note - role-specific, ADDITIVE to the generic orientation,
# and completely absent in a single-repo product (the zero-cost guarantee).
OR1W="$(new_repo orient1w)"
managed_spine "${OR1W}"
mkdir -p "${OR1W}/spec"
printf 'schema: 1\n' >"${OR1W}/spec/workspace.yml"
out="$(run_hook orient-session.sh "$(session_json "${OR1W}" or1w)")"
oq_grep "orient: workspace role announced" 'is the \*\*workspace\*\*' "${out}"
oq_grep "orient: workspace warns on partial reports" 'uncovered' "${out}"
oq_ngrep "orient: workspace note is not the member note" 'is a \*\*member\*\*' "${out}"
oq_grep "orient: polyrepo note is additive" 'need to know skill names' "${out}"

OR1M="$(new_repo orient1m)"
managed_spine "${OR1M}"
printf 'workspace:\n' >"${OR1M}/spec/PRODUCT.md"
out="$(run_hook orient-session.sh "$(session_json "${OR1M}" or1m)")"
oq_grep "orient: member role announced" 'is a \*\*member\*\*' "${out}"
oq_grep "orient: member told to qualify cross-repo Closes" 'Closes owner/repo#N' "${out}"
oq_ngrep "orient: member note is not the workspace note" 'is the \*\*workspace\*\*' "${out}"
oq_grep "orient: member note is additive" 'need to know skill names' "${out}"

# The topology note is precisely why the hook is registered on
# startup|resume|clear|compact|fork: it must survive a /clear, a compaction or a fork, unlike the
# one-time knowledge-work greeting, which is gated to `startup`.
for src in startup resume clear compact fork; do
	out="$(run_hook orient-session.sh "$(session_json_src "${OR1M}" or1m "${src}")")"
	oq_grep "orient: member topology note survives source=${src}" 'is a \*\*member\*\*' "${out}"
done

# A single-repo product must see NO polyrepo text at all.
OR1S="$(new_repo orient1s)"
managed_spine "${OR1S}"
out="$(run_hook orient-session.sh "$(session_json "${OR1S}" or1s)")"
oq_ngrep "orient: single-repo product pays zero polyrepo bytes" 'polyrepo' "${out}"

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

finish
