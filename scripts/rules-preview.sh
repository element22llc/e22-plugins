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
#   * the BUNDLE is the real hooks/inject-standards.sh — every part hooks.json
#     registers, concatenated — run on a synthetic
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
HOOK_ERR="${WORK}/hook.err"
PAYLOAD="$(printf '{"session_id":"rules-preview","cwd":"%s","hook_event_name":"SessionStart"}' "${TARGET}")"

# How many parts hooks.json registers — the same manifest the runtime reads.
# (Backslashes stripped first: the JSON escapes the quotes around the path.)
PARTS="$(tr -d '\\' <"${PLUGIN}/hooks/hooks.json" 2>/dev/null | grep -c 'inject-standards\.sh" [0-9]* [0-9]*"' | tr -d ' ')"
[ "${PARTS:-0}" -ge 1 ] || PARTS=1

# Run every part, keep each one (to attribute rules to parts below), and
# concatenate them into the bundle.
: >"${BUNDLE}"
: >"${HOOK_ERR}"
PARTS_USED=0
LARGEST_PART=0
k=1
while [ "${k}" -le "${PARTS}" ]; do
	printf '%s' "${PAYLOAD}" |
		sh "${PLUGIN}/hooks/inject-standards.sh" "${k}" "${PARTS}" >"${WORK}/part-${k}.md" 2>>"${HOOK_ERR}" || {
		printf 'rules-preview: inject-standards.sh part %s/%s failed\n' "${k}" "${PARTS}" >&2
		exit 1
	}
	_pc="$(LC_ALL=C tr -d '\200-\277' <"${WORK}/part-${k}.md" | wc -c | tr -d ' ')"
	[ "${_pc}" -gt 0 ] && PARTS_USED=$((PARTS_USED + 1))
	[ "${_pc}" -gt "${LARGEST_PART}" ] && LARGEST_PART="${_pc}"
	cat "${WORK}/part-${k}.md" >>"${BUNDLE}"
	k=$((k + 1))
done
INJECTED_CHARS="$(LC_ALL=C tr -d '\200-\277' <"${BUNDLE}" | wc -c | tr -d ' ')"
INJECTED_BYTES="$(wc -c <"${BUNDLE}" | tr -d ' ')"

# Rules the hook's cap guard had to leave out. Scope eligibility and *delivery*
# are two different questions: a rule can pass every scope predicate and still
# never reach the session because the registered parts were full. Read the
# hook's own stderr list (complete, unlike the in-band notice, which names a
# few and then counts) rather than re-deriving the budget.
CAPPED="$(sed -n 's/^steer-inject: dropped([0-9]*)://p' "${HOOK_ERR}" | head -n 1)"

# Which part a rule landed in: the first line of its body (after any marker) is
# looked up in each part file. Prints the part number, or '-' if not found.
part_of() { # <rule-file> <skip-marker?>
	if [ "$2" -eq 1 ]; then
		_line="$(sed -n '2p' "$1")"
	else
		_line="$(sed -n '1p' "$1")"
	fi
	[ -n "${_line}" ] || {
		printf -- '-'
		return
	}
	_k=1
	while [ "${_k}" -le "${PARTS}" ]; do
		if grep -qxF -- "${_line}" "${WORK}/part-${_k}.md" 2>/dev/null; then
			printf '%s' "${_k}"
			return
		fi
		_k=$((_k + 1))
	done
	printf -- '-'
}

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

printf '%-28s  %-7s  %5s  %6s  %s\n' 'RULE' 'STATUS' 'PART' 'CHARS' 'SCOPE'
printf '%-28s  %-7s  %5s  %6s  %s\n' '----' '------' '----' '-----' '-----'

KEPT=0
DROPPED=0
DROPPED_BYTES=0
CAPPED_N=0
CAPPED_BYTES=0

