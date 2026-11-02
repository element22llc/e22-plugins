#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# check-template-drift.sh - root-anchored spec/template drift detector
# (SessionStart; emits plain markdown wrapped as additionalContext by the harness.
#  Reads cwd from the payload and resolves the work-tree root - issue #270.)
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

# (c) the placeholder-marked heading (### Q-001 ... steer:placeholder) is never
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

# (e) a contract.md with every template section but plain, unnumbered rule bullets
#     -> silent. The template's `### R-001` seed is placeholder-marked; without
#     that, every pre-existing contract would draw a drift notice each session.
TD4="$(new_repo td4)"
mkdir -p "${TD4}/spec/features/f"
grep '^## ' "${PLUGIN}/templates/spec/feature-contract.md" >"${TD4}/spec/features/f/contract.md"
printf -- '- Given a list, when exported, then a CSV downloads\n' >>"${TD4}/spec/features/f/contract.md"
out="$(run_hook check-template-drift.sh "$(session_json "${TD4}" td4)")"
assert_empty "template-drift: unnumbered contract rules are not drift" "${out}"

finish
