#!/usr/bin/env sh
# steer SessionStart hook — open-questions nudge (anti-rot).
#
# WHY THIS EXISTS
#   Open questions in the spec spine (each feature's intent.md → "## Open
#   questions", and vision.md / PRODUCTIONIZATION.md) get written down once,
#   gated at PO acceptance, then forgotten. Nothing resurfaces them, so they
#   rot. The /steer:questions skill resolves them — but a skill is
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
# STALENESS ESCALATION (anti-rot, part 2)
#   A count is not enough: a question open since January looks identical to one
#   written today, so nothing escalates as it rots. Each `### Q-NNN` block may
#   carry an optional `created: YYYY-MM-DD`. A *blocking*, still-open,
#   *un-promoted* question (no `tracker:` ref) older than STEER_QUESTION_STALE_DAYS
#   gets its own loud escalation line naming the question, feature, owner role,
#   and age — the cue to promote it (assign its owner via the tracker.md Owners
#   map) or defer it. When `created:` is absent we fall back to the heading
#   line's `git blame` author-time, so legacy questions still get an age; if git
#   is unavailable the question simply isn't aged (fail-open, never crash).
#   The hook only *detects* staleness — it never opens issues (writes stay on the
#   human-gated /steer:questions → /steer:issues path).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. Age math is done in awk (the
#   days-from-civil algorithm) so we never depend on GNU-only `date -d`.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/lifecycle.sh"

# SessionStart payload carries cwd (may be a subdir); anchor spec lookups at the
# work-tree root. Not a git repo → fall back to cwd (a spec/ may still be
# addressable relatively).
# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || ROOT="${CWD}"

RB_ORDER="$(steer_required_before_order)"

# A blocking question still open this many days after its `created:` date is
# escalated. Flat policy (user-chosen 14); edit this constant to retune.
STEER_QUESTION_STALE_DAYS=14

# Today as a day-number (days since 1970-01-01, UTC). STEER_TODAY (YYYY-MM-DD)
# overrides for deterministic tests; otherwise `date -u` (POSIX — no -d/-j). If
# the date is unavailable or malformed, TODAY_DAYS is empty and staleness
# escalation is skipped entirely (fail-open: counts still work). Day math uses
# the shared days-from-civil awk source (lib/lifecycle.sh).
_today_ymd="${STEER_TODAY:-$(date -u +%Y-%m-%d 2>/dev/null)}"
TODAY_DAYS="$(printf '%s\n' "${_today_ymd}" | awk -F- "${STEER_AWK_DAYS_FROM_CIVIL}"'
  /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print days_from_civil($1 + 0, $2 + 0, $3 + 0); got = 1 }
  END { if (!got) print "" }')"

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

# parse_questions <file> — THE block parser, one pass, one home. Emits one
# tab-separated record per `### Q-NNN` block under "## Open questions"
# (placeholder seeds skipped), empty fields as "-" (IFS-tab `read` and awk both
# mishandle genuinely empty tab fields):
#   Q \t id \t line \t status \t impact \t required_before \t owner \t created \t tracker
# plus one final record counting legacy `- [ ]` checkboxes (pre-structured
# format, still counted as backlog for one deprecation window; the old
# bracketed [placeholder] seed is skipped):
#   LEGACY \t <count>
# The counting (count_open) and staleness (stale_lines) passes below classify
# these records instead of each re-walking the file with its own parser.
parse_questions() {
	[ -f "$1" ] || return 0
	awk '
    function dash(v) { return v == "" ? "-" : v }
    function val(line, key,   v) { v = line; sub("^" key ":[[:space:]]*", "", v); sub(/[[:space:]].*$/, "", v); return v }
    function endblock() {
      if (inblk && !skip)
        printf "Q\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", dash(q_id), q_line, dash(q_status), dash(q_impact), dash(q_rb), dash(q_owner), dash(q_created), dash(q_tracker)
      inblk = 0; skip = 0; q_id = ""; q_line = 0; q_status = ""; q_impact = ""; q_rb = ""; q_owner = ""; q_created = ""; q_tracker = ""
    }
    /^## Open questions/ { endblock(); inq = 1; next }
    /^## / { endblock(); inq = 0 }
    /^# /  { endblock(); inq = 0 }
    inq && /^### / {
      endblock()
      inblk = 1
      skip = ($0 ~ /steer:placeholder/) ? 1 : 0
      q_line = FNR
      q_id = $0; sub(/^###[[:space:]]*/, "", q_id); sub(/[[:space:]].*$/, "", q_id)
      next
    }
    inq && inblk {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      if      (line ~ /^status:/)          q_status  = tolower(val(line, "status"))
      else if (line ~ /^impact:/)          q_impact  = tolower(val(line, "impact"))
      else if (line ~ /^required_before:/) q_rb      = val(line, "required_before")
      else if (line ~ /^owner:/)           q_owner   = tolower(val(line, "owner"))
      else if (line ~ /^created:/)         q_created = val(line, "created")
      else if (line ~ /^tracker:/)         q_tracker = val(line, "tracker")
    }
    inq && !inblk && /^- \[ \] / {
      rest = substr($0, 7)
      if (rest !~ /^\[/) legacy++
    }
    END { endblock(); printf "LEGACY\t%d\n", legacy + 0 }
  ' "$1"
}

# count_open <file> — prints "now trans backlog attn" for one spec file, by
# classifying parse_questions records against the lifecycle gate ranking.
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
	_cleared="$(rank_of "$(steer_status_cleared_gate "${_status}")")"

	parse_questions "${_f}" | awk -F '\t' -v rborder="${RB_ORDER}" -v cleared="${_cleared}" '
    BEGIN { n = split(rborder, a, " "); for (i = 1; i <= n; i++) rank[a[i]] = i }
    $1 == "LEGACY" { backlog += $2; next }
    $1 != "Q" { next }
    {
      status = ($4 == "-") ? "" : $4
      impact = ($5 == "-") ? "" : $5
      rb     = ($6 == "-") ? "" : $6
      if (status == "") { attn++ }
      else if (status == "open" || status == "investigating") {
        if (impact == "") { attn++ }
        else if (impact == "blocking") {
          r = (rb in rank) ? rank[rb] : 0
          if (r == 0 || r <= cleared + 1) { now++ } else { trans++ }
        } else { backlog++ }
      }
    }
    END { printf "%d %d %d %d", now + 0, trans + 0, backlog + 0, attn + 0 }'
}

