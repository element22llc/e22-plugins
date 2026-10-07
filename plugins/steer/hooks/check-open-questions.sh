#!/usr/bin/env sh
# steer SessionStart hook - open-questions nudge (anti-rot).
#
# WHY THIS EXISTS
#   Open questions in the spec spine (each feature's intent.md -> "## Open
#   questions", and vision.md / PRODUCTIONIZATION.md) get written down once,
#   gated at PO acceptance, then forgotten. Nothing resurfaces them, so they
#   rot. The /steer:spec questions skill resolves them - but a skill is
#   pull, not push: it only runs when someone remembers to invoke it. This hook
#   makes the backlog visible every session so it can't quietly accumulate.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path
#   as inject-standards.sh / check-template-drift.sh). The hook stays SILENT
#   when there are no open questions, so a clean repo gets zero noise and the
#   notice clears itself once questions are answered or explicitly deferred.
#
#   Questions use the structured contract (see templates/spec/feature-intent.md),
#   parsed by lib/questions.sh - the one parser the legacy converter shares:
#     ### Q-001 - title
#     - status: open            # open | investigating | resolved | deferred | cancelled
#     - impact: blocking        # blocking | non-blocking
#     - required_before: intent-approval
#   Counted when status is open or investigating. Blocking questions are split
#   into "blocks now" vs "blocks a later transition" using the shared
#   lifecycle-ordering contract (lib/lifecycle.sh) against the feature's Status.
#   Malformed blocks (missing status/impact) are surfaced as needs-attention
#   rather than silently dropped. Legacy `- [ ]` checkboxes are no longer
#   backlog: their deprecation window closed when the ledger gained a
#   converter, so they are reported on their own line with the one command
#   that converts them (/steer:setup sync).
#
# STALENESS ESCALATION (anti-rot, part 2)
#   A count is not enough: a question open since January looks identical to one
#   written today, so nothing escalates as it rots. Each `### Q-NNN` block may
#   carry an optional `created: YYYY-MM-DD`. A still-open, *un-promoted*
#   question (no `tracker:` ref) is stale once older than its threshold:
#   STEER_QUESTION_STALE_DAYS for a blocking one, and for a non-blocking one
#   STEER_QUESTION_STALE_NONBLOCKING_DAYS - or the blocking threshold when its
#   feature is already `live`, because the question has outlived the work it
#   was meant to inform. When `created:` is absent we fall back to the heading
#   line's `git blame` author-time (one blame per file, never per question); if
#   git is unavailable the question simply isn't aged (fail-open, never crash).
#   The hook only *detects* staleness - it never opens issues (writes stay on
#   the human-gated /steer:spec questions -> /steer:issues path).
#
# OUTPUT IS BOUNDED BY DESIGN
#   One summary line, then at most STEER_QUESTION_TOP questions by urgency
#   (blocking-now first, then stale, then oldest), then one remedy line. Never a
#   line per file or per question: a large backlog printed in full repeats
#   unchanged every session, trains people to skip it, and can overrun the
#   per-command hook output cap.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. Age math is done in awk (the
#   days-from-civil algorithm) so we never depend on GNU-only `date -d`.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/lifecycle.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/questions.sh"

# SessionStart payload carries cwd (may be a subdir); anchor spec lookups at the
# work-tree root. Not a git repo -> fall back to cwd (a spec/ may still be
# addressable relatively).
# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || ROOT="${CWD}"
# The promotion notice names the tracker - resolve it, so an OpenSpec repo is
# pointed at openspec/steer/tracker.md rather than a path it does not have.
steer_tracker_rel "${ROOT}"

# Promotion means something different per tracker: on GitHub Issues /steer:spec questions
# files a spec-question issue and assigns it from the `owners:` map, and on every
# other tracker - Jira, Linear, none-yet, none declared - that is manual and there
# is no owners map to assign from. Resolved once here rather than inside
# the top-list loop, whose pipe-to-while body is a subshell. Fail-open (an ambiguous
# member resolves to GitHub) keeps today's wording as the default.
if steer_tracker_is_github "${ROOT}"; then TRACKER_IS_GITHUB=1; else TRACKER_IS_GITHUB=0; fi

RB_ORDER="$(steer_required_before_order)"

