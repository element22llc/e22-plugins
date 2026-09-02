#!/usr/bin/env sh
# steer SessionStart hook — one PART of the always-on ruleset.
#
#   sh inject-standards.sh [PART [PARTS]]        (defaults: 1 1)
#
# Everything this script writes to stdout becomes `additionalContext` for the
# session — i.e. the always-on engineering operating rules. hooks.json registers
# it PARTS times for `startup | resume | clear | compact`, once per part, and
# there is no once-per-session guard: `compact` can fire repeatedly within one
# session, and re-injecting then is the point — a compaction can drop the rules
# from context, so the hook has to put them back.
#
# WHY PARTS. Claude Code caps a hook command's stdout at 10,000 characters;
# anything longer is persisted to a file and replaced in context with a short
# "Output too large" pointer, while the hook still exits 0 — a SILENT failure
# that left every session with a fraction of the ruleset (#509). The cap is per
# hook COMMAND, not per event (measured on 2.1.258: seven 9,500-character
# commands all arrived whole), so the ruleset is delivered as PARTS commands
# that each stay under it. Every invocation computes the same deterministic
# partition of the eligible rules — lexical order, greedy fill, one part after
# another — and emits only its own part, so hooks.json needs nothing but the
# part number. The parts land in context in completion order, not part order;
# each carries a header saying so, and the numeric rule prefixes give the
# sequence. If the eligible rules do not fit in PARTS parts, whole rules are
# dropped from the tail and the LAST part says so in-band (the full list goes
# to stderr, which costs a session nothing). scripts/check_context_budget.py
# runs every part of every profile pre-merge and fails on any drop.
#
# THE COPILOT SURFACES take a different shape of the same payload. GitHub
# Copilot's SessionStart hook injects context too, but only from a JSON object
# on stdout — the Copilot CLI reads a top-level `additionalContext`, Copilot Chat
# in VS Code reads `hookSpecificOutput.additionalContext`, and both discard raw
# text ("returned non-JSON output"). There is no 10k cap there (120 K characters
# measured whole; 10 MiB documented) but the LAST hook returning context wins,
# so the parts must not be mirrored: when steer_hook_host says `copilot`, part 1
# emits the WHOLE eligible ruleset as one JSON object carrying both keys and
# every other part stays silent. The CLI reaches this path through the generated
# copilot-hooks.json (STEER_HOOK_TARGET=copilot); VS Code reaches it by running
# this plugin's Claude hooks.json as-is — which is why the host is detected here
# rather than declared by a manifest (lib/json.sh, steer_hook_host).
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
#   - Fail-soft: even if the rules dir is missing, part 1 still emits the banner,
#     so a session is never left with silently-empty org context.
#   - Sizes are counted in CHARACTERS (the runtime's unit), locale-independently:
#     `LC_ALL=C tr -d '\200-\277' | wc -c` strips UTF-8 continuation bytes, so
#     the count is code points whether or not the session has a UTF-8 locale
#     (`wc -m` degrades to bytes under LC_ALL=C and would under-fill).

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/report-fault.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

ROOT="${CLAUDE_PLUGIN_ROOT}"
RULES_DIR="${ROOT}/rules"
PLUGIN_JSON="${ROOT}/.claude-plugin/plugin.json"

# Which part this invocation emits, out of how many. Anything malformed falls
# back to a single part — the pre-#509 shape — rather than emitting nothing.
PART="${1:-1}"
PARTS="${2:-1}"
case "${PART}${PARTS}" in
*[!0-9]* | "") PART=1 PARTS=1 ;;
esac
[ "${PART}" -ge 1 ] && [ "${PARTS}" -ge 1 ] && [ "${PART}" -le "${PARTS}" ] || {
	PART=1
	PARTS=1
}

# The runtime's hard ceiling on one hook command's stdout, and the size a part
# is filled to. The 500-character slack absorbs the runtime counting something
# slightly differently from us (bytes vs characters on a multibyte-heavy part,
# a trailing separator) — never spend it on rules.
STEER_INJECT_CAP=10000
STEER_INJECT_PART_BUDGET=9500
# The in-band notice names at most this many dropped rules, then a count.
STEER_INJECT_NAME_LIMIT=6

