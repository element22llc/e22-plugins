#!/usr/bin/env sh
# steer SessionStart hook.
#
# Everything this script writes to stdout becomes `additionalContext` for the
# session — i.e. the always-on engineering operating rules. hooks.json registers
# it for `startup | resume | clear | compact`, and there is no once-per-session
# guard: `compact` can fire repeatedly within one session, and re-injecting then
# is the point — a compaction can drop the rules from context, so the hook has to
# put them back.
#
# Design notes:
#   - cwd is the CONSUMER repo, not the plugin, so paths use ${CLAUDE_PLUGIN_ROOT}.
#   - rules/*.md concatenate in lexical order (hence the numeric file prefixes).
#   - A rule may declare an injection scope on its first line
#     (`<!-- steer:inject-when=<token> -->`); it is then injected only when that
#     scope applies to the consumer repo (see lib/scope.sh). This reclaims
#     context budget for rules that are dead weight where they can't apply
#     (e.g. issue-first on a non-GitHub repo). Fail-open: a missing signal or an
#     unknown token injects the rule, so a typo never silently drops one.
#   - Fail-soft: even if the rules dir is missing we still emit the banner, so a
#     session is never left with silently-empty org context.
#   - HARD CAP. Claude Code caps a hook's stdout (and `additionalContext`) at
#     10,000 characters; anything longer is persisted to a file and replaced in
#     context with a ~2 KB preview. That failure is SILENT — the hook still
#     exits 0 and the gate still passes, while the session receives a fraction
#     of the ruleset. Measured on 2.1.252: a 9,990-char payload arrives whole, a
#     10,010-char payload arrives as a preview. So the payload is assembled to a
#     buffer and capped here; if it does not fit, we truncate at a rule boundary
#     and say so in-band rather than let the runtime drop rules quietly.
#     scripts/check_context_budget.py gates the same number pre-merge.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/report-fault.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

ROOT="${CLAUDE_PLUGIN_ROOT}"
RULES_DIR="${ROOT}/rules"
PLUGIN_JSON="${ROOT}/.claude-plugin/plugin.json"

# Resolve the CONSUMER repo root from the SessionStart payload cwd, so a genuine
# plugin defect (the rules dir vanished) can be recorded for upstream reporting.
# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
CONSUMER_ROOT="$(steer_repo_root "${CWD}" 2>/dev/null)" || CONSUMER_ROOT=""

# Best-effort version read (no jq dependency): grab the first "version" string.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${PLUGIN_JSON}" 2>/dev/null | head -n 1)"
[ -z "${VERSION}" ] && VERSION="unknown"

# The runtime's hard ceiling on hook stdout, and the room held back so the
# over-cap notice below can always be appended without itself busting it.
STEER_INJECT_CAP=10000
# The notice lists at most STEER_INJECT_NAME_LIMIT rule names and then a count,
# so its length is bounded no matter how many rules overflow — which is what
# makes a fixed reserve sound. An unbounded list would need a reserve sized for
# the worst case (~900 B), and every byte of that would be taken from the rules
# in the common case where nothing is dropped at all.
STEER_INJECT_FOOTER_RESERVE=300
STEER_INJECT_NAME_LIMIT=6

# Assemble into a buffer rather than streaming: the payload has to be measured
# against the cap before any of it is emitted. mktemp failure falls back to
# streaming uncapped — a session with the rules beats no session at all.
BUF="$(mktemp "${TMPDIR:-/tmp}/steer-inject.XXXXXX" 2>/dev/null)" || BUF=""
if [ -n "${BUF}" ]; then
	trap 'rm -f "${BUF}"' EXIT
	exec 3>&1 >"${BUF}"
fi

printf '<!-- Engineering standards — steer plugin v%s. Run `/plugin update steer@e22-plugins` to refresh. -->\n\n' "${VERSION}"

# Work mode decides how much of the ruleset applies. 'knowledge' = a confidently
# non-code folder (the typical Claude Cowork product-owner case: a connected
# folder of specs/docs, no git repo) → inject only the lean, always-on
# PO-relevant set and skip every code/infra/tracker-scoped rule. Anything else,
# or any doubt, → 'code' = the full ruleset (fail-safe; never silently drops a
# rule). See steer_work_mode in lib/scope.sh.
WORK_MODE="$(steer_work_mode "${CWD}")"
if [ "${WORK_MODE}" = "knowledge" ]; then
	printf '<!-- steer: knowledge-work mode (non-code folder) — code/infra/tracker rules are intentionally omitted, not missing. -->\n\n'
fi