# A blocking question still open this many days after its `created:` date is
# escalated. Flat policy (user-chosen 14); edit this constant to retune.
STEER_QUESTION_STALE_DAYS=14
# A non-blocking question gates nothing, so it gets longer - but it still
# expires, or the backlog only ever grows. A non-blocking question in a `live`
# feature uses STEER_QUESTION_STALE_DAYS instead.
STEER_QUESTION_STALE_NONBLOCKING_DAYS=60
# How many questions the notice names.
STEER_QUESTION_TOP=3

# Today as a day-number (days since 1970-01-01, UTC). STEER_TODAY (YYYY-MM-DD)
# overrides for deterministic tests; otherwise `date -u` (POSIX - no -d/-j). If
# the date is unavailable or malformed, TODAY_DAYS is empty and staleness
# escalation is skipped entirely (fail-open: counts still work). Day math uses
# the shared days-from-civil awk source (lib/lifecycle.sh).
_today_ymd="${STEER_TODAY:-$(date -u +%Y-%m-%d 2>/dev/null)}"
TODAY_DAYS="$(printf '%s\n' "${_today_ymd}" | awk -F- "${STEER_AWK_DAYS_FROM_CIVIL}"'
  /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { print days_from_civil($1 + 0, $2 + 0, $3 + 0); got = 1 }
  END { if (!got) print "" }')"

# rank_of <token> - 1-based position of a gate token in the lifecycle order, or
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

# Feature Status -> rank of the gate it has cleared, as "status=rank ..." for
# awk. Built from lib/lifecycle.sh so the Status vocabulary stays in one place.
CLEARED_MAP=""
for _st in approved live implemented validated; do
	CLEARED_MAP="${CLEARED_MAP} ${_st}=$(rank_of "$(steer_status_cleared_gate "${_st}")")"
done

# classify_file <file> <label> - one pass over lib/questions.sh records (plus
# a blame map when some open question has no usable `created:`), emitting:
#   COUNT \t now \t trans \t backlog \t attn \t legacy \t unowned \t product
#   ITEM  \t rank \t age \t id \t owner \t kind \t stale \t label \t title
# rank orders the top list: 0 stale blocking-now, 1 blocking-now, 2 stale,
# 3 the rest; age is -1 when unknown. kind is now | later | non-blocking.
# Empty owner/title stay "-" so the tab-IFS `read` below keeps its columns.
classify_file() {
	_f="$1"
	_lbl="$2"
	[ -f "${_f}" ] || return 0
	_recs="$(steer_questions_parse "${_f}")"
	# Blame only when an open question actually needs it.
	_blame=""
	if [ -n "${TODAY_DAYS}" ] && printf '%s\n' "${_recs}" | awk -F '\t' '
		$1 == "Q" && ($4 == "open" || $4 == "investigating") && $8 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ { f = 1 }
		END { exit !f }'; then
		_blame="$(steer_questions_blame "${ROOT}" "${_f}")"
	fi
	printf '%s\n%s\n' "${_blame}" "${_recs}" | awk -F '\t' \
		-v rborder="${RB_ORDER}" -v today="${TODAY_DAYS}" -v lbl="${_lbl}" \
		-v sb="${STEER_QUESTION_STALE_DAYS}" -v snb="${STEER_QUESTION_STALE_NONBLOCKING_DAYS}" \
		-v clearmap="${CLEARED_MAP}" \
		"${STEER_AWK_DAYS_FROM_CIVIL}"'
    BEGIN {
      n = split(rborder, a, " "); for (i = 1; i <= n; i++) rank[a[i]] = i
      n = split(clearmap, a, " "); for (i = 1; i <= n; i++) { split(a[i], kv, "="); crank[kv[1]] = kv[2] + 0 }
    }
    $1 == "B" { bt[$2] = $3; next }
    $1 == "S" { st = $2; cleared = (st in crank) ? crank[st] : 0; next }
    $1 == "L" { legacy++; next }
    $1 != "Q" { next }
    {
      status = ($4 == "-") ? "" : $4
      impact = ($5 == "-") ? "" : $5
      rb     = ($6 == "-") ? "" : $6
      owner  = ($7 == "-") ? "" : $7
      if (status == "") { attn++; next }
      if (status != "open" && status != "investigating") next
      if (impact == "") { attn++; next }
      if (owner == "") unowned++
      # The client answers a PO question, and any access/tooling/decision ask
      # whoever owns it - the same audience `questions bundle` solicits.
      if (owner == "product" || ($11 != "" && $11 != "-" && $11 != "clarification")) product++
      if (impact == "blocking") {
        r = (rb in rank) ? rank[rb] : 0
        if (r == 0 || r <= cleared + 1) { now++; kind = "now" } else { trans++; kind = "later" }
      } else { backlog++; kind = "non-blocking" }
      age = -1
      if (today != "") {
        if ($8 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
          split($8, p, "-"); age = today - days_from_civil(p[1] + 0, p[2] + 0, p[3] + 0)
        } else if ($3 in bt) {
          age = today - int(bt[$3] / 86400)
        }
      }
      limit = (impact == "blocking" || st == "live") ? sb : snb
      stale = ($9 == "-" && age >= limit) ? 1 : 0
      rk = (kind == "now") ? (stale ? 0 : 1) : (stale ? 2 : 3)
      printf "ITEM\t%d\t%d\t%s\t%s\t%s\t%d\t%s\t%s\n", rk, age, $2, $7, kind, stale, lbl, $10
    }
    END { printf "COUNT\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", now, trans, backlog, attn, legacy, unowned, product }'
}

