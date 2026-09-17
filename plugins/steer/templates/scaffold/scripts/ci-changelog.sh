#!/usr/bin/env sh
# steer - a change that ships must bring a changelog fragment.
# Rationale: /steer:reference conventions -> "Changelog".
# Deliberately delivery-mode-blind: in solo-trunk there is no PR, so this is the
# only thing between a trunk push and an unrecorded shipped change.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

# Paths that ship nothing. Matched against each changed path with `case`.
is_exempt() {
	case "$1" in
	spec/* | docs/* | .github/* | .claude/* | .vscode/* | .changes/*) return 0 ;;
	tests/* | test/* | */tests/* | */test/*) return 0 ;;
	# Prose ships no behaviour, wherever it lives. A docs change that IS worth an
	# entry can still have one - this only says it is never *required*.
	*.md) return 0 ;;
	esac
	return 1
}

if ! base="$(steer_ci_base)"; then
	steer_ci_notice 'No base ref to diff against - skipping the changelog gate (fail-open).'
	exit 0
fi

if [ ! -f .changie.yaml ]; then
	steer_ci_notice 'No .changie.yaml - repo has no changelog yet. Run /steer:sync to install it.'
	exit 0
fi

changed="$(git diff --name-only "${base}...HEAD" 2>/dev/null || git diff --name-only "${base}" HEAD)"

shipping=''
while IFS= read -r path; do
	[ -n "${path}" ] || continue
	is_exempt "${path}" || shipping="${shipping}${path}
"
done <<EOF
${changed}
EOF

if [ -z "${shipping}" ]; then
	printf 'ci:changelog - no shipping paths changed; no fragment required.\n'
	exit 0
fi

added="$(git diff --diff-filter=A --name-only "${base}...HEAD" -- .changes/unreleased/ 2>/dev/null ||
	git diff --diff-filter=A --name-only "${base}" HEAD -- .changes/unreleased/)"

if [ -n "${added}" ]; then
	printf 'ci:changelog - fragment present.\n'
	exit 0
fi

steer_ci_error "Shipping code changed but no changelog fragment was added under .changes/unreleased/. Run \`mise run changelog:new\`. Changed:$(printf '%s' "${shipping}" | cut -c1-300)"
exit 1
