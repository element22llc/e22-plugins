#!/usr/bin/env sh
# steer helper - drop unfilled `### Q-001` placeholder seeds that have outlived
# their purpose.
#
# WHY THIS EXISTS
#   The feature-intent template seeds `## Open questions` with a
#   `<!-- steer:placeholder -->` example block so a fresh draft shows the format.
#   An open-question scaffold reconcile inserted that seed into features that
#   were long approved, and nothing ever removed an unfilled one. Anything that
#   does not know the placeholder convention reads each as an open blocking
#   question. This is the mechanical half of the MIGRATIONS.md entry that clears
#   them; /steer:setup sync runs it read-then-propose, and /steer:spec approve
#   drops the seed itself on the draft -> approved write.
#
# WHAT IT REMOVES
#   A seed block (`P` record from lib/questions.sh) whose heading still carries
#   the bracketed template title, when EITHER its feature's Status is past
#   `draft`, OR the same section already holds a real `### Q-NNN` question -
#   exactly what the scaffolded ci-spec.sh gate fails on. A seed in a draft
#   feature with nothing else is left alone: there it is still the example.
#   The block runs from its heading to the next heading, its `_Resolution:_`
#   line included; surrounding blank lines are collapsed to one.
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/remove-question-seeds.sh" [--list|--apply] [repo-root]
#   (default prints the proposed change as a unified diff and writes nothing;
#    --list prints one `file:line: id` per seed and is the ledger precondition;
#    --apply rewrites the files)
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh + awk, no jq.

set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
. "${PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${PLUGIN_ROOT}/hooks/lib/questions.sh"

MODE="diff"
case "${1:-}" in
--list) MODE=list && shift ;;
--apply) MODE=apply && shift ;;
--*)
	printf 'usage: remove-question-seeds.sh [--list|--apply] [repo-root]\n' >&2
	exit 2
	;;
esac
ROOT="$(steer_repo_root "${1:-.}")" || ROOT="${1:-.}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/steer-seeds.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

REMOVED=0

seed_file() {
	_f="$1"
	_rel="${_f#"${ROOT}/"}"
	# Seeds to drop, as "<line>\t<id>": past draft, or beside a real question,
	# and still carrying the bracketed template title.
	steer_questions_parse "${_f}" | awk -F '\t' '
    $1 == "S" { past = ($2 ~ /^(approved|live|implemented|validated)$/); next }
    $1 == "Q" { real++; next }
    $1 == "P" { n++; line[n] = $2; id[n] = $3; next }
    END { if (past || real) for (i = 1; i <= n; i++) printf "%s\t%s\n", line[i], id[i] }
  ' >"${TMP}/cands"
	: >"${TMP}/seeds"
	while IFS="$(printf '\t')" read -r _ln _id; do
		sed -n "${_ln}p" "${_f}" | grep -q '^###[[:space:]]*Q-[0-9]*[[:space:]]*-[[:space:]]*\[' &&
			printf '%s\t%s\n' "${_ln}" "${_id}" >>"${TMP}/seeds"
	done <"${TMP}/cands"
	[ -s "${TMP}/seeds" ] || return 0
	if [ "${MODE}" = list ]; then
		awk -F '\t' -v f="${_rel}" '{ printf "%s:%s: %s\n", f, $1, $2 }' "${TMP}/seeds"
		return 0
	fi
	awk -F '\t' '
    FNR == NR { cut[$1] = 1; next }
    {
      if (FNR in cut) { skipping = 1; cutsince = 1; next }
      if (skipping) { if ($0 ~ /^(# |## |### )/) skipping = 0; else next }
      if ($0 == "") { blanks++; next }
      if (blanks) { k = cutsince ? 1 : blanks; for (i = 0; i < k; i++) print "" }
      blanks = 0; cutsince = 0
      print
    }
    END { if (blanks && !cutsince) for (i = 0; i < blanks; i++) print "" }
  ' "${TMP}/seeds" "${_f}" >"${TMP}/new"
	REMOVED=$((REMOVED + $(grep -c . "${TMP}/seeds")))
	if [ "${MODE}" = apply ]; then
		cat "${TMP}/new" >"${_f}"
		printf '%s: removed %s\n' "${_rel}" "$(grep -c . "${TMP}/seeds")"
	else
		diff -u -L "a/${_rel}" -L "b/${_rel}" "${_f}" "${TMP}/new"
	fi
}

for _q in "${ROOT}/spec/vision.md" "${ROOT}"/spec/features/*/intent.md "${ROOT}/spec/PRODUCTIONIZATION.md"; do
	[ -f "${_q}" ] || continue
	seed_file "${_q}"
done

if [ "${MODE}" != list ] && [ "${REMOVED}" -gt 0 ]; then
	printf '%s placeholder seed(s) %s.\n' "${REMOVED}" "$([ "${MODE}" = apply ] && echo removed || echo 'to remove')" >&2
fi
exit 0