# Resolve the CONSUMER repo root from the SessionStart payload cwd, so a genuine
# plugin defect (the rules dir vanished) can be recorded for upstream reporting.
# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
CONSUMER_ROOT="$(steer_repo_root "${CWD}" 2>/dev/null)" || CONSUMER_ROOT=""

# ---- Host. Claude Code gets the parted raw-text delivery; a Copilot surface
# gets one JSON object from part 1 and silence from every other part (see the
# header). The budget is lifted rather than removed: 2 M characters is far above
# any ruleset and far below Copilot's 10 MiB stdout bound, so the partition
# logic below runs unchanged and simply never splits or drops.
HOST="$(steer_hook_host)"
if [ "${HOST}" = "copilot" ]; then
	[ "${PART}" -eq 1 ] || exit 0
	PARTS=1
	STEER_INJECT_PART_BUDGET=2000000
	STEER_INJECT_CAP=2000000
fi

# emit_context — stdin is the context text; on Claude it is the hook's stdout as
# is, on a Copilot surface it is wrapped in the envelope both surfaces read (the
# CLI takes the top-level key, VS Code the nested one; each ignores the other).
# Empty context emits nothing rather than an envelope around "".
emit_context() {
	if [ "${HOST}" = "copilot" ]; then
		_ctx="$(steer_json_string)"
		[ "${_ctx}" != '""' ] || return 0
		printf '{"additionalContext":%s,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
			"${_ctx}" "${_ctx}"
	else
		cat
	fi
}

# Best-effort version read (no jq dependency): grab the first "version" string.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${PLUGIN_JSON}" 2>/dev/null | head -n 1)"
[ -z "${VERSION}" ] && VERSION="unknown"

# Character count of stdin (code points, locale-independent — see header).
steer_chars() {
	LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '
}

# Header text for part N. Part 1 carries the banner every session used to get;
# the others say which part they are and that order is not meaningful.
refresh_hint() {
	if [ "${HOST}" = "copilot" ]; then
		printf 'Run `copilot plugin update steer` (Copilot CLI) or update the plugin from the Extensions view (VS Code) to refresh.'
	else
		printf 'Run `/plugin update steer@e22-plugins` to refresh.'
	fi
}

part_header() {
	if [ "$1" -eq 1 ]; then
		if [ "${PARTS}" -eq 1 ]; then
			printf '<!-- Engineering standards — steer plugin v%s. %s -->\n' "${VERSION}" "$(refresh_hint)"
		else
			printf '<!-- Engineering standards — steer plugin v%s, part 1/%s. The other parts arrive as separate SessionStart blocks, in any order; the numeric rule prefixes give the sequence. %s -->\n' "${VERSION}" "${PARTS}" "$(refresh_hint)"
		fi
		if [ "${WORK_MODE}" = "knowledge" ]; then
			printf '\n<!-- steer: knowledge-work mode — this is a non-code folder, so the code/infra/tracker-specific rules are intentionally omitted (not missing). The spec-workflow, decision-capture, living-docs, roles and output rules still apply. -->\n'
		fi
	else
		printf '<!-- Engineering standards — steer plugin v%s, part %s/%s (continued; parts arrive in any order). -->\n' "${VERSION}" "$1" "${PARTS}"
	fi
}

# Work mode decides how much of the ruleset applies. 'knowledge' = a confidently
# non-code folder (the typical Claude Cowork product-owner case: a connected
# folder of specs/docs, no git repo) → inject only the lean, always-on
# PO-relevant set and skip every code/infra/tracker-scoped rule. Anything else,
# or any doubt, → 'code' = the full ruleset (fail-safe; never silently drops a
# rule). See steer_work_mode in lib/scope.sh.
WORK_MODE="$(steer_work_mode "${CWD}")"

if [ ! -d "${RULES_DIR}" ]; then
	# Only part 1 speaks for a missing rules dir — one notice, not PARTS copies.
	if [ "${PART}" -eq 1 ]; then
		printf '# Engineering standards\n\nThe steer rules directory was not found at %s. Reinstall or update the plugin (`/plugin`).\n' "${RULES_DIR}" | emit_context
		# A vanished rules dir is a steer install defect, not a user error — record it
		# (path-free, stable signature) so surface-faults.sh can offer `/steer:report`.
		# Guarded with `if` (never a bare `&&` chain at branch end): SessionStart
		# stdout becomes additionalContext only on exit 0, so a failed guard test
		# here would silently drop the fallback banner this branch exists for (#319).
		if [ -n "${CONSUMER_ROOT}" ] && [ ! -d "${CONSUMER_ROOT}/.claude-plugin" ]; then
			steer_record_fault "${CONSUMER_ROOT}" "inject-standards.sh" "rules directory missing — plugin install incomplete or corrupted"
		fi
	fi
	exit 0
