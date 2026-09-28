#!/usr/bin/env sh
# steer helper - convert legacy `- [ ]` open questions into `### Q-NNN` blocks.
#
# WHY THIS EXISTS
#   Before the structured open-question format, a question was a bare `- [ ]`
#   item under `## Open questions`. Nothing ever converted those: the ledger
#   left it to /steer:spec questions "as it touches them", so a feature nobody
#   revisited kept its checkboxes through every sync. A checkbox has no
#   status, owner or date, so the staleness escalation could never see it.
#   This is the mechanical half of the MIGRATIONS.md entry that ends that
#   window; /steer:setup sync runs it read-then-propose.
#
# WHAT IT CONVERTS
#   Exactly the items lib/questions.sh reports as legacy (`L` records): inside
#   `## Open questions`, outside any `### ` block, not a bracketed placeholder.
#   `- [ ]` gates elsewhere (`## PO acceptance`, acceptance criteria) are never
#   touched, and neither is a `- [x]` item. Each becomes:
#     ### Q-NNN - <the question>      (numbered after the file's highest id)
#     - created: <author date of the ORIGINAL checkbox line, from git blame>
#     - status: open / impact: non-blocking / owner: (blank = needs triage)
#     - required_before: / tracker:   (blank)
#   followed by any wrapped text or sub-bullets the item carried. The date must
#   come from the checkbox line: after conversion, blame would date the new
#   heading to the migration commit and every old question would read as new.
#   An uncommitted item has no date and gets a blank `created:` - never today.
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/convert-legacy-questions.sh" [--list|--apply] [repo-root]
#   (default mode prints the proposed change as a unified diff and writes
#    nothing; --list prints one `file:line: text` per item and is the ledger
#    precondition - empty means nothing to do; --apply rewrites the files)
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
	printf 'usage: convert-legacy-questions.sh [--list|--apply] [repo-root]\n' >&2
	exit 2
	;;
esac
ROOT="$(steer_repo_root "${1:-.}")" || ROOT="${1:-.}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/steer-convert-q.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

CONVERTED=0
UNDATED=0

convert_file() {
	_f="$1"
	_rel="${_f#"${ROOT}/"}"
	steer_questions_parse "${_f}" >"${TMP}/parse"
	grep -q '^L	' "${TMP}/parse" || return 0
	if [ "${MODE}" = list ]; then
		awk -F '\t' -v f="${_rel}" '$1 == "L" { printf "%s:%s: %s\n", f, $2, $3 }' "${TMP}/parse"
		return 0
	fi
	# Plan: one "C <line> <id> <date>" row per item, ids continuing past the
	# file's highest, dates from the checkbox line's commit ("-" when uncommitted).
	steer_questions_blame "${ROOT}" "${_f}" >"${TMP}/blame"
	cat "${TMP}/blame" "${TMP}/parse" | awk -F '\t' "${STEER_AWK_CIVIL_FROM_DAYS}"'
    $1 == "B" { t[$2] = $3; next }
    $1 == "N" { max = $2 + 0; next }
    $1 == "L" { n++; line[n] = $2; next }
    END {
      for (i = 1; i <= n; i++) {
        d = (line[i] in t) ? civil_from_days(int(t[line[i]] / 86400)) : "-"
        printf "C\t%d\tQ-%03d\t%s\n", line[i], max + i, d
      }
    }' >"${TMP}/plan"
	awk -F '\t' '
    FNR == NR { id[$2] = $3; created[$2] = $4; next }
    function flush(   q, body, k) {
      if (!open) return
      # Title = the question up to its first "?", the rest becomes context.
      q = text; body = ""
      k = index(q, "?")
      if (k > 0 && k < length(q)) { body = substr(q, k + 1); q = substr(q, 1, k); sub(/^[[:space:]]+/, "", body) }
      if (last != "") print ""
      printf "### %s - %s\n\n", cur_id, q
      if (cur_created == "-") print "- created:"; else printf "- created: %s\n", cur_created
      print "- status: open"
      print "- impact: non-blocking"
      print "- owner:"
      print "- required_before:"
      print "- tracker:"
      if (body != "") printf "\n%s\n", body
      if (extra != "") printf "\n%s", extra
      open = 0; text = ""; extra = ""; pending = 1; last = "x"
    }
    function out(s) {
      if (pending && s != "") print ""
      pending = 0; print s; last = s
    }
    {
      # Inside an item: indented non-blank lines belong to it - a wrapped
      # sentence joins the question, a sub-bullet is kept as context.
      if (open) {
        if ($0 ~ /^[[:space:]]+[^[:space:]]/) {
          s = $0; sub(/^  /, "", s)
          if (s ~ /^[[:space:]]*([-*+]|[0-9]+\.)[[:space:]]/ || extra != "") extra = extra s "\n"
          else { sub(/^[[:space:]]+/, "", s); text = text " " s }
          next
        }
        flush()
      }
      if (FNR in id) {
        open = 1; cur_id = id[FNR]; cur_created = created[FNR]
        text = substr($0, 7); sub(/[[:space:]]+$/, "", text)
        next
      }
      out($0)
    }
    END { flush() }
  ' "${TMP}/plan" "${_f}" >"${TMP}/new"
	_n="$(grep -c '^C	' "${TMP}/plan")"
	_u="$(grep -c '	-$' "${TMP}/plan")"
	CONVERTED=$((CONVERTED + _n))
	UNDATED=$((UNDATED + _u))
	if [ "${MODE}" = apply ]; then
		cat "${TMP}/new" >"${_f}"
		printf '%s: converted %s\n' "${_rel}" "${_n}"
	else
		diff -u -L "a/${_rel}" -L "b/${_rel}" "${_f}" "${TMP}/new"
	fi
}

for _q in "${ROOT}/spec/vision.md" "${ROOT}"/spec/features/*/intent.md "${ROOT}/spec/PRODUCTIONIZATION.md"; do
	[ -f "${_q}" ] || continue
	convert_file "${_q}"
done

if [ "${MODE}" != list ] && [ "${CONVERTED}" -gt 0 ]; then
	printf '%s legacy question(s) %s.\n' "${CONVERTED}" "$([ "${MODE}" = apply ] && echo converted || echo 'to convert')" >&2
	[ "${UNDATED}" -gt 0 ] && printf '%s have no committed date, so their created: stays blank.\n' "${UNDATED}" >&2
fi
exit 0
