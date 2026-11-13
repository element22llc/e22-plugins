#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# The scanner reads git's file list inside a work tree, so a WORK under some
# enclosing repo, or a developer's global excludes, would change what it sees.
export GIT_CEILING_DIRECTORIES="${WORK}" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

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

# Inside a git work tree only tracked and untracked-not-ignored files are read.
SG="${WORK}/scan-git"
mkdir -p "${SG}/.helm-plugins/x" "${SG}/sub/.helm-plugins"
git -C "${SG}" init -q >/dev/null 2>&1
printf '.helm-plugins/\n' >"${SG}/.gitignore"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/.helm-plugins/x/compose.yaml"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/sub/.helm-plugins/compose.yaml"
scan "${SG}"
assert_rc "scan: git-ignored vendored dir skipped" "${rc}" 0
scan "${SG}/sub"
assert_rc "scan: git-ignored dir skipped from a subdirectory root" "${rc}" 0

printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/compose.yaml"
git -C "${SG}" add compose.yaml
scan "${SG}"
assert_rc "scan: tracked pin caught -> exit 1" "${rc}" 1
git -C "${SG}" rm -q --cached compose.yaml
rm -f "${SG}/compose.yaml"

printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/new.yml"
scan "${SG}"
assert_rc "scan: untracked-not-ignored pin caught -> exit 1" "${rc}" 1
rm -f "${SG}/new.yml"

mkdir -p "${SG}/sub dir"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/sub dir/my compose.yml"
scan "${SG}"
assert_rc "scan: filename with spaces caught -> exit 1" "${rc}" 1
rm -rf "${SG}/sub dir"

mkdir -p "${SG}/node_modules/x"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/node_modules/x/compose.yaml"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/README.md"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/gone.yml"
git -C "${SG}" add node_modules README.md gone.yml
rm -f "${SG}/gone.yml"
scan "${SG}"
assert_rc "scan: tracked dependency tree, prose and deleted path skipped" "${rc}" 0
git -C "${SG}" rm -rq --cached node_modules README.md gone.yml
rm -rf "${SG}/node_modules" "${SG}/README.md"

printf 'image: %s\n' "$(pin postgres 11)" >"${WORK}/outside.yml"
ln -s "${WORK}/outside.yml" "${SG}/link.yml"
git -C "${SG}" add link.yml
scan "${SG}"
assert_rc "scan: tracked symlink not followed" "${rc}" 0
git -C "${SG}" rm -q --cached link.yml
rm -f "${SG}/link.yml"

# A root the enclosing repo ignores is walked, not read as an empty file list.
mkdir -p "${SG}/.helm-plugins/y"
printf 'image: %s\n' "$(pin postgres 11)" >"${SG}/.helm-plugins/y/compose.yaml"
scan "${SG}/.helm-plugins/y"
assert_rc "scan: git-ignored root walked -> exit 1" "${rc}" 1

# An ignore-everything-then-whitelist .gitignore must not read as an ignored root.
SW="${WORK}/scan-whitelist"
mkdir -p "${SW}/sub/.vend"
git -C "${SW}" init -q >/dev/null 2>&1
printf '*\n!*/\n!*.yml\nsub/.vend/\n' >"${SW}/.gitignore"
printf 'image: %s\n' "$(pin postgres 11)" >"${SW}/sub/.vend/v.yml"
scan "${SW}"
assert_rc "scan: whitelist-style .gitignore still honored at the top level" "${rc}" 0

MARK="${WORK}/fsmonitor-ran"
printf '#!/bin/sh\n: >"%s"\n' "${MARK}" >"${WORK}/fsmonitor.sh"
chmod +x "${WORK}/fsmonitor.sh"
git -C "${SW}" config core.fsmonitor "${WORK}/fsmonitor.sh"
scan "${SW}"
[ ! -e "${MARK}" ] && ok || bad "scan: repo-configured core.fsmonitor was executed"
git -C "${SW}" config --unset core.fsmonitor

printf 'image: %s\n' "$(pin postgres 11)" >"${SW}/top.yml"
out="$(STEER_POLICY_FILE="${BUNDLED_POLICY}" sh "${SCAN}" "${SW}/" 2>&1)"
assert_has "scan: trailing-slash root keeps one slash" "${out}" "${SW}/top.yml:1:"
rm -f "${SW}/top.yml"

# A failing `git ls-files` falls back to the walk rather than scanning nothing.
SHIM="${WORK}/git-shim"
mkdir -p "${SHIM}"
REAL_GIT="$(command -v git)"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = ls-files ] && exit 1; done\nexec "%s" "$@"\n' "${REAL_GIT}" >"${SHIM}/git"
chmod +x "${SHIM}/git"
PATH="${SHIM}:${PATH}" STEER_POLICY_FILE="${BUNDLED_POLICY}" sh "${SCAN}" "${SG}" >/dev/null 2>&1
assert_rc "scan: failing ls-files falls back to the walk -> exit 1" "$?" 1

# Outside git a .gitignore means nothing: the walk still reads the vendored dir.
SN="${WORK}/scan-nogit"
mkdir -p "${SN}/.helm-plugins"
printf '.helm-plugins/\n' >"${SN}/.gitignore"
printf 'image: %s\n' "$(pin postgres 11)" >"${SN}/.helm-plugins/compose.yaml"
scan "${SN}"
assert_rc "scan: non-git root walked -> exit 1" "${rc}" 1

finish
