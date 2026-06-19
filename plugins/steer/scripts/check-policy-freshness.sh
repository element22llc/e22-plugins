#!/usr/bin/env sh
# steer — version-policy freshness check + refresh (advisory, CI/scheduled only).
#
# Compares policy/versions.yml `minimum_supported` floors against UPSTREAM
# end-of-life (endoflife.date) and computes the floor each product SHOULD carry:
# the lowest cycle still supported upstream, at the SAME granularity the floor
# already uses (major-only or major.minor). It is BUMP-UP-ONLY — it never lowers a
# floor, so a policy that is deliberately STRICTER than upstream EOL is preserved.
#
# This is the ONLY place that consults the live source. Two modes:
#   (default)   read-only — print the bumps that are due, exit 1 if any are due.
#   --write     apply the bumps in place to the policy file(s), exit 1 if any
#               were applied. The scheduled workflow runs --write and opens a PR;
#               enforcement (the hook + scan-version-pins.sh) never runs this.
#
# Writing targets BOTH byte-identical copies (the plugin default + the scaffold
# seed) when no explicit file is given, so they never drift (check_standards.py
# enforces byte-identity). Idempotent: a second run with current floors is a no-op.
#
# Requires jq + curl (a controlled CI environment — unlike the enforcement path,
# which is dependency-free). Prints nothing when every floor is current.
#
# USAGE: check-policy-freshness.sh [--write] [policy-file]
#        (default policy-file: the plugin-bundled copy)
# EXIT:  0 floors current · 1 bumps due/applied · 2 config error (missing dep/file)

set -u
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
. "${HERE}/../hooks/lib/version-policy.sh"

WRITE=0
POLICY=""
for _arg in "$@"; do
	case "${_arg}" in
	--write) WRITE=1 ;;
	*) POLICY="${_arg}" ;;
	esac
done

# Detection reads ONE source of truth; --write applies to every target so the
# byte-identical copies stay in lockstep.
PLUGIN_POLICY="${HERE}/../policy/versions.yml"
SCAFFOLD_POLICY="${HERE}/../templates/scaffold/policy/versions.yml"
if [ -n "${POLICY}" ]; then
	TARGETS="${POLICY}"
else
	POLICY="${PLUGIN_POLICY}"
	TARGETS="${PLUGIN_POLICY} ${SCAFFOLD_POLICY}"
fi

[ -s "${POLICY}" ] || {
	printf 'check-policy-freshness: policy file %s not found.\n' "${POLICY}" >&2
	exit 2
}
command -v jq >/dev/null 2>&1 || {
	printf 'check-policy-freshness: jq required.\n' >&2
	exit 2
}
command -v curl >/dev/null 2>&1 || {
	printf 'check-policy-freshness: curl required.\n' >&2
	exit 2
}

# product (policy key) -> endoflife.date product slug. Products with no upstream
# feed (e.g. valkey) are omitted and skipped.
eol_slug() {
	case "$1" in
	postgres) printf 'postgresql' ;;
	node) printf 'nodejs' ;;
	mongo) printf 'mongodb' ;;
	python | redis | mysql | mariadb | nginx) printf '%s' "$1" ;;
	*) : ;;
	esac
}

# Normalize an upstream cycle to the granularity of the current floor: 1 segment
# (major) or 2 (major.minor). Keeps the computed floor at the same shape the
# policy already uses, so a finer-grained upstream cycle never produces an
# over-denying floor (e.g. "10.11" where the policy means major "10").
norm_cycle() { # <cycle> <segs>
	if [ "$2" = 1 ]; then
		printf '%s' "${1%%.*}"
	else
		_c_maj="${1%%.*}"
		_c_rest="${1#*.}"
		case "$1" in
		*.*) printf '%s.%s' "${_c_maj}" "${_c_rest%%.*}" ;;
		*) printf '%s' "${_c_maj}" ;;
		esac
	fi
}

# apply_floor <file> <product> <newval> — replace minimum_supported within the
# product's block only. Fixed-shape YAML (2-space product keys, 4-space scalars).
apply_floor() {
	_af_tmp="$1.tmp.$$"
	awk -v p="$2" -v v="$3" '
    /^  [A-Za-z]/ { inblock = ($0 ~ "^  " p ":[ \t]*(#.*)?$") }
    inblock && /^    minimum_supported:/ {
      sub(/minimum_supported:[ \t]*"[^"]*"/, "minimum_supported: \"" v "\"")
    }
    { print }
  ' "$1" >"${_af_tmp}" && mv "${_af_tmp}" "$1"
}

# Products listed in the policy file (2-space keys under `products:`).
PRODUCTS="$(awk '/^products:/{p=1;next} p&&/^  [a-z]/{s=$1;sub(/:.*/,"",s);print s}' "${POLICY}")"

TODAY="$(date -u +%Y-%m-%d)"
REPORT=""
BUMPS="" # newline-separated "product target" pairs to apply

for _p in ${PRODUCTS}; do
	_slug="$(eol_slug "${_p}")"
	[ -n "${_slug}" ] || continue
	_cur="$(steer_policy_field "${POLICY}" "${_p}" minimum_supported)"
	[ -n "${_cur}" ] || continue

	_json="$(curl -fsS --max-time 15 "https://endoflife.date/api/${_slug}.json" 2>/dev/null)" || continue
	# Cycles still supported upstream: eol == false, or an eol date in the future.
	_cycles="$(printf '%s' "${_json}" | jq -r --arg today "${TODAY}" '
    .[]
    | select((.eol == false) or ((.eol | type == "string") and (.eol > $today)))
    | (.cycle | tostring)' 2>/dev/null)"
	[ -n "${_cycles}" ] || continue

	# Granularity of the existing floor (major-only vs major.minor).
	_segs=1
	case "${_cur}" in *.*) _segs=2 ;; esac

	# Lowest still-supported cycle at that granularity == the floor we want.
	_target=""
	for _c in ${_cycles}; do
		_nc="$(norm_cycle "${_c}" "${_segs}")"
		[ -n "${_nc}" ] || continue
		_ncn="$(steer_ver_num "${_nc}")"
		[ "${_ncn}" -gt 0 ] 2>/dev/null || continue
		if [ -z "${_target}" ] || [ "${_ncn}" -lt "$(steer_ver_num "${_target}")" ]; then
			_target="${_nc}"
		fi
	done
	[ -n "${_target}" ] || continue

	# Bump up only — never lower a floor that is stricter than upstream EOL.
	if [ "$(steer_ver_num "${_target}")" -gt "$(steer_ver_num "${_cur}")" ] 2>/dev/null; then
		REPORT="${REPORT}- ${_p}: minimum_supported ${_cur} → ${_target} (cycle ${_cur} no longer supported upstream)\n"
		BUMPS="${BUMPS}${_p} ${_target}\n"
	fi
done

if [ -z "${BUMPS}" ]; then
	exit 0
fi

if [ "${WRITE}" = 1 ]; then
	printf '%b' "${BUMPS}" | while IFS=' ' read -r _bp _bt; do
		[ -n "${_bp}" ] || continue
		for _t in ${TARGETS}; do
			[ -f "${_t}" ] && apply_floor "${_t}" "${_bp}" "${_bt}"
		done
	done
	printf 'Version policy floors raised to track upstream EOL:\n\n'
	printf '%b\n' "${REPORT}"
	exit 1
fi

printf 'Version policy is behind upstream EOL:\n\n'
printf '%b\n' "${REPORT}"
exit 1