fi

# ---- Pass 1: which rules are in scope for this consumer, and how big is each.
# Rows are `<skip> <size> <path>`: skip=1 means "strip the first (marker) line".
# Size includes the two-newline separator each rule is followed by.
#
# Every size comes from ONE awk pass over the whole rules dir, and the loop is
# driven by that table rather than by a second glob (awk visits the files in
# glob order, so the two would agree — but looking each file up in the table
# with `${table#*pattern}` is quadratic in bash 3.2 and cost ~400 ms per part).
# A per-rule `tr | wc` pipeline was two forks per rule per part; with PARTS parts
# started in parallel that was hundreds of process spawns per session start.
# Character count = bytes minus UTF-8 continuation bytes, matched as raw
# 0x80-0xBF under LC_ALL=C, so it is the code-point count in any locale. A file
# without a final newline counts one character over — the conservative
# direction. An empty file has nothing to inject and does not appear.
# Table row: `<chars> <first-line-chars> <path>` — path last, so a plugin root
# containing spaces still parses.
NL='
'
_sizes="$(LC_ALL=C awk -v re="$(printf '[\200-\277]')" '
	FNR == 1 && NR > 1 { print n, first, name; n = 0 }
	FNR == 1 { name = FILENAME }
	{ l = length($0) + 1; c = gsub(re, ""); ch = l - c; n += ch; if (FNR == 1) first = ch }
	END { if (name != "") print n, first, name }
' "${RULES_DIR}"/*.md 2>/dev/null)"
_eligible=""
_oifs="${IFS}"
IFS="${NL}"
for _srow in ${_sizes}; do
	IFS="${_oifs}"
	_size="${_srow%% *}"
	_rest="${_srow#* }"
	_firstlen="${_rest%% *}"
	f="${_rest#* }"
	[ -f "${f}" ] || {
		IFS="${NL}"
		continue
	}
	IFS= read -r _first <"${f}" || _first=""
	_skip=0
	case "${_first}" in
	'<!-- steer:inject-when='*' -->')
		# A knowledge-work folder skips EVERY conditional rule — none of the
		# code/infra/tracker-scoped rules apply there — leaving only the unmarked,
		# always-on PO-relevant core. (Marker line is dropped with the rule.)
		if [ "${WORK_MODE}" = "knowledge" ]; then
			IFS="${NL}"
			continue
		fi
		_token="${_first#<!-- steer:inject-when=}"
		_token="${_token% -->}"
		if ! steer_inject_when_ok "${_token}" "${CONSUMER_ROOT}"; then
			IFS="${NL}"
			continue
		fi
		_skip=1
		;;
	esac
	if [ "${_skip}" -eq 1 ]; then
		_size=$((_size - _firstlen + 2))
	else
		_size=$((_size + 2))
	fi
	_eligible="${_eligible}${_skip} ${_size} ${f}${NL}"
	IFS="${NL}"
done
IFS="${_oifs}"

# ---- Partition: lexical order, greedy fill, part after part. Deterministic, so
# every one of the PARTS invocations computes the same assignment.
_shard=1
_used=$(($(part_header 1 | steer_chars) + 1))
_assign=""
_dropped_all=""
_dropped_n=0
_oifs="${IFS}"
IFS="${NL}"
for _row in ${_eligible}; do
	IFS="${_oifs}"
	_size="${_row#* }"
	_size="${_size%% *}"
	if [ "${_shard}" -le "${PARTS}" ] && [ $((_used + _size)) -gt "${STEER_INJECT_PART_BUDGET}" ]; then
		_shard=$((_shard + 1))
		[ "${_shard}" -le "${PARTS}" ] && _used=$(($(part_header "${_shard}" | steer_chars) + 1))
	fi
	if [ "${_shard}" -gt "${PARTS}" ] || [ $((_used + _size)) -gt "${STEER_INJECT_PART_BUDGET}" ]; then
		# Out of parts, or a single rule larger than a whole part: dropped. A rule
		# that big is a gate failure upstream; here we just refuse to overrun.
		_name="${_row##*/}"
		_dropped_all="${_dropped_all} ${_name}"
		_dropped_n=$((_dropped_n + 1))
		IFS="${NL}"
		continue
	fi
	_assign="${_assign}${_shard} ${_row}${NL}"
	_used=$((_used + _size))
	IFS="${NL}"
