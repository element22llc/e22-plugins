#!/usr/bin/env sh
# steer — version-policy freshness check (advisory, CI/scheduled only).
#
# Compares policy/versions.yml `minimum_supported` floors against UPSTREAM
# end-of-life (endoflife.date) and prints products whose policy floor is already
# EOL upstream — i.e. the deterministic policy has drifted behind reality and
# should be raised. This is the ONLY place that consults the live source: it
# PROPOSES policy bumps (the scheduled workflow opens an issue from this output);
# it never enforces and never gates a build.
#
# Requires jq + curl (a controlled CI environment — unlike the enforcement path,
# which is dependency-free). Prints nothing when the policy is current.
#
# USAGE: check-policy-freshness.sh [policy-file]   (default: plugin-bundled)

set -u
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
. "${HERE}/../hooks/lib/version-policy.sh"

POLICY="${1:-${HERE}/../policy/versions.yml}"
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

# Products listed in the policy file (2-space keys under `products:`).
PRODUCTS="$(awk '/^products:/{p=1;next} p&&/^  [a-z]/{s=$1;sub(/:.*/,"",s);print s}' "${POLICY}")"

STALE=""
for _p in ${PRODUCTS}; do
	_slug="$(eol_slug "${_p}")"
	[ -n "${_slug}" ] || continue
	_min="$(steer_policy_field "${POLICY}" "${_p}" minimum_supported)"
	[ -n "${_min}" ] || continue
	_json="$(curl -fsS --max-time 15 "https://endoflife.date/api/${_slug}.json" 2>/dev/null)" || continue
	# eol for the cycle == minimum_supported ("false" = supported, else date/true).
	_eol="$(printf '%s' "${_json}" | jq -r --arg c "${_min}" '.[] | select((.cycle|tostring)==$c) | (.eol|tostring)' 2>/dev/null | head -n 1)"
	[ -n "${_eol}" ] || continue
	case "${_eol}" in
	false) : ;; # still supported upstream → policy floor is fine
	true) STALE="${STALE}- ${_p}: minimum_supported ${_min} is EOL upstream (raise the floor)\n" ;;
	*)
		# A date — EOL if in the past. POSIX has no string `<`, so sort the two
		# YYYY-MM-DD values (lexical == chronological) and check which is earliest.
		_today="$(date -u +%Y-%m-%d)"
		_earliest="$(printf '%s\n%s\n' "${_eol}" "${_today}" | sort | head -n 1)"
		if [ "${_earliest}" = "${_eol}" ] && [ "${_eol}" != "${_today}" ]; then
			STALE="${STALE}- ${_p}: minimum_supported ${_min} reached EOL ${_eol} (raise the floor)\n"
		fi
		;;
	esac
done

if [ -n "${STALE}" ]; then
	printf 'Version policy is behind upstream EOL:\n\n'
	printf '%b\n' "${STALE}"
	exit 1
fi
exit 0