# The runtime cap and the per-part budget, read out of the hook (the enforcing
# side) so this preview can never disagree with it.
CAP_CHARS="$(sed -n 's/^STEER_INJECT_CAP=\([0-9]*\)$/\1/p' "${PLUGIN}/hooks/inject-standards.sh" | head -n 1)"
PART_BUDGET="$(sed -n 's/^STEER_INJECT_PART_BUDGET=\([0-9]*\)$/\1/p' "${PLUGIN}/hooks/inject-standards.sh" | head -n 1)"

for f in "${RULES_DIR}"/*.md; do
	[ -e "${f}" ] || continue
	name="$(basename "${f}")"
	IFS= read -r first <"${f}" || first=""

	case "${first}" in
	'<!-- steer:inject-when='*' -->')
		token="${first#<!-- steer:inject-when=}"
		token="${token% -->}"
		# The marker line is stripped by the hook, so it costs nothing.
		bytes="$(($(tail -n +2 "${f}" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' ') + 2))"
		skip=1
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
		bytes="$(($(LC_ALL=C tr -d '\200-\277' <"${f}" | wc -c | tr -d ' ') + 2))"
		status="inject"
		scope="always-on"
		skip=0
		;;
	esac

	# A scope-eligible rule that the cap guard dropped never reaches the session.
	# Report it as CAPPED, not "inject" — conflating the two is what let a
	# 61 KB payload read as fully delivered.
	part="-"
	if [ "${status}" = inject ]; then
		case " ${CAPPED} " in
		*" ${name} "*)
			status="CAPPED"
			scope="${scope} — did not fit the ${PARTS} registered part(s), NOT delivered"
			;;
		*)
			part="$(part_of "${f}" "${skip}")"
			;;
		esac
	fi

	case "${status}" in
	inject)
		KEPT=$((KEPT + 1))
		;;
	CAPPED)
		CAPPED_N=$((CAPPED_N + 1))
		CAPPED_BYTES=$((CAPPED_BYTES + bytes))
		;;
	*)
		DROPPED=$((DROPPED + 1))
		DROPPED_BYTES=$((DROPPED_BYTES + bytes))
		;;
	esac
	printf '%-28s  %-7s  %5s  %6s  %s\n' "${name}" "${status}" "${part}" "${bytes}" "${scope}"
done

# --- totals vs the cap --------------------------------------------------------

# Same pessimistic 3.5 B/token the gate documents; integer arithmetic in sh.
INJECTED_TOKENS=$((INJECTED_BYTES * 10 / 35))

printf '\n%s delivered, %s out of scope (%s chars reclaimed)\n' \
	"${KEPT}" "${DROPPED}" "${DROPPED_BYTES}"
printf 'injected payload: %s chars (%s B, ~%s tokens @3.5 B/tok) in %s of %s registered part(s); largest part %s chars\n' \
	"${INJECTED_CHARS}" "${INJECTED_BYTES}" "${INJECTED_TOKENS}" "${PARTS_USED}" "${PARTS}" "${LARGEST_PART}"
if [ -n "${CAP_CHARS}" ] && [ -n "${PART_BUDGET}" ]; then
	printf 'runtime cap:      %s characters per hook command (Claude Code; not a policy number) — each part is filled to %s; capacity %s chars, %s spare\n' \
		"${CAP_CHARS}" "${PART_BUDGET}" "$((PARTS * PART_BUDGET))" "$((PARTS * PART_BUDGET - INJECTED_CHARS))"
fi
if [ "${CAPPED_N}" -gt 0 ]; then
	printf '\n!! %s rule(s) (%s chars) are in scope for this repo but did NOT fit the registered parts.\n' \
		"${CAPPED_N}" "${CAPPED_BYTES}"
	printf '   A session here never receives them. Trade prose out to templates/reference/*,\n'
	printf '   scope the rule with an inject-when marker, or — deliberately — register one\n'
	printf '   more part in hooks/hooks.json (scripts/check_context_budget.py gates this).\n'
fi

if [ "${FULL}" -eq 1 ]; then
	printf '\n----- injected text -----\n'
	cat "${BUNDLE}"
fi
