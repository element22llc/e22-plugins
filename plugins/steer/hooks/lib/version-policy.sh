# shellcheck shell=sh
# steer helper — read + apply the version-pin policy (policy/versions.yml); sourced by the hook and the CI scanner.
# Not a general YAML parser: the policy file is fixed-shape (2-space product blocks, 4-space scalar fields).
# Rationale: /steer:reference conventions -> "Enforcement: the version-pin floor".

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

# steer_policy_has <file> <product>
steer_policy_has() {
	grep -qE "^  ${2}:[[:space:]]*(#.*)?$" "$1" 2>/dev/null
}

# steer_policy_field <file> <product> <field> — scalar value; empty if absent.
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

# steer_policy_denied <file> <product> — space-separated denied majors.
steer_policy_denied() {
	steer_policy_field "$1" "$2" denied | tr -d '[]' | tr ',' ' '
}

# steer_policy_verdict <file> <product> <version> — prints `unknown` | `ok` | `deny <detail>`. A floor, not a chooser.
steer_policy_verdict() {
	_f="$1"
	_p="$2"
	_v="$3"
	steer_policy_has "${_f}" "${_p}" || {
		printf 'unknown'
		return
	}
	_min="$(steer_policy_field "${_f}" "${_p}" minimum_supported)"
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
	printf 'ok'
}

# steer_policy_resolve <repo_root> — repo-local policy/versions.yml if present, else the plugin-bundled one; empty if neither.
steer_policy_resolve() {
	if [ -n "$1" ] && [ -f "$1/policy/versions.yml" ]; then
		printf '%s' "$1/policy/versions.yml"
	elif [ -f "${CLAUDE_PLUGIN_ROOT}/policy/versions.yml" ]; then
		printf '%s' "${CLAUDE_PLUGIN_ROOT}/policy/versions.yml"
	fi
}