done
IFS="${_oifs}"
[ "${_shard}" -le "${PARTS}" ] || _shard="${PARTS}"
# _shard is now the last part with a header; _used its fill.

# The notice is part of the payload, not a stderr warning: the session itself
# has to know its ruleset is incomplete, because it is the thing acting on it.
# It lives on the last emitted part and is sized from the data — rules are
# popped off that part until header + rules + notice fit the budget, so the
# guard can never itself bust the cap it exists to enforce.
build_notice() {
	_names=""
	_i=0
	for _n in ${_dropped_all}; do
		_i=$((_i + 1))
		[ "${_i}" -le "${STEER_INJECT_NAME_LIMIT}" ] || break
		_names="${_names} ${_n}"
	done
	_more=""
	[ "${_dropped_n}" -gt "${STEER_INJECT_NAME_LIMIT}" ] &&
		_more=" and $((_dropped_n - STEER_INJECT_NAME_LIMIT)) more"
	printf '<!-- steer: RULESET INCOMPLETE — the ruleset did not fit in %s SessionStart part(s) of %s characters (the runtime cap on hook output), so %s rule(s) were NOT injected:%s%s. Treat the standards above as partial; run `/steer:standards` for the full ruleset, and report it with `/steer:report`. -->\n' \
		"${PARTS}" "${STEER_INJECT_CAP}" "${_dropped_n}" "${_names}" "${_more}"
}
NOTICE=""
if [ "${_dropped_n}" -gt 0 ]; then
	NOTICE="$(build_notice)"
	while [ $((_used + $(printf '%s\n' "${NOTICE}" | steer_chars))) -gt "${STEER_INJECT_PART_BUDGET}" ]; do
		_last="${_assign%"${NL}"}"
		_last="${_last##*"${NL}"}"
		[ -n "${_last}" ] || break
		case "${_last}" in
		"${_shard} "*) ;;
		*) break ;; # the last part holds nothing but its header
		esac
		_assign="${_assign%"${_last}${NL}"}"
		_rest="${_last#* }"
		_size="${_rest#* }"
		_size="${_size%% *}"
		_used=$((_used - _size))
		_dropped_all=" ${_last##*/}${_dropped_all}"
		_dropped_n=$((_dropped_n + 1))
		NOTICE="$(build_notice)"
	done
fi

# ---- Emit this part. A part past the last used one has nothing to say and
# stays silent (empty stdout adds no context). Part 1 always speaks. The text is
# produced by emit_part and shaped for the host by emit_context (raw on Claude,
# the JSON envelope on a Copilot surface).
_has_rows=0
case "${NL}${_assign}" in *"${NL}${PART} "*) _has_rows=1 ;; esac
if [ "${PART}" -ne 1 ] && [ "${_has_rows}" -eq 0 ] && { [ -z "${NOTICE}" ] || [ "${PART}" -ne "${_shard}" ]; }; then
	exit 0
fi

emit_part() {
	part_header "${PART}"
	printf '\n'
	IFS="${NL}"
	for _row in ${_assign}; do
		IFS="${_oifs}"
		case "${_row}" in
		"${PART} "*) ;;
		*)
			IFS="${NL}"
			continue
			;;
		esac
		_rest="${_row#* }"
		_skip="${_rest%% *}"
		_rest="${_rest#* }"
		f="${_rest#* }"
		if [ "${_skip}" -eq 1 ]; then
			tail -n +2 "${f}"
		else
			cat "${f}"
		fi
		printf '\n\n'
		IFS="${NL}"
	done
	IFS="${_oifs}"

	if [ -n "${NOTICE}" ] && [ "${PART}" -eq "${_shard}" ]; then
		printf '%s\n' "${NOTICE}"
		# stdout is context and therefore rationed; stderr is not. The gate and
		# scripts/rules-preview.sh read the untruncated list from here, so neither
		# has to re-derive the budget the hook just applied.
		printf 'steer-inject: dropped(%s):%s\n' "${_dropped_n}" "${_dropped_all}" >&2
	fi
}

emit_part | emit_context

exit 0