# stale_lines <file> — for each blocking, still-open, un-promoted question
# (promoted = non-empty `tracker:` — already on someone's plate), emit one
# tab-separated record so the shell decides staleness in one place:
#   AGE\t<Q-id>\t<owner>\t<age-in-days>   when `created:` is a valid YYYY-MM-DD
#   BLAME\t<Q-id>\t<owner>\t<heading-line-no>   when `created:` is absent/malformed
stale_lines() {
	[ -f "$1" ] || return 0
	[ -n "${TODAY_DAYS}" ] || return 0
	parse_questions "$1" | awk -F '\t' -v today="${TODAY_DAYS}" "${STEER_AWK_DAYS_FROM_CIVIL}"'
    $1 == "Q" && ($4 == "open" || $4 == "investigating") && $5 == "blocking" && $9 == "-" {
      owner = ($7 == "-") ? "" : $7
      if ($8 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
        split($8, parts, "-")
        printf "AGE\t%s\t%s\t%d\n", $2, owner, today - days_from_civil(parts[1] + 0, parts[2] + 0, parts[3] + 0)
      } else {
        printf "BLAME\t%s\t%s\t%d\n", $2, owner, $3
      }
    }'
}

# format_stale <file> <label> — turn stale_lines records into escalation markdown.
# Resolves BLAME records to an age via `git blame` author-time (fail-open if git
# or the commit is unavailable). Applies the staleness threshold in one place.
# Pure stdout (no global writes) so a pipe-to-while subshell is safe here.
format_stale() {
	_ff="$1"
	_lbl="$2"
	[ -n "${TODAY_DAYS}" ] || return 0
	stale_lines "${_ff}" | while IFS="$(printf '\t')" read -r _kind _qid _owner _field; do
		case "${_kind}" in
		AGE)
			_age="${_field}"
			;;
		BLAME)
			command -v git >/dev/null 2>&1 || continue
			_bt="$(git -C "${ROOT}" blame -L"${_field}","${_field}" --porcelain -- "${_ff}" 2>/dev/null |
				awk '/^author-time /{print $2; exit}')"
			[ -n "${_bt}" ] || continue
			case "${_bt}" in *[!0-9]*) continue ;; esac
			_age=$((TODAY_DAYS - _bt / 86400))
			;;
		*) continue ;;
		esac
		[ "${_age}" -ge "${STEER_QUESTION_STALE_DAYS}" ] 2>/dev/null || continue
		if [ -n "${_owner}" ]; then _own=", owner ${_owner}"; else _own=""; fi
		printf -- '- ⚠ `%s` (%s%s) blocking, open %sd — promote (assign its owner via tracker.md) or defer: **/steer:questions**\n' \
			"${_qid}" "${_lbl}" "${_own}" "${_age}"
	done
}

NOW=0
TRANS=0
BACKLOG=0
ATTN=0
REPORT=""
STALE_REPORT=""
STALE_COUNT=0

# args: file
check_file() {
	_file="$1" # capture before `set --` overwrites the positional params
	# Intentional word-splitting: count_open prints four space-separated integers.
	# shellcheck disable=SC2046
	set -- $(count_open "${_file}")
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

	# Staleness escalation for this file's blocking, un-promoted questions.
	_esc="$(format_stale "${_file}" "${_FILE_LABEL}")"
	if [ -n "${_esc}" ]; then
		STALE_REPORT="${STALE_REPORT}
${_esc}"
		STALE_COUNT=$((STALE_COUNT + $(printf '%s\n' "${_esc}" | grep -c .)))
	fi
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
# sees them — surface the file itself so /steer:questions can migrate it away.
LEGACY=""
[ -f "${ROOT}/spec/SPEC-QUESTIONS.md" ] && LEGACY=1

TOTAL=$((NOW + TRANS + BACKLOG + ATTN))
[ "${TOTAL}" -gt 0 ] 2>/dev/null || [ -n "${LEGACY}" ] || exit 0

printf '<!-- steer: open questions outstanding -->\n'

if [ -n "${LEGACY}" ]; then
	printf '⚠ **Retired `spec/SPEC-QUESTIONS.md` present.** Open questions no longer '
	printf 'live in a standalone file — they belong next to their context '
	printf '(`vision.md` / each feature'"'"'s `intent.md` → `## Open questions`). '
	printf 'Run **/steer:questions** to migrate its questions into the right files and '
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
	if [ "${STALE_COUNT}" -gt 0 ] 2>/dev/null; then
		printf '\n🚨 **%s blocking question(s) have rotted (open >%sd, not yet promoted)** — escalate now:\n' "${STALE_COUNT}" "${STEER_QUESTION_STALE_DAYS}"
		printf '%s\n' "${STALE_REPORT}"
		printf 'Promotion files a `spec-question` issue and assigns the owner role via the `owners:` map in `spec/tracker.md`.\n'
	fi
	printf '\nRun **/steer:questions** to sweep them and drive each to an answer '
	printf '(or an explicit deferral). This notice clears itself once they are resolved.\n'
fi
