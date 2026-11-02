#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/scan-version-pins.sh - CI version-pin scanner (deterministic policy)
# (pins assembled via pin() so this file's source carries no name:NN literal.)
# ---------------------------------------------------------------------------
SCAN="${PLUGIN}/scripts/scan-version-pins.sh"
BUNDLED_POLICY="${PLUGIN}/policy/versions.yml"
scan() { # <dir>  -> sets `rc`; uses the bundled policy
	STEER_POLICY_FILE="${BUNDLED_POLICY}" sh "${SCAN}" "$1" >/dev/null 2>&1
	rc=$?
}

SD="${WORK}/scan1"
mkdir -p "${SD}"
printf 'services:\n  db:\n    image: %s\n' "$(pin postgres 11)" >"${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: denied pin -> exit 1" "${rc}" 1

printf 'services:\n  db:\n    image: %s # steer:allow-pin vendor LTS\n' "$(pin postgres 11)" >"${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: suppressed pin -> exit 0" "${rc}" 0

printf 'FROM %s\n' "$(pin node 22)" >"${SD}/Dockerfile"
rm -f "${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: supported pin -> exit 0" "${rc}" 0

# Templated / variable values are NOT resolved -> never false-positived.
printf 'services:\n  db:\n    image: postgres:${PG_MAJOR}\n' >"${SD}/compose.yaml"
rm -f "${SD}/Dockerfile"
scan "${SD}"
assert_rc "scan: templated value not flagged" "${rc}" 0

# Excluded dependency trees are skipped even with a denied pin inside.
mkdir -p "${SD}/node_modules/x"
printf 'image: %s\n' "$(pin postgres 11)" >"${SD}/node_modules/x/compose.yaml"
rm -f "${SD}/compose.yaml"
scan "${SD}"
assert_rc "scan: excluded dir (node_modules) skipped" "${rc}" 0

# Bash-mediated pin in a committed script IS caught (the hook can't see it).
printf '#!/bin/sh\ndocker run %s\n' "$(pin postgres 11)" >"${SD}/run.sh"
scan "${SD}"
assert_rc "scan: committed Bash pin caught -> exit 1" "${rc}" 1
rm -f "${SD}/run.sh"

# No policy file -> config error.
SDNP="${WORK}/scan-nopolicy"
mkdir -p "${SDNP}"
printf 'image: %s\n' "$(pin postgres 11)" >"${SDNP}/compose.yaml"
sh "${SCAN}" "${SDNP}" >/dev/null 2>&1
assert_rc "scan: missing policy -> exit 2" "$?" 2

finish