if [ -d "${RULES_DIR}" ]; then
	# Budget tracked in BYTES against a cap the runtime counts in CHARACTERS. For
	# UTF-8 bytes >= characters, so this errs strictly toward emitting less — the
	# safe direction for a ceiling whose overrun is silent.
	_used="$(wc -c <"${BUF:-/dev/null}" 2>/dev/null | tr -d ' ')"
	[ -n "${_used}" ] || _used=0

	# Pass 1 — which rules are in scope for this consumer, and how big are they.
	# Separating selection from emission is what lets the footer reserve be
	# CONDITIONAL: holding 300 B back on every session to pay for a notice that
	# usually is not written costs one whole small rule for nothing.
	_eligible=""
	_total="${_used}"
	for f in "${RULES_DIR}"/*.md; do
		[ -e "${f}" ] || continue
		# A rule may scope itself with a first-line `<!-- steer:inject-when=<token> -->`
		# marker. Inject it only when that scope applies; strip the marker line so it
		# never reaches context. No marker (the common case) → emit unchanged.
		IFS= read -r _first <"${f}" || _first=""
		_skip=0
		case "${_first}" in
		'<!-- steer:inject-when='*' -->')
			# A knowledge-work folder skips EVERY conditional rule — none of the
			# code/infra/tracker-scoped rules apply there — leaving only the unmarked,
			# always-on PO-relevant core. (Marker line is dropped with the rule.)
			[ "${WORK_MODE}" = "knowledge" ] && continue
			_token="${_first#<!-- steer:inject-when=}"
			_token="${_token% -->}"
			steer_inject_when_ok "${_token}" "${CONSUMER_ROOT}" || continue
			_skip=1
			;;
		esac
		if [ "${_skip}" -eq 1 ]; then
			_size=$(($(tail -n +2 "${f}" | wc -c | tr -d ' ') + 2))
		else
			_size=$(($(wc -c <"${f}" | tr -d ' ') + 2))
		fi
		_total=$((_total + _size))
		_eligible="${_eligible}${_skip} ${_size} ${f}
"
	done

	# Reserve room for the notice only when one is actually going to be needed.
	if [ -z "${BUF}" ] || [ "${_total}" -le "${STEER_INJECT_CAP}" ]; then
		_limit="${STEER_INJECT_CAP}"
	else
		_limit=$((STEER_INJECT_CAP - STEER_INJECT_FOOTER_RESERVE))
	fi

	# Pass 2 — emit until the budget is spent. Once one rule does not fit, every
	# later rule is dropped too, rather than greedily slotting in whichever small
	# ones still happen to fit: a partial ruleset assembled out of order is harder
	# to reason about than a clean prefix plus an explicit list of what is missing.
	# Iterated in the parent shell (IFS split on newline, not a `| while` pipeline)
	# so the counters below survive the loop — a subshell would discard them and
	# the notice would never fire.
	_dropped=""
	_dropped_all=""
	_dropped_n=0
	_oifs="${IFS}"
	IFS='
'
	for _row in ${_eligible}; do
		IFS="${_oifs}"
		_skip="${_row%% *}"
		_rest="${_row#* }"
		_size="${_rest%% *}"
		f="${_rest#* }"
		[ -n "${f}" ] || continue

		if [ -n "${_dropped}" ] || [ $((_used + _size)) -gt "${_limit}" ]; then
			_dropped_n=$((_dropped_n + 1))
			[ "${_dropped_n}" -le "${STEER_INJECT_NAME_LIMIT}" ] &&
				_dropped="${_dropped} $(basename "${f}")"
			_dropped_all="${_dropped_all} $(basename "${f}")"
			IFS='
'
			continue
		fi
		_used=$((_used + _size))
		if [ "${_skip}" -eq 1 ]; then
			tail -n +2 "${f}"
		else
			cat "${f}"
		fi
		printf '\n\n'
		IFS='
'
	done
	IFS="${_oifs}"

	# The notice is part of the payload, not a stderr warning: the session itself
	# has to know its ruleset is incomplete, because it is the thing acting on it.
	if [ -n "${_dropped}" ]; then
		_more=""
		[ "${_dropped_n}" -gt "${STEER_INJECT_NAME_LIMIT}" ] &&
			_more=" and $((_dropped_n - STEER_INJECT_NAME_LIMIT)) more"
		printf '<!-- steer: RULESET INCOMPLETE — the SessionStart payload hit the runtime %s-character cap on hook output, so %s rule(s) were NOT injected: %s%s. Treat the standards above as partial; run `/steer:standards` for the full ruleset, and report it with `/steer:report`. -->\n' \
			"${STEER_INJECT_CAP}" "${_dropped_n}" "${_dropped}" "${_more}"
		# stdout is context and therefore rationed; stderr is not. The gate and
		# scripts/rules-preview.sh read the untruncated list from here, so neither
		# has to re-derive the budget the hook just applied.
		printf 'steer-inject: dropped(%s):%s\n' "${_dropped_n}" "${_dropped_all}" >&2
	fi
else
	printf '# Engineering standards\n\nThe steer rules directory was not found at %s. Reinstall or update the plugin (`/plugin`).\n' "${RULES_DIR}"
	# A vanished rules dir is a steer install defect, not a user error — record it
	# (path-free, stable signature) so surface-faults.sh can offer `/steer:report`.
	# Guarded with `if` (never a bare `&&` chain at branch end): SessionStart
	# stdout becomes additionalContext only on exit 0, so a failed guard test
	# here would silently drop the fallback banner this branch exists for (#319).
	if [ -n "${CONSUMER_ROOT}" ] && [ ! -d "${CONSUMER_ROOT}/.claude-plugin" ]; then
		steer_record_fault "${CONSUMER_ROOT}" "inject-standards.sh" "rules directory missing — plugin install incomplete or corrupted"
	fi
fi

# Restore the real stdout and flush. Guarded on BUF so the mktemp-failed
# streaming path (which never redirected) is a no-op here.
if [ -n "${BUF}" ]; then
	exec 1>&3 3>&-
	cat "${BUF}"
fi

exit 0
