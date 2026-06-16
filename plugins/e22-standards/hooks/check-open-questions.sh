#!/usr/bin/env sh
# e22-standards SessionStart hook — open-questions nudge (anti-rot).
#
# WHY THIS EXISTS
#   Open questions in the spec spine (each feature's intent.md → "## Open
#   questions", and vision.md / PRODUCTIONIZATION.md) get written down once,
#   gated at PO acceptance, then forgotten. Nothing resurfaces them, so they
#   rot. The /e22-standards:e22-questions skill resolves them — but a skill is
#   pull, not push: it only runs when someone remembers to invoke it. This hook
#   makes the backlog visible every session so it can't quietly accumulate.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path
#   as inject-standards.sh / check-template-drift.sh). The hook stays SILENT
#   when there are no open questions, so a clean repo gets zero noise and the
#   notice clears itself once questions are answered or explicitly deferred.
#
#   Questions use the structured contract (see templates/spec/feature-intent.md):
#     ### Q-001 — title
#     - status: open            # open | investigating | resolved | deferred | cancelled
#     - impact: blocking        # blocking | non-blocking
#     - required_before: intent-approval
#   Counted when status ∈ {open, investigating}. Blocking questions are split
#   into "blocks now" vs "blocks a later transition" using the shared
#   lifecycle-ordering contract (lib/lifecycle.sh) against the feature's Status.
#   Malformed blocks (missing status/impact) are surfaced as needs-attention
#   rather than silently dropped. Legacy `- [ ]` checkboxes are still counted
#   (as backlog) for one deprecation window.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/lifecycle.sh"

# SessionStart payload carries cwd (may be a subdir); anchor spec lookups at the
# work-tree root. Not a git repo → fall back to cwd (a spec/ may still be
# addressable relatively).
# shellcheck disable=SC2034  # consumed by e22_field (lib/json.sh) via $E22_INPUT
E22_INPUT="$(cat 2>/dev/null)"
CWD="$(e22_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(e22_repo_root "${CWD}")" || ROOT="${CWD}"

RB_ORDER="$(e22_required_before_order)"

# rank_of <token> — 1-based position of a gate token in the lifecycle order, or
# 0 when absent/unknown.
rank_of() {
	_i=0
	for _t in ${RB_ORDER}; do
		_i=$((_i + 1))
		[ "${_t}" = "$1" ] && {
			printf '%s' "${_i}"
			return 0
		}
	done
	printf '0'
}

