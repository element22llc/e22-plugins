#!/usr/bin/env sh
# Preview the always-on ruleset a real session would receive.
#
# Authoring a rule is partly blind: rules/*.md are concatenated by
# hooks/inject-standards.sh, and any rule carrying a first-line
# `<!-- steer:inject-when=<token> -->` marker is injected only when that scope
# holds for the CONSUMER repo. So the payload differs per repo, and neither the
# file on disk nor `check_context_budget.py`'s total tells you what a given repo
# actually gets. This prints exactly that.
#
#     sh scripts/rules-preview.sh                 # this repo
#     sh scripts/rules-preview.sh --repo ../app   # some consumer repo
#     sh scripts/rules-preview.sh --knowledge     # a non-code (PO) folder
#     sh scripts/rules-preview.sh --full          # also dump the injected text
#
# Reuse, not reimplementation — the two halves both run shipped code:
#   * the BUNDLE is the real hooks/inject-standards.sh, run on a synthetic
#     SessionStart payload, so the byte total is what a session truly pays;
#   * the PER-RULE table calls the real lib/scope.sh predicates
#     (steer_work_mode, steer_inject_when_ok), so kept/dropped can't drift from
#     what the hook decided.
# The ratchet ceiling is read out of scripts/check_context_budget.py for the
# same reason. Read-only: no repo is written to, including --repo.

set -u

ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
PLUGIN="${ROOT}/plugins/steer"
RULES_DIR="${PLUGIN}/rules"
BUDGET_PY="${ROOT}/scripts/check_context_budget.py"

TARGET="."
FULL=0
KNOWLEDGE=0

usage() {
	cat <<'EOF'
Usage: sh scripts/rules-preview.sh [options]

  --repo <path>   Preview what this repo would receive (default: the cwd).
  --knowledge     Preview a knowledge-work folder: runs against an empty temp
                  dir, which the real classifier reads as a non-code folder.
                  Mutually exclusive with --repo.
  --full          Also print the complete injected text to stdout.
  -h, --help      Show this help.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--repo)
		[ $# -ge 2 ] || {
			printf 'rules-preview: --repo needs a path\n' >&2
			exit 2
		}
		TARGET="$2"
		shift 2
		;;
	--knowledge)
		KNOWLEDGE=1
		shift
		;;
	--full)
		FULL=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		printf 'rules-preview: unknown argument %s\n' "$1" >&2
		usage >&2
		exit 2
		;;
	esac
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/steer-rules-preview.XXXXXX")" || exit 1
trap 'rm -rf "${WORK}"' EXIT

if [ "${KNOWLEDGE}" -eq 1 ]; then
	# An empty, non-git dir carries no code markers, so the REAL steer_work_mode
	# classifies it 'knowledge'. We don't force the mode — we hand the classifier
	# a folder that genuinely is one.
	TARGET="${WORK}/knowledge-folder"
	mkdir -p "${TARGET}"
fi

[ -d "${TARGET}" ] || {
	printf 'rules-preview: not a directory: %s\n' "${TARGET}" >&2
	exit 2
}
TARGET="$(CDPATH='' cd -- "${TARGET}" && pwd)"

[ -d "${RULES_DIR}" ] || {
	printf 'rules-preview: no rules dir at %s\n' "${RULES_DIR}" >&2
	exit 1
}

# --- the bundle: drive the real hook -----------------------------------------

export CLAUDE_PLUGIN_ROOT="${PLUGIN}"
BUNDLE="${WORK}/bundle.md"
printf '{"session_id":"rules-preview","cwd":"%s","hook_event_name":"SessionStart"}' \
	"${TARGET}" | sh "${PLUGIN}/hooks/inject-standards.sh" >"${BUNDLE}" || {
	printf 'rules-preview: inject-standards.sh failed\n' >&2
	exit 1
}
INJECTED_BYTES="$(wc -c <"${BUNDLE}" | tr -d ' ')"

# --- the per-rule table: call the real predicates -----------------------------

# shellcheck source=/dev/null
. "${PLUGIN}/hooks/lib/repo-root.sh"
# shellcheck source=/dev/null
. "${PLUGIN}/hooks/lib/scope.sh"

MODE="$(steer_work_mode "${TARGET}")"
CONSUMER_ROOT="$(steer_repo_root "${TARGET}" 2>/dev/null)" || CONSUMER_ROOT=""

printf 'repo:      %s\n' "${TARGET}"
if [ "${MODE}" = knowledge ]; then
	printf 'work mode: knowledge (every marked rule is skipped)\n'
	printf 'git root:  <none — a knowledge folder is not a git repo>\n\n'
else
	printf 'work mode: code (full ruleset, subject to per-rule scope)\n'
	printf 'git root:  %s\n\n' \
		"${CONSUMER_ROOT:-<none — every scope predicate fails open>}"
fi

printf '%-28s  %-7s  %8s  %s\n' 'RULE' 'STATUS' 'BYTES' 'SCOPE'
printf '%-28s  %-7s  %8s  %s\n' '----' '------' '-----' '-----'

KEPT=0
DROPPED=0
DROPPED_BYTES=0

for f in "${RULES_DIR}"/*.md; do
	[ -e "${f}" ] || continue
	name="$(basename "${f}")"
	IFS= read -r first <"${f}" || first=""

	case "${first}" in
	'<!-- steer:inject-when='*' -->')
		token="${first#<!-- steer:inject-when=}"
		token="${token% -->}"
		# The marker line is stripped by the hook, so it costs nothing.
		bytes="$(($(tail -n +2 "${f}" | wc -c | tr -d ' ') + 2))"
		if [ "${MODE}" = knowledge ]; then
			status="skip"
			scope="${token} (knowledge mode)"
		elif steer_inject_when_ok "${token}" "${CONSUMER_ROOT}"; then
			status="inject"
			scope="${token}"
		else
			status="skip"
			scope="${token} (not met)"
		fi
		;;
	*)
		bytes="$(($(wc -c <"${f}" | tr -d ' ') + 2))"
		status="inject"
		scope="always-on"
		;;
	esac

	if [ "${status}" = inject ]; then
		KEPT=$((KEPT + 1))
	else
		DROPPED=$((DROPPED + 1))
		DROPPED_BYTES=$((DROPPED_BYTES + bytes))
	fi
	printf '%-28s  %-7s  %8s  %s\n' "${name}" "${status}" "${bytes}" "${scope}"
done

# --- totals vs the ratchet ----------------------------------------------------

# Read the ceiling from the gate so the two can never disagree. Missing or
# unparseable → report the total without a verdict rather than invent a bar.
CEILING="$(sed -n 's/^RULES_TOTAL_MAX_BYTES[[:space:]]*=[[:space:]]*\([0-9_]*\).*/\1/p' \
	"${BUDGET_PY}" 2>/dev/null | head -n 1 | tr -d '_')"

printf '\n%s injected, %s skipped (%s B reclaimed)\n' \
	"${KEPT}" "${DROPPED}" "${DROPPED_BYTES}"

if [ -n "${CEILING}" ]; then
	printf 'injected payload: %s B  (ratchet %s B for rules/*.md on disk)\n' \
		"${INJECTED_BYTES}" "${CEILING}"
	printf 'note: the ratchet gates the on-disk total; this repo receives %s B.\n' \
		"${INJECTED_BYTES}"
else
	printf 'injected payload: %s B\n' "${INJECTED_BYTES}"
fi

if [ "${FULL}" -eq 1 ]; then
	printf '\n----- injected text -----\n'
	cat "${BUNDLE}"
fi