NOW=0
TRANS=0
BACKLOG=0
ATTN=0
LEGACY_Q=0
UNOWNED=0
PRODUCT=0
FILES=0
STALE=0
ITEMS=""

# args: file
check_file() {
	_out="$(classify_file "$1" "${_FILE_LABEL}")"
	[ -n "${_out}" ] || return 0
	# Intentional word-splitting: the COUNT record is eight tab-free integers.
	# shellcheck disable=SC2046
	set -- $(printf '%s\n' "${_out}" | awk -F '\t' '$1 == "COUNT" { print $2, $3, $4, $5, $6, $7, $8 }')
	[ $(($1 + $2 + $3 + $4 + $5)) -gt 0 ] 2>/dev/null || return 0
	FILES=$((FILES + 1))
	NOW=$((NOW + $1))
	TRANS=$((TRANS + $2))
	BACKLOG=$((BACKLOG + $3))
	ATTN=$((ATTN + $4))
	LEGACY_Q=$((LEGACY_Q + $5))
	UNOWNED=$((UNOWNED + $6))
	PRODUCT=$((PRODUCT + $7))
	_items="$(printf '%s\n' "${_out}" | grep '^ITEM	')"
	if [ -n "${_items}" ]; then
		ITEMS="${ITEMS}
${_items}"
		STALE=$((STALE + $(printf '%s\n' "${_items}" | awk -F '\t' '$7 == 1' | grep -c .)))
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
# Its items live under "## Open" (not "## Open questions"), so the parser never
# sees them - surface the file itself so /steer:spec questions can migrate it away.
LEGACY=""
[ -f "${ROOT}/spec/SPEC-QUESTIONS.md" ] && LEGACY=1

TOTAL=$((NOW + TRANS + BACKLOG + ATTN + LEGACY_Q))
[ "${TOTAL}" -gt 0 ] 2>/dev/null || [ -n "${LEGACY}" ] || exit 0

printf '<!-- steer: open questions outstanding -->\n'

if [ -n "${LEGACY}" ]; then
	printf '⚠ **Retired `spec/SPEC-QUESTIONS.md` present.** Open questions no longer '
	printf 'live in a standalone file - they belong next to their context '
	printf '(`vision.md` / each feature'"'"'s `intent.md` -> `## Open questions`). '
	printf 'Run **/steer:spec questions** to migrate its questions into the right files and '
	printf 'remove it.\n\n'
fi

[ "${TOTAL}" -gt 0 ] 2>/dev/null || exit 0

# One summary line: the gate-aware split, non-zero parts only.
_parts=""
_add() { if [ -n "${_parts}" ]; then _parts="${_parts}, $1"; else _parts="$1"; fi; }
[ "${NOW}" -gt 0 ] && _add "**${NOW} block work now**"
[ "${TRANS}" -gt 0 ] && _add "${TRANS} block a later transition"
[ "${BACKLOG}" -gt 0 ] && _add "${BACKLOG} non-blocking"
[ "${ATTN}" -gt 0 ] && _add "${ATTN} malformed"
[ "${LEGACY_Q}" -gt 0 ] && _add "${LEGACY_Q} in the retired \`- [ ]\` format"
printf 'ℹ **%s open question(s)** in %s spec file(s): %s.\n' "${TOTAL}" "${FILES}" "${_parts}"

if [ "${TRACKER_IS_GITHUB}" = 1 ]; then
	_how="promote (assign its owner via ${STEER_TRACKER_REL})"
else
	_how="promote (open it in the declared tracker, then set its \`tracker:\` ref)"
fi

# The few questions to act on, by urgency then age. Undated ones sort last.
if [ -n "${ITEMS}" ]; then
	_top="$(printf '%s\n' "${ITEMS}" | grep '^ITEM	' | sort -t "$(printf '\t')" -k2,2n -k3,3nr | head -n "${STEER_QUESTION_TOP}")"
	_shown="$(printf '%s\n' "${_top}" | grep -c .)"
	_open_q=$((NOW + TRANS + BACKLOG))
	if [ "${_open_q}" -gt "${_shown}" ]; then
		printf '\nMost urgent %s of %s:\n' "${_shown}" "${_open_q}"
	else
		printf '\n'
	fi
	printf '%s\n' "${_top}" | while IFS="$(printf '\t')" read -r _t _rk _age _qid _owner _kind _stale _lbl _title; do
		[ "${_t}" = ITEM ] || continue
		case "${_kind}" in
		now) _k="blocks work now" ;;
		later) _k="blocks a later transition" ;;
		*) _k="non-blocking" ;;
		esac
		if [ "${_owner}" != - ]; then _own="owner ${_owner}"; else _own="no owner"; fi
		if [ "${_age}" -ge 0 ] 2>/dev/null; then _a=", open ${_age}d"; else _a=""; fi
		case "${_title}" in -) _title="" ;; esac
		[ -n "${_title}" ] && _title=" ${_title}"
		if [ "${_stale}" != 1 ]; then
			_s=""
		elif [ "${_owner}" = - ]; then
			_s=" - ⚠ stale: set its \`owner:\`, then promote or defer"
		else
			_s=" - ⚠ stale: ${_how} or defer"
		fi
		printf -- '- `%s`%s (`%s`, %s, %s%s)%s\n' "${_qid}" "${_title}" "${_lbl}" "${_own}" "${_k}" "${_a}" "${_s}"
	done