# count_open <file> — prints "now trans backlog attn" for one spec file.
count_open() {
	_f="$1"
	[ -f "${_f}" ] || {
		printf '0 0 0 0'
		return 0
	}
	# Feature Status → the gate it has already cleared → that gate's rank. Only the
	# header is scanned (stop at "## Open questions") so a question's own `status:`
	# bullet is never mistaken for the feature Status. vision / productionization
	# have no Status line → cleared rank 0 (nothing cleared).
	_status="$(awk '
    /^## Open questions/ { exit }
    tolower($0) ~ /^[>*#[:space:]]*status:/ {
      sub(/^[>*#[:space:]]*[Ss][Tt][Aa][Tt][Uu][Ss]:[[:space:]]*/, "")
      sub(/[[:space:]|].*$/, "")
      print tolower($0); exit
    }' "${_f}")"
	_cleared="$(rank_of "$(e22_status_cleared_gate "${_status}")")"

	awk -v rborder="${RB_ORDER}" -v cleared="${_cleared}" '
    function endblock() {
      if (inblk && !skip) {
        if (q_status == "") { attn++ }
        else if (q_status == "open" || q_status == "investigating") {
          if (q_impact == "") { attn++ }
          else if (q_impact == "blocking") {
            r = (q_rb in rank) ? rank[q_rb] : 0
            if (r == 0 || r <= cleared + 1) { now++ } else { trans++ }
          } else { backlog++ }
        }
      }
      inblk = 0; skip = 0; q_status = ""; q_impact = ""; q_rb = ""
    }
    BEGIN { n = split(rborder, a, " "); for (i = 1; i <= n; i++) rank[a[i]] = i }
    /^## Open questions/ { endblock(); inq = 1; next }
    /^## / { endblock(); inq = 0 }
    /^# /  { endblock(); inq = 0 }
    inq && /^### / {
      endblock()
      inblk = 1
      skip = ($0 ~ /e22:placeholder/) ? 1 : 0
      next
    }
    inq && inblk {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      if (line ~ /^status:/)              { v = line; sub(/^status:[[:space:]]*/, "", v);          sub(/[[:space:]].*$/, "", v); q_status = tolower(v) }
      else if (line ~ /^impact:/)         { v = line; sub(/^impact:[[:space:]]*/, "", v);          sub(/[[:space:]].*$/, "", v); q_impact = tolower(v) }
      else if (line ~ /^required_before:/) { v = line; sub(/^required_before:[[:space:]]*/, "", v); sub(/[[:space:]].*$/, "", v); q_rb = v }
    }
    # Legacy checkbox format (pre-structured) — counted as backlog, skipping the
    # old bracketed [placeholder] seed.
    inq && !inblk && /^- \[ \] / {
      rest = substr($0, 7)
      if (rest !~ /^\[/) backlog++
    }
    END { endblock(); printf "%d %d %d %d", now + 0, trans + 0, backlog + 0, attn + 0 }
  ' "${_f}"
}

NOW=0
TRANS=0
BACKLOG=0
ATTN=0
REPORT=""

# args: file
check_file() {
	# Intentional word-splitting: count_open prints four space-separated integers.
	# shellcheck disable=SC2046
	set -- $(count_open "$1")
	_now="$1"
	_trans="$2"
	_backlog="$3"
	_attn="$4"
	_sum=$((_now + _trans + _backlog + _attn))
	[ "${_sum}" -gt 0 ] 2>/dev/null || return 0
	NOW=$((NOW + _now))
	TRANS=$((TRANS + _trans))
	BACKLOG=$((BACKLOG + _backlog))
	ATTN=$((ATTN + _attn))
	_breakdown=""
	[ "${_now}" -gt 0 ] && _breakdown="${_breakdown} ${_now} blocking-now"
	[ "${_trans}" -gt 0 ] && _breakdown="${_breakdown} ${_trans} blocks-a-transition"
	[ "${_backlog}" -gt 0 ] && _breakdown="${_breakdown} ${_backlog} non-blocking"
	[ "${_attn}" -gt 0 ] && _breakdown="${_breakdown} ${_attn} malformed"
	REPORT="${REPORT}
- \`${_FILE_LABEL}\` —${_breakdown}"
}

_FILE_LABEL="spec/vision.md"
check_file "${ROOT}/spec/vision.md"
for _intent in "${ROOT}"/spec/features/*/intent.md; do
	[ -e "${_intent}" ] || continue
	_FILE_LABEL="${_intent#"${ROOT}/"}"
	check_file "${_intent}"
done
_FILE_LABEL="spec/PRODUCTIONIZATION.md"
check_file "${ROOT}/spec/PRODUCTIONIZATION.md"

# A pre-1.25.0 fork may still carry the retired standalone SPEC-QUESTIONS.md.
# Its items live under "## Open" (not "## Open questions"), so count_open never
# sees them — surface the file itself so /e22-standards:e22-questions can migrate it away.
LEGACY=""
[ -f "${ROOT}/spec/SPEC-QUESTIONS.md" ] && LEGACY=1

TOTAL=$((NOW + TRANS + BACKLOG + ATTN))
[ "${TOTAL}" -gt 0 ] 2>/dev/null || [ -n "${LEGACY}" ] || exit 0

printf '<!-- e22-standards: open questions outstanding -->\n'

if [ -n "${LEGACY}" ]; then
	printf '⚠ **Retired `spec/SPEC-QUESTIONS.md` present.** Open questions no longer '
	printf 'live in a standalone file — they belong next to their context '
	printf '(`vision.md` / each feature'"'"'s `intent.md` → `## Open questions`). '
	printf 'Run **/e22-standards:e22-questions** to migrate its questions into the right files and '
	printf 'remove it.\n\n'
fi

if [ "${TOTAL}" -gt 0 ] 2>/dev/null; then
	printf 'ℹ **%s open question(s) across this product'"'"'s specs:**\n' "${TOTAL}"
	printf '%s\n\n' "${REPORT}"
	# Gate-aware summary — these are not all the same urgency.
	if [ "${NOW}" -gt 0 ]; then
		printf -- '- **%s block work now** — a blocking question is open at or before the next gate this spec faces. Resolve these before advancing the gate.\n' "${NOW}"
	fi
	if [ "${TRANS}" -gt 0 ]; then
		printf -- '- **%s block a later transition** — blocking, but for a gate further ahead (e.g. production-release). Track, do not necessarily resolve now.\n' "${TRANS}"
	fi
	if [ "${BACKLOG}" -gt 0 ]; then
		printf -- '- **%s non-blocking** — backlog; they rot if left, but gate nothing.\n' "${BACKLOG}"
	fi
	if [ "${ATTN}" -gt 0 ]; then
		printf -- '- **%s malformed** — a `### Q-NNN` block is missing `status:`/`impact:`; fix the metadata so its gate state is unambiguous.\n' "${ATTN}"
	fi
	printf '\nRun **/e22-standards:e22-questions** to sweep them and drive each to an answer '
	printf '(or an explicit deferral). This notice clears itself once they are resolved.\n'
fi
