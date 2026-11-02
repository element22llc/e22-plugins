#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- check-version-pins.sh (deterministic, policy-driven; uses the bundled
#     policy/versions.yml via CLAUDE_PLUGIN_ROOT - no network, no jq) ---

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11)")")"
assert_deny "version-pins: denied major denied" "${out}"

# Floor-only policy: a supported-but-older major (>= minimum_supported, not denied)
# is silent - there is no advisory "behind the target" tier.
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 16)")")"
assert_no_deny "version-pins: above-floor not denied" "${out}"
assert_empty "version-pins: above-floor silent (no advisory tier)" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 18)")")"
assert_empty "version-pins: above-floor major silent" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin python 3.9)")")"
assert_deny "version-pins: below minimum_supported denied (python 3.9)" "${out}"
# A major-only tag floats the minor: python:3 resolves to a current 3.x (CONVENTIONS).
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 Dockerfile "FROM $(pin python 3)-slim")")"
assert_empty "version-pins: major-only tag compared at major granularity" "${out}"
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 Dockerfile "FROM $(pin python 2)-slim")")"
assert_deny "version-pins: major-only tag below the floor's major still denied" "${out}"
# The docs exemption is repo-relative: a clone under a docs/ dir is still enforced.
RD="${WORK}/docs/app"
mkdir -p "${RD}" && git -C "${RD}" init -q
out="$(run_hook check-version-pins.sh "$(json_write "${RD}" s1 "${RD}/compose.yaml" "image: $(pin postgres 11)")")"
assert_deny "version-pins: an ancestor docs/ dir does not exempt the repo" "${out}"
out="$(run_hook check-version-pins.sh "$(json_write "${RD}" s1 "${RD}/docs/setup.yaml" "image: $(pin postgres 11)")")"
assert_empty "version-pins: the repo's own docs/ stays exempt" "${out}"

out="$(run_hook check-version-pins.sh "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"compose.yaml\",\"old_string\":\"$(pin postgres 11)\",\"new_string\":\"$(pin postgres 18)\"}}")"
assert_empty "version-pins: upgrade edit silent (F13, old value ignored)" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11) # steer:allow-pin vendor LTS")")"
assert_empty "version-pins: steer:allow-pin bypass" "${out}"

out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11) # pin-ok: legacy alias")")"
assert_empty "version-pins: legacy pin-ok bypass" "${out}"

# Regression: a three-segment pin (extracted at major.minor) must still honor a
# same-line marker - the boundary class excludes only digits, not the dot.
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin postgres 11).2.1 # steer:allow-pin three-segment")")"
assert_empty "version-pins: steer:allow-pin bypass honors 3-segment pin" "${out}"

out="$(run_hook check-version-pins.sh "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"docker run $(pin postgres 11)\"}}")"
assert_empty "version-pins: Bash skipped (CI scanner is the backstop)" "${out}"

# NotebookEdit new_source is inspected like any write - a denied pin in a notebook
# cell is caught, not silently passed (issue #271: NotebookEdit was a dead matcher).
out="$(run_hook check-version-pins.sh "{\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"a.ipynb\",\"new_source\":\"image: $(pin postgres 11)\"}}")"
assert_deny "version-pins: NotebookEdit new_source denied pin caught" "${out}"

# A steer:allow-pin justification on a DIFFERENT line must NOT suppress a deny for a
# pin elsewhere - the same-line discipline only holds if multi-line content survives
# unescaping (issue #271). '\n' in the JSON value is a real newline in the content.
out="$(run_hook check-version-pins.sh "$(json_write /tmp sML compose.yaml "image: $(pin postgres 11)\nother: fine # steer:allow-pin unrelated")")"
assert_deny "version-pins: allow-pin on a different line does not suppress deny" "${out}"

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
# The same repo-local policy is honored when editing from a SUBDIR - the hook
# resolves the work-tree root before reading policy/versions.yml (#277 item 4). A
# subdir with no policy/ would otherwise fall through to the laxer bundled default.
mkdir -p "${RP}/apps/web"
out="$(run_hook check-version-pins.sh "$(json_write "${RP}/apps/web" sPsub compose.yaml "image: $(pin postgres 17)")")"
assert_deny "version-pins: repo-local policy enforced from a subdir" "${out}"
# Escaping the pin's dot (#277 item 5) must not break allow-pin marker matching on
# a legitimately-marked dotted pin.
out="$(run_hook check-version-pins.sh "$(json_write /tmp s1 compose.yaml "image: $(pin python 3.9) # steer:allow-pin vendor LTS")")"
assert_empty "version-pins: dotted pin still honors its own allow-pin marker" "${out}"

finish