fi

if [ "${NOW}" -gt 0 ]; then
	printf '\nA question that blocks work now gates the next transition its spec faces - resolve it before advancing that gate.\n'
fi
if [ "${ATTN}" -gt 0 ]; then
	printf '\n%s malformed: a `### Q-NNN` block is missing `status:`/`impact:` - fix the metadata so its gate state is unambiguous.\n' "${ATTN}"
fi
if [ "${STALE}" -gt 0 ] 2>/dev/null; then
	printf '\n🚨 **%s question(s) have rotted** - open past %sd (blocking) or %sd (non-blocking), not yet promoted. Promote or defer them in **/steer:spec questions**.\n' \
		"${STALE}" "${STEER_QUESTION_STALE_DAYS}" "${STEER_QUESTION_STALE_NONBLOCKING_DAYS}"
	if [ "${TRACKER_IS_GITHUB}" = 1 ]; then
		printf 'Promotion files a `spec-question` issue and assigns the owner role via the `owners:` map in `%s`.\n' "${STEER_TRACKER_REL}"
	else
		printf 'This product does not use GitHub Issues, so promotion is manual: open the work item in the tracker declared in `%s`, then write its ref into the question'"'"'s `tracker:` field.\n' "${STEER_TRACKER_REL}"
	fi
fi

# One remedy, the most specific that applies.
printf '\n'
if [ "${LEGACY_Q}" -gt 0 ]; then
	printf -- '%s question(s) are still bare `- [ ]` items, which have no owner, gate or date. Run **/steer:setup sync**: its migration converts them to `### Q-NNN` blocks dated from when each was written.\n' "${LEGACY_Q}"
elif [ $((UNOWNED * 2)) -gt $((NOW + TRANS + BACKLOG)) ]; then
	printf -- 'Most have no `owner:`, so nobody is asked. Triage them in **/steer:spec questions**: set an owner, then answer, defer, or cancel each.\n'
elif [ $((PRODUCT * 2)) -gt $((NOW + TRANS + BACKLOG)) ]; then
	printf -- 'Most are the PO'"'"'s to answer. **/steer:spec questions bundle** turns them into one questionnaire the PO can fill in offline.\n'
else
	printf -- 'Run **/steer:spec questions** to drive each to an answer or an explicit deferral.\n'
fi
printf 'This notice clears itself once they are resolved or deferred.\n'
