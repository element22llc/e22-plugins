#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/check-policy-freshness.sh - offline cases for the pure parts
# (norm_cycle granularity, bump-up-only, apply_floor in-place edit). The live
# feed is stubbed: a fake `curl` emits canned per-product cycle lists and a
# fake `jq` is a stdin passthrough, so only the script's own logic is under
# test - no network, deterministic.
# ---------------------------------------------------------------------------
FRESH="${PLUGIN}/scripts/check-policy-freshness.sh"
FR_BIN="${WORK}/fresh-bin"
mkdir -p "${FR_BIN}"
cat >"${FR_BIN}/curl" <<'EOF'
#!/bin/sh
for _a in "$@"; do _url="${_a}"; done
case "${_url}" in
*postgresql*) printf '14\n15\n16\n' ;; # floor 13 EOL'd -> lowest supported 14
*mysql*) printf '8.4\n9.1.2\n' ;;      # major.minor floor; 9.1.2 must normalize to 9.1
*mariadb*) printf '10.11\n11.4\n' ;;   # major-only floor; 10.11 must normalize to 10
*) exit 22 ;;
esac
EOF
printf '#!/bin/sh\ncat\n' >"${FR_BIN}/jq"
chmod +x "${FR_BIN}/curl" "${FR_BIN}/jq"
freshrun() { # [args...] - run with the stubbed feed; sets out + rc (+ RC_FILE)
	out="$(env PATH="${FR_BIN}:${PATH}" sh "${FRESH}" "$@" 2>/dev/null)"
	rc=$?
	printf '%s' "${rc}" >"${RC_FILE}"
}

FR_POL="${WORK}/fresh-policy.yml"
fresh_policy() {
	cat >"${FR_POL}" <<'EOF'
products:
  postgres:
    minimum_supported: "13"
  mysql:
    minimum_supported: "8.0"
  mariadb:
    minimum_supported: "10"
  valkey:
    minimum_supported: "7"
EOF
}
fresh_policy

# Read-only mode: behind floors reported, exit 1, file untouched.
freshrun "${FR_POL}"
assert_rc "freshness: bumps due -> exit 1" "${rc}" 1
assert_has "freshness: postgres floor bump reported" "${out}" "postgres: minimum_supported 13 -> 14"
assert_has "freshness: major.minor floor normalized (9.1.2 -> 8.4 wins)" "${out}" "mysql: minimum_supported 8.0 -> 8.4"
# norm_cycle keeps the floor's granularity: upstream "10.11" reads as major "10",
# equal to the current floor -> NO bump (a finer cycle must never over-deny).
printf '%s' "${out}" | grep -q 'mariadb' && bad "freshness: major-only floor must not bump from 10.11 (got: ${out})" || ok
grep -q 'minimum_supported: "13"' "${FR_POL}" && ok || bad "freshness: read-only run must not edit the policy file"

# --write: floors bumped in place (product-scoped), exit 1.
freshrun --write "${FR_POL}"
assert_rc "freshness: --write applies -> exit 1" "${rc}" 1
grep -q 'minimum_supported: "14"' "${FR_POL}" && ok || bad "freshness: postgres floor not bumped to 14"
grep -q 'minimum_supported: "8.4"' "${FR_POL}" && ok || bad "freshness: mysql floor not bumped to 8.4"
grep -q 'minimum_supported: "10"' "${FR_POL}" && ok || bad "freshness: mariadb floor must stay 10 (apply_floor scoped per product)"
grep -q 'minimum_supported: "7"' "${FR_POL}" && ok || bad "freshness: no-feed product (valkey) must be skipped untouched"

# Idempotent: floors now current -> exit 0, silent.
freshrun "${FR_POL}"
assert_rc "freshness: floors current -> exit 0" "${rc}" 0
assert_empty "freshness: floors current -> silent" "${out}"

# Missing policy file -> config error.
freshrun "${WORK}/fresh-nope.yml"
assert_rc "freshness: missing policy -> exit 2" "${rc}" 2

finish
