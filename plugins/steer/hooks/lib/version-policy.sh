# shellcheck shell=sh
# steer helper — read + apply the deterministic version-pin policy
# (policy/versions.yml). Shared by the interactive hook (check-version-pins.sh)
# and the CI scanner (scan-version-pins.sh) so both enforce ONE source of truth,
# identically, with no network call and no jq dependency.
#
# The policy file is intentionally a tiny, fixed-shape YAML (2-space product
# blocks, 4-space scalar fields) so a POSIX awk parse is reliable — this is NOT a
# general YAML parser.

# steer_ver_num <maj[.min]> — comparable integer (major*1000 + minor).
steer_ver_num() {
	_maj="${1%%.*}"
	_rest="${1#*.}"
	[ "${_rest}" = "$1" ] && _rest=0
	_min="${_rest%%.*}"
	case "${_maj}${_min}" in
	*[!0-9]*)
		printf '0'
		return
		;;
	esac
	printf '%d' "$((_maj * 1000 + _min))"
}

# steer_policy_has <file> <product> — true if the product has a policy block.
steer_policy_has() {
	grep -qE "^  ${2}:[[:space:]]*(#.*)?$" "$1" 2>/dev/null
}

# steer_policy_field <file> <product> <field> — scalar field value (quotes, spaces,
# and trailing comments stripped). Empty if absent.
steer_policy_field() {
	awk -v p="$2" -v k="$3" '
    $0 ~ "^  " p ":[ \t]*(#.*)?$" { inp = 1; next }
    /^  [A-Za-z]/ { inp = 0 }
    inp && $0 ~ "^    " k ":" {
      line = $0
      sub(/^    [A-Za-z_]+:[ \t]*/, "", line)
      sub(/[ \t]*#.*$/, "", line)
      gsub(/"/, "", line)
      gsub(/[ \t]/, "", line)
      print line
      exit
    }
  ' "$1" 2>/dev/null
}

# steer_policy_denied <file> <product> — space-separated denied majors (may be empty).
steer_policy_denied() {
	steer_policy_field "$1" "$2" denied | tr -d '[]' | tr ',' ' '
}

# steer_policy_verdict <file> <product> <version> — prints one line:
#   unknown                      product not in policy → not enforced
#   ok                           at/above the org target
#   advise <detail>             supported, but below the recommended target
#   deny <detail>               below minimum_supported or explicitly denied
steer_policy_verdict() {
	_f="$1"
	_p="$2"
	_v="$3"
	steer_policy_has "${_f}" "${_p}" || {
		printf 'unknown'
		return
	}
	_min="$(steer_policy_field "${_f}" "${_p}" minimum_supported)"
	_rec="$(steer_policy_field "${_f}" "${_p}" recommended)"
	_vmaj="${_v%%.*}"
	for _d in $(steer_policy_denied "${_f}" "${_p}"); do
		if [ "${_d}" = "${_v}" ] || [ "${_d}" = "${_vmaj}" ]; then
			printf 'deny %s:%s is denied by the version policy (minimum_supported %s)' "${_p}" "${_v}" "${_min}"
			return
		fi
	done
	if [ -n "${_min}" ] && [ "$(steer_ver_num "${_v}")" -lt "$(steer_ver_num "${_min}")" ] 2>/dev/null; then
		printf 'deny %s:%s is below the minimum supported %s' "${_p}" "${_v}" "${_min}"
		return
	fi
	if [ -n "${_rec}" ] && [ "$(steer_ver_num "${_v}")" -lt "$(steer_ver_num "${_rec}")" ] 2>/dev/null; then
		printf 'advise %s:%s is supported but the target is %s' "${_p}" "${_v}" "${_rec}"
		return
	fi
	printf 'ok'
}

# steer_policy_resolve <repo_root> — the policy file to use: the repo-local
# policy/versions.yml if present (consumers may extend), else the plugin-bundled
# default. Empty if neither exists.
steer_policy_resolve() {
	if [ -n "$1" ] && [ -f "$1/policy/versions.yml" ]; then
		printf '%s' "$1/policy/versions.yml"
	elif [ -f "${CLAUDE_PLUGIN_ROOT}/policy/versions.yml" ]; then
		printf '%s' "${CLAUDE_PLUGIN_ROOT}/policy/versions.yml"
	fi
}
