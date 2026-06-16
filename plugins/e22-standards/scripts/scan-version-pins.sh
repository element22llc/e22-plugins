#!/usr/bin/env sh
# e22-standards — repository version-pin scanner (the CI hard gate).
#
# The interactive hook (hooks/check-version-pins.sh) only sees the content a tool
# writes, and skips Bash command text. THIS scanner is the committed-state
# backstop: it walks a repo's infra/config/script files for pinned major versions
# and fails when a pin violates policy/versions.yml. Same policy file, same
# verdicts as the hook — deterministic, no network, no jq.
#
# SCOPE — a CONSERVATIVE LITERAL-PIN scanner, not a semantic analyzer. It matches
# literal `<product>:<version>` tokens (and `FROM <product>:<version>`) in:
#   compose.yaml/.yml, docker-compose.yaml/.yml, Dockerfile[.*], mise.toml/.mise.toml,
#   *.tf, *.sh, *.bash, *.yml, *.yaml
# It does NOT evaluate Terraform locals/vars/interpolation, shell variables, or
# templated values — a pin hidden behind `${VAR}` is NOT resolved and NOT flagged
# (reported as out of scope by omission, never false-positived). Unknown products
# are not enforced.
#
# SUPPRESS a deliberate pin: append `# e22:allow-pin <reason>` (legacy
# `# pin-ok: <reason>`) on the same line, and record an ADR (versioning policy).
#
# SECURITY: read-only; never executes repo content; no network; does not follow
# symlinks (POSIX find default); skips .git, dependency trees, build output;
# diagnostics print the matched token + location, never surrounding file content.
#
# USAGE: scan-version-pins.sh [repo-root]   (default: .)
# EXIT:  0 clean · 1 denied pin found · 2 config error (no/empty policy file)
# POSIX sh; no jq, no network.

ROOT="${1:-.}"
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# Locate the shared policy lib. In the plugin it lives at ../hooks/lib/; in a
# consumer repo the scaffold ships a verbatim copy alongside this script (kept
# byte-identical — enforced by check_standards.py).
for _cand in \
	"${HERE}/../hooks/lib/version-policy.sh" \
	"${HERE}/version-policy.sh" \
	"${HERE}/lib/version-policy.sh"; do
	if [ -f "${_cand}" ]; then
		# shellcheck disable=SC1090  # path resolved at runtime (plugin vs consumer layout)
		. "${_cand}"
		break
	fi
done
if ! command -v e22_policy_verdict >/dev/null 2>&1; then
	printf 'scan-version-pins: cannot locate version-policy.sh (config error).\n' >&2
	exit 2
fi

# Resolve the policy file: explicit override → repo-local → plugin-bundled.
if [ -n "${E22_POLICY_FILE:-}" ]; then
	POLICY="${E22_POLICY_FILE}"
elif [ -f "${ROOT}/policy/versions.yml" ]; then
	POLICY="${ROOT}/policy/versions.yml"
elif [ -f "${ROOT}/plugins/e22-standards/policy/versions.yml" ]; then
	POLICY="${ROOT}/plugins/e22-standards/policy/versions.yml"
else
	printf 'scan-version-pins: no policy/versions.yml found under %s (config error).\n' "${ROOT}" >&2
	exit 2
fi
[ -s "${POLICY}" ] || {
	printf 'scan-version-pins: policy file %s is empty (config error).\n' "${POLICY}" >&2
	exit 2
}

PRODUCTS='postgres|node|python|redis|valkey|nginx|mysql|mariadb|mongo'
PAT="(${PRODUCTS}):[0-9]+(\.[0-9]+)?"

# scan_file <path> — print "path:line: <detail>" for each DENIED pin.
scan_file() {
	_f="$1"
	grep -nE "${PAT}" "${_f}" 2>/dev/null | while IFS= read -r _m; do
		_ln="${_m%%:*}"
		_line="${_m#*:}"
		printf '%s' "${_line}" | grep -qE '(e22:allow-pin|pin-ok)' && continue
		for _pin in $(printf '%s' "${_line}" | grep -oE "${PAT}" | sort -u); do
			_verdict="$(e22_policy_verdict "${POLICY}" "${_pin%%:*}" "${_pin#*:}")"
			case "${_verdict}" in
			deny\ *) printf '%s:%s: %s\n' "${_f}" "${_ln}" "${_verdict#deny }" ;;
			*) : ;;
			esac
		done
	done
}

VIOLATIONS="$(
	find "${ROOT}" \
		\( -name .git -o -name node_modules -o -name .venv -o -name venv \
		-o -name vendor -o -name dist -o -name build -o -name target \
		-o -name .terraform -o -name .next -o -name .work \) -prune -o \
		-type f \( \
		-name 'compose.yaml' -o -name 'compose.yml' \
		-o -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
		-o -name 'Dockerfile' -o -name 'Dockerfile.*' \
		-o -name 'mise.toml' -o -name '.mise.toml' \
		-o -name '*.tf' -o -name '*.sh' -o -name '*.bash' \
		-o -name '*.yml' -o -name '*.yaml' \
		\) -print 2>/dev/null | while IFS= read -r _file; do
		scan_file "${_file}"
	done
)"

if [ -n "${VIOLATIONS}" ]; then
	printf 'Version-pin policy violations (source: %s):\n\n' "${POLICY}" >&2
	printf '%s\n\n' "${VIOLATIONS}" >&2
	printf 'Bump to a supported major, or annotate a deliberate pin with `# e22:allow-pin <reason>` and record an ADR.\n' >&2
	exit 1
fi

exit 0
