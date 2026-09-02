#!/usr/bin/env sh
# steer — CI version-pin scanner: fails on literal `<product>:<version>` pins that violate policy/versions.yml.
# Usage: scan-version-pins.sh [repo-root]   Exit: 0 clean · 1 denied pin · 2 config error (no/empty policy)
# Suppress a deliberate pin with `# steer:allow-pin <reason>` (legacy `# pin-ok: <reason>`) + an ADR.
# Rationale: /steer:reference conventions -> "Enforcement: the version-pin floor".

ROOT="${1:-.}"
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# Plugin layout keeps the lib at ../hooks/lib/; the consumer scaffold ships a byte-identical copy beside this script.
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
if ! command -v steer_policy_verdict >/dev/null 2>&1; then
	printf 'scan-version-pins: cannot locate version-policy.sh (config error).\n' >&2
	exit 2
fi

if [ -n "${STEER_POLICY_FILE:-}" ]; then
	POLICY="${STEER_POLICY_FILE}"
elif [ -f "${ROOT}/policy/versions.yml" ]; then
	POLICY="${ROOT}/policy/versions.yml"
elif [ -f "${ROOT}/plugins/steer/policy/versions.yml" ]; then
	POLICY="${ROOT}/plugins/steer/policy/versions.yml"
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

scan_file() {
	_f="$1"
	grep -nE "${PAT}" "${_f}" 2>/dev/null | while IFS= read -r _m; do
		_ln="${_m%%:*}"
		_line="${_m#*:}"
		printf '%s' "${_line}" | grep -qE '(steer:allow-pin|pin-ok)' && continue
		for _pin in $(printf '%s' "${_line}" | grep -oE "${PAT}" | sort -u); do
			_verdict="$(steer_policy_verdict "${POLICY}" "${_pin%%:*}" "${_pin#*:}")"
			case "${_verdict}" in
			deny\ *) printf '%s:%s: %s\n' "${_f}" "${_ln}" "${_verdict#deny }" ;;
			*) : ;;
			esac
		done
	done
}

VIOLATIONS="$(
	# Prune .claude/worktrees by PATH (not -name): linked worktrees are full checkouts, so each file would be reported once per worktree.
	find "${ROOT}" \
		\( -path '*/.claude/worktrees' -o -name .git -o -name node_modules \
		-o -name .venv -o -name venv \
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
	# shellcheck disable=SC2016  # backticks here are literal markdown in the message, not command substitution
	printf 'Bump to a supported major, or annotate a deliberate pin with `# steer:allow-pin <reason>` and record an ADR.\n' >&2
	exit 1
fi

exit 0
