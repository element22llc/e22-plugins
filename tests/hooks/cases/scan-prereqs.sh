#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/scan-prereqs.sh - offline cases for the pure parts (os/stack
# fingerprint, shadowed classification). The detector probes the host PATH, so
# each case runs it under a HERMETIC PATH: a dir of symlinked core utilities
# plus only the tools the case plants - every verdict is deterministic on any
# host or CI runner.
# ---------------------------------------------------------------------------
PREREQS="${PLUGIN}/scripts/scan-prereqs.sh"
PQ_CORE="${WORK}/pq-core"
mkdir -p "${PQ_CORE}"
for _t in sh uname head tr ls grep; do
	ln -s "$(command -v "${_t}")" "${PQ_CORE}/${_t}"
done

fake_tool() { # <dir> <name> <output-line>  - a stub that answers any args with $3
	printf '#!/bin/sh\necho "%s"\n' "$3" >"$1/$2"
	chmod +x "$1/$2"
}
pqscan() { # <PATH-value> <repo> [extra env assignments...]
	_pq_path="$1"
	_pq_repo="$2"
	shift 2
	out="$(env "$@" PATH="${_pq_path}" sh "${PREREQS}" "${_pq_repo}" 2>/dev/null)"
	rc=$?
	printf '%s' "${rc}" >"${RC_FILE}"
}
pqstatus() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$1==t {print $2; exit}'; }
pqdetail() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$1==t {print $3; exit}'; }

# --- os fingerprint (fake uname pins the kernel name per case) ---
PQ_OS="${WORK}/pq-os-bin"
mkdir -p "${PQ_OS}"
fake_tool "${PQ_OS}" uname "Darwin"
# fake uname shadows the core one -> prepend
PQR="${WORK}/pq-repo"
mkdir -p "${PQR}"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}"
assert_rc "prereqs: normal run exits 0" "${rc}" 0
assert_eq "prereqs: os Darwin -> darwin" "$(pqstatus "${out}" os)" "darwin"
fake_tool "${PQ_OS}" uname "Linux"
# Both WSL signals are stubbed per case, so the suite is hermetic on a real WSL2 host too.
PQ_PROC_PLAIN="${WORK}/pq-proc-plain"
printf 'Linux version 6.8.0-generic (gcc 13)\n' >"${PQ_PROC_PLAIN}"
PQ_PROC_WSL="${WORK}/pq-proc-wsl"
printf 'Linux version 5.15.0-microsoft-standard-WSL2 (gcc 11)\n' >"${PQ_PROC_WSL}"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}" -u WSL_DISTRO_NAME "STEER_PROC_VERSION=${PQ_PROC_PLAIN}"
assert_eq "prereqs: os Linux (no WSL) -> linux" "$(pqstatus "${out}" os)" "linux"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}" WSL_DISTRO_NAME=Ubuntu "STEER_PROC_VERSION=${PQ_PROC_PLAIN}"
assert_eq "prereqs: os Linux + WSL_DISTRO_NAME -> wsl2" "$(pqstatus "${out}" os)" "wsl2"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}" -u WSL_DISTRO_NAME "STEER_PROC_VERSION=${PQ_PROC_WSL}"
assert_eq "prereqs: os Linux + microsoft /proc/version -> wsl2" "$(pqstatus "${out}" os)" "wsl2"
fake_tool "${PQ_OS}" uname "MINGW64_NT-10.0"
pqscan "${PQ_OS}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: os MINGW -> windows" "$(pqstatus "${out}" os)" "windows"

# --- stack fingerprint drives n/a verdicts ---
PQ_PY="${WORK}/pq-py"
mkdir -p "${PQ_PY}"
printf '[project]\n' >"${PQ_PY}/pyproject.toml"
pqscan "${PQ_CORE}" "${PQ_PY}"
assert_eq "prereqs: python-only repo -> node n/a" "$(pqstatus "${out}" node)" "n/a"
assert_eq "prereqs: python-only repo -> pnpm n/a" "$(pqstatus "${out}" pnpm)" "n/a"
PQ_NODE="${WORK}/pq-node"
mkdir -p "${PQ_NODE}"
printf '{}\n' >"${PQ_NODE}/package.json"
pqscan "${PQ_CORE}" "${PQ_NODE}"
assert_eq "prereqs: node-only repo -> uv n/a" "$(pqstatus "${out}" uv)" "n/a"

# --- required tools + runtime classification against a controlled PATH ---
# Nothing planted: git/mise missing; runtimes unmanaged (no mise to provide them).
pqscan "${PQ_CORE}" "${PQR}"
assert_eq "prereqs: bare PATH -> git missing" "$(pqstatus "${out}" git)" "missing"
assert_eq "prereqs: bare PATH -> mise missing" "$(pqstatus "${out}" mise)" "missing"
assert_eq "prereqs: no mise -> node unmanaged" "$(pqstatus "${out}" node)" "unmanaged"

# mise present, runtime absent -> via-mise.
PQ_MISEBIN="${WORK}/pq-misebin"
mkdir -p "${PQ_MISEBIN}"
fake_tool "${PQ_MISEBIN}" mise "mise 0.0-fake"
pqscan "${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: mise present, node absent -> via-mise" "$(pqstatus "${out}" node)" "via-mise"

# mise present + runtime resolving OUTSIDE the mise data dir -> shadowed (advisory).
PQ_SHADOW="${WORK}/pq-shadowbin"
mkdir -p "${PQ_SHADOW}"
fake_tool "${PQ_SHADOW}" node "v0.0-fake"
pqscan "${PQ_SHADOW}:${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: non-mise node while mise present -> shadowed" "$(pqstatus "${out}" node)" "shadowed"
assert_has "prereqs: shadowed detail names the fix" "$(pqdetail "${out}" node)" "mise exec"

# ... and the shadow source is classified (a ~/.nvm path reads as nvm).
PQ_NVM="${WORK}/.nvm/versions/bin"
mkdir -p "${PQ_NVM}"
fake_tool "${PQ_NVM}" node "v0.0-fake"
pqscan "${PQ_NVM}:${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_has "prereqs: nvm path classified as nvm shadow" "$(pqdetail "${out}" node)" "(nvm)"

# A mise-managed resolution (path contains /mise/) is NOT shadowed -> ok.
PQ_MISED="${WORK}/mise/installs/node/bin"
mkdir -p "${PQ_MISED}"
fake_tool "${PQ_MISED}" node "v0.0-fake"
pqscan "${PQ_MISED}:${PQ_MISEBIN}:${PQ_CORE}" "${PQR}"
assert_eq "prereqs: mise-managed node -> ok" "$(pqstatus "${out}" node)" "ok"

# --- docker requiredness rides on compose presence ---
pqscan "${PQ_CORE}" "${PQR}"
assert_has "prereqs: no compose -> docker advisory" "$(pqdetail "${out}" docker)" "advisory"
printf 'services:\n' >"${PQR}/compose.yaml"
pqscan "${PQ_CORE}" "${PQR}"
assert_eq "prereqs: compose + no docker -> missing" "$(pqstatus "${out}" docker)" "missing"
assert_has "prereqs: compose -> docker required" "$(pqdetail "${out}" docker)" "required"
rm -f "${PQR}/compose.yaml"

# --- exit-code contract ---
sh "${PREREQS}" a b >/dev/null 2>&1
assert_rc "prereqs: too many args -> exit 2" "$?" 2
sh "${PREREQS}" "${WORK}/pq-nope" >/dev/null 2>&1
assert_rc "prereqs: unreadable repo-root -> exit 3" "$?" 3

finish
