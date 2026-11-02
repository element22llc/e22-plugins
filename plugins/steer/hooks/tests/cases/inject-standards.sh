#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ----- inject-standards.sh: missing-rules fail-soft (banner + rc 0, #319) -----
# SessionStart stdout becomes additionalContext ONLY on exit 0, so the fallback
# banner must always ship with a clean exit. A fake plugin root (hook libs, no
# rules/) exercises the degraded path via the CLAUDE_PLUGIN_ROOT override.
FAKEPLUGIN="${WORK}/fakeplugin"
mkdir -p "${FAKEPLUGIN}/hooks"
cp -R "${HOOKS}/lib" "${FAKEPLUGIN}/hooks/lib"
# Consumer root that looks like the plugin's own tree (.claude-plugin present):
# pre-fix the record-fault guard chain's failed test leaked rc 1 here, dropping
# the banner exactly in the degraded scenario it exists for.
NR1="$(new_repo norules_plugintree)"
mkdir -p "${NR1}/.claude-plugin"
out="$(ENV="CLAUDE_PLUGIN_ROOT=${FAKEPLUGIN}" run_hook inject-standards.sh "$(session_json "${NR1}" nr1)")"
assert_has "inject: missing rules dir still emits fallback banner (plugin tree)" "${out}" 'rules directory was not found'
assert_rc "inject: missing-rules fail-soft exits 0 (plugin tree)" "$(last_rc)" 0
# Ordinary consumer repo: banner + rc 0, and the defect is recorded for
# surface-faults.sh to offer /steer:report.
NR2="$(new_repo norules_consumer)"
out="$(ENV="CLAUDE_PLUGIN_ROOT=${FAKEPLUGIN}" run_hook inject-standards.sh "$(session_json "${NR2}" nr2)")"
assert_has "inject: missing rules dir emits fallback banner (consumer repo)" "${out}" 'rules directory was not found'
assert_rc "inject: missing-rules fail-soft exits 0 (consumer repo)" "$(last_rc)" 0
grep -q 'rules directory missing' "${NR2}/.claude/steer-faults.log" 2>/dev/null &&
	ok || bad "inject: missing rules dir records a self-fault in the consumer repo"

# ----- inject-standards.sh: conditional (inject-when) rule scoping -----
# 36-issue-first carries inject-when=tracker-github; 12-stack-infra inject-when=has-iac&org-e22.
# Deployment is no longer separately scoped - it is a section of 45-delivery
# (code-project), which policy/delivery.yml already neutralises for a repo that
# deploys nowhere (`environments: []`).
# A scoped rule is injected only when its predicate holds; always-on rules
# (e.g. 00-router) appear regardless; the marker line never leaks into output.

# GitHub tracker -> issue-first injected, its marker stripped.
CRI_GH="$(new_repo cri_gh)"
mkdir -p "${CRI_GH}/spec"
printf 'system: github\n' >"${CRI_GH}/spec/tracker.md"
out="$(run_inject "$(session_json "${CRI_GH}" cri_gh)")"
oq_grep "inject: github repo includes issue-first rule" 'Issue-first (GitHub-adopted repos)' "${out}"
oq_grep "inject: always-on router present (github repo)" 'You are the router' "${out}"
# GitHub-only tracker prose lives in 36, not in the code-project rules 35 and 50.
oq_grep "inject: github repo gets the issue lifecycle line" 'lifecycle workflow and' "${out}"
oq_grep "inject: github repo gets the issue checklist item" 'End-of-session checklist gains one item' "${out}"
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject: inject-when marker line must be stripped from output" || ok

# Non-GitHub tracker -> issue-first skipped.
CRI_JIRA="$(new_repo cri_jira)"
mkdir -p "${CRI_JIRA}/spec"
printf 'system: jira\n' >"${CRI_JIRA}/spec/tracker.md"
out="$(run_inject "$(session_json "${CRI_JIRA}" cri_jira)")"
printf '%s' "${out}" | grep -q 'Issue-first (GitHub-adopted repos)' &&
	bad "inject: non-github repo must omit issue-first rule" || ok
printf '%s' "${out}" | grep -q -e 'lifecycle workflow and' -e 'End-of-session checklist gains one item' &&
	bad "inject: non-github repo must omit the GitHub issue lifecycle and checklist item" || ok
oq_grep "inject: non-github repo keeps the manual-export line" 'uses the manual export' "${out}"
oq_grep "inject: always-on router present (jira repo)" 'You are the router' "${out}"

# /infra present -> the infra-stack fragment is injected (has-iac), and the
# delivery rule (which carries deployment) rides in on code-project.
CRI_INFRA="$(new_repo cri_infra)"
mkdir -p "${CRI_INFRA}/infra"
out="$(run_inject "$(session_json "${CRI_INFRA}" cri_infra)")"
oq_grep "inject: repo with /infra includes deployment rule" 'policy/delivery.yml' "${out}"
oq_grep "inject: repo with /infra includes infra-stack fragment" 'Stack - infrastructure / IaC' "${out}"

# Root-level IaC (Ansible site.yml, no /infra dir) -> infra-stack fragment injected
# via has-iac. This is the case steer used to skip entirely.
CRI_ANSIBLE="$(new_repo cri_ansible)"
printf -- '- hosts: all\n' >"${CRI_ANSIBLE}/site.yml"
out="$(run_inject "$(session_json "${CRI_ANSIBLE}" cri_ansible)")"
oq_grep "inject: root-level Ansible repo includes infra-stack fragment" 'Stack - infrastructure / IaC' "${out}"
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject: inject-when marker line must be stripped (ansible repo)" || ok

# App repo (package.json, no /infra, no IaC) -> the delivery rule is injected,
# but NOT the infra-stack fragment (has-iac is false).
CRI_APP="$(new_repo cri_app)"
printf '{}\n' >"${CRI_APP}/package.json"
out="$(run_inject "$(session_json "${CRI_APP}" cri_app)")"
oq_grep "inject: app repo (no /infra) includes deployment rule" 'policy/delivery.yml' "${out}"
printf '%s' "${out}" | grep -q 'Stack - infrastructure / IaC' &&
	bad "inject: app repo without IaC must omit infra-stack fragment" || ok

# No /infra, no IaC, no GitHub tracker -> all scoped rules skipped.
CRI_BARE="$(new_repo cri_bare)"
out="$(run_inject "$(session_json "${CRI_BARE}" cri_bare)")"
printf '%s' "${out}" | grep -q 'auto-deploys non-prod' &&
	bad "inject: repo without /infra must omit deployment rule" || ok
printf '%s' "${out}" | grep -q 'Stack - infrastructure / IaC' &&
	bad "inject: repo without IaC must omit infra-stack fragment" || ok
printf '%s' "${out}" | grep -q 'Issue-first (GitHub-adopted repos)' &&
	bad "inject: repo without github tracker must omit issue-first rule" || ok
oq_grep "inject: always-on router present (bare repo)" 'You are the router' "${out}"
printf '%s' "${out}" | grep -q 'OpenSpec backend' &&
	bad "inject: repo without openspec/ must omit the OpenSpec spec-workflow rule" || ok
printf '%s' "${out}" | grep -q 'Worktree services' &&
	bad "inject: repo without a Compose file must omit the worktree-services rule" || ok
oq_grep "inject: worktree trust stays unscoped (bare repo)" 'never create trust' "${out}"

# Root compose.yaml -> 47-worktree-services injected (has-compose).
CRI_COMPOSE="$(new_repo cri_compose)"
printf 'services: {}\n' >"${CRI_COMPOSE}/compose.yaml"
out="$(run_inject "$(session_json "${CRI_COMPOSE}" cri_compose)")"
oq_grep "inject: compose repo includes the worktree-services rule" 'Worktree services' "${out}"
oq_grep "inject: worktree trust present (compose repo)" 'never create trust' "${out}"

# openspec/ present -> 33-spec-workflow-openspec injected (has-openspec). The
# native rule 30 is UNMARKED by design and must still arrive: rule 33 overrides
# its paths in prose, and marking 30 would drop it from knowledge mode, where the
# injection banner promises spec-workflow still applies.
CRI_OS="$(new_repo cri_os)"
mkdir -p "${CRI_OS}/openspec/changes"
out="$(run_inject "$(session_json "${CRI_OS}" cri_os)")"
oq_grep "inject: openspec repo includes the OpenSpec spec-workflow rule" 'OpenSpec backend' "${out}"
oq_grep "inject: openspec rule names the propose command" '/opsx:propose' "${out}"
oq_grep "inject: openspec repo still receives the native spec-workflow rule" 'Brownfield' "${out}"
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject: inject-when marker line must be stripped (openspec repo)" || ok

# A bare openspec/ directory is NOT proof of an OpenSpec spine (mirrors spine.sh
# refusing a bare spec/) -> the rule stays out.
CRI_OSBARE="$(new_repo cri_osbare)"
mkdir -p "${CRI_OSBARE}/openspec"
out="$(run_inject "$(session_json "${CRI_OSBARE}" cri_osbare)")"
printf '%s' "${out}" | grep -q 'OpenSpec backend' &&
	bad "inject: bare openspec/ dir must not trigger the OpenSpec rule" || ok

# ----- the tracker-path resolver (steer_tracker_file) -----
# Proven through rule 36-issue-first, which injects only when the resolved
# tracker declares `system: github`. This is the whole point of the fold: on an
# OpenSpec repo the declaration that counts is openspec/steer/tracker.md, and the
# pre-fold spec/tracker.md must no longer decide anything.

# Tracker at the NAMESPACED path -> issue-first injects.
CRI_OSTRK="$(new_repo cri_ostrk)"
mkdir -p "${CRI_OSTRK}/openspec/changes" "${CRI_OSTRK}/openspec/steer"
printf 'system: github\n' >"${CRI_OSTRK}/openspec/steer/tracker.md"
out="$(run_inject "$(session_json "${CRI_OSTRK}" cri_ostrk)")"
oq_grep "resolver: openspec/steer/tracker.md drives issue-first" 'Issue-first (GitHub-adopted repos)' "${out}"

# Tracker only at the OLD path on an OpenSpec repo -> it no longer decides, so
# issue-first stays out. (The session is told to migrate by check-unmanaged-repo.)
CRI_OSOLD="$(new_repo cri_osold)"
mkdir -p "${CRI_OSOLD}/openspec/changes" "${CRI_OSOLD}/spec"
printf 'system: github\n' >"${CRI_OSOLD}/spec/tracker.md"
out="$(run_inject "$(session_json "${CRI_OSOLD}" cri_osold)")"
printf '%s' "${out}" | grep -q 'Issue-first (GitHub-adopted repos)' &&
	bad "resolver: pre-fold spec/tracker.md must not drive issue-first on an openspec repo" || ok

# A NATIVE repo is untouched by the fold: spec/tracker.md still decides.
CRI_NATTRK="$(new_repo cri_nattrk)"
mkdir -p "${CRI_NATTRK}/spec"
printf 'system: github\n' >"${CRI_NATTRK}/spec/tracker.md"
out="$(run_inject "$(session_json "${CRI_NATTRK}" cri_nattrk)")"
oq_grep "resolver: native repo still resolves spec/tracker.md" 'Issue-first (GitHub-adopted repos)' "${out}"

# ---------------------------------------------------------------------------
# inject-standards.sh - parts under the 10,000-character cap on hook stdout.
#
# Claude Code persists a longer hook output to a file and gives the session a
# short "Output too large" pointer instead, while the hook still exits 0. The
# cap is per hook COMMAND, so the ruleset is registered as PARTS commands, each
# emitting one slice of a deterministic partition. These cases pin: the
# partition is ordered and complete, every part stays under budget, an empty
# part is silent, a ruleset that does not fit says so in-band on the last part
# (and the notice itself never busts the budget), and hooks.json registers the
# parts contiguously.
# ---------------------------------------------------------------------------
INJ_ERR="${WORK}/inject.err"

# (a) A small ruleset fits in part 1; the later parts are silent.
IF_SMALL="$(inject_fixture inject-small)"
printf '# Rule A\n\nBe brief.\n' >"${IF_SMALL}/rules/10-a.md"
printf '# Rule B\n\nBe correct.\n' >"${IF_SMALL}/rules/20-b.md"
IF_REPO="$(new_repo inject-small-repo)"
: >"${INJ_ERR}"
out="$(inject_part "${IF_SMALL}" "${IF_REPO}" 1 3)"
assert_has "inject parts: part 1 delivers rule A" "${out}" "Be brief."
assert_has "inject parts: part 1 delivers rule B" "${out}" "Be correct."
assert_has "inject parts: part 1 header names its position" "${out}" "part 1/3"
printf '%s' "${out}" | grep -q "RULESET INCOMPLETE" &&
	bad "inject parts: a fitting ruleset must not carry the incomplete notice" || ok
out="$(inject_part "${IF_SMALL}" "${IF_REPO}" 2 3)"
assert_empty "inject parts: an unused part emits nothing" "${out}"
out="$(inject_part "${IF_SMALL}" "${IF_REPO}" 3 3)"
assert_empty "inject parts: the last unused part emits nothing" "${out}"
[ -s "${INJ_ERR}" ] && bad "inject parts: a fitting ruleset writes nothing to stderr" || ok

# (b) Twelve ~1.9 KB rules across 3 parts: every rule arrives exactly once, in
#     order, no part over budget, no notice.
IF_BIG="$(inject_fixture inject-big)"
i=1
while [ "${i}" -le 12 ]; do
	{
		printf '# Rule %02d\n\n' "${i}"
		j=0
		while [ "${j}" -lt 30 ]; do
			printf 'Padding line %02d for rule %02d, long enough to consume budget.\n' "${j}" "${i}"
			j=$((j + 1))
		done
	} >"${IF_BIG}/rules/$(printf '%02d' "${i}")-big.md"
	i=$((i + 1))
done
IF_BREPO="$(new_repo inject-big-repo)"
: >"${INJ_ERR}"
all=""
k=1
prev_last=0
while [ "${k}" -le 3 ]; do
	out="$(inject_part "${IF_BIG}" "${IF_BREPO}" "${k}" 3)"
	n="$(inject_chars "${out}")"
	[ "${n}" -le 9500 ] && ok || bad "inject parts: part ${k} must stay within the 9500-char budget (got ${n})"
	[ "${n}" -gt 0 ] && ok || bad "inject parts: part ${k} of a 12-rule set must not be empty"
	# Rules inside a part, and across parts, keep lexical order.
	first="$(printf '%s' "${out}" | sed -n 's/^# Rule \([0-9]*\)$/\1/p' | sed -n '1p')"
	[ "${first:-0}" -gt "${prev_last}" ] && ok || bad "inject parts: part ${k} starts at rule ${first}, not after ${prev_last}"
	prev_last="$(printf '%s' "${out}" | sed -n 's/^# Rule \([0-9]*\)$/\1/p' | tail -n 1)"
	all="${all}${out}"
	k=$((k + 1))
done
i=1
while [ "${i}" -le 12 ]; do
	c="$(printf '%s' "${all}" | grep -c "^# Rule $(printf '%02d' "${i}")\$")"
	[ "${c}" -eq 1 ] && ok || bad "inject parts: rule ${i} must appear exactly once across parts (got ${c})"
	i=$((i + 1))
done
printf '%s' "${all}" | grep -q "RULESET INCOMPLETE" &&
	bad "inject parts: a ruleset that fits its parts carries no notice" || ok
[ -s "${INJ_ERR}" ] && bad "inject parts: nothing dropped means nothing on stderr" || ok

# (c) The same twelve rules in ONE part: a clean prefix is delivered, the part
#     stays under budget, the notice names the first dropped rules and counts
#     the rest, and stderr carries the full list for the gate.
: >"${INJ_ERR}"
out="$(inject_part "${IF_BIG}" "${IF_BREPO}" 1 1)"
n="$(inject_chars "${out}")"
[ "${n}" -le 9500 ] && ok || bad "inject cap: single part must stay within the budget (got ${n})"
assert_has "inject cap: over-cap payload carries the notice" "${out}" "RULESET INCOMPLETE"
assert_has "inject cap: notice names the first dropped rule" "${out}" "-big.md"
assert_has "inject cap: notice reports the dropped count" "${out}" "rule(s) were NOT injected"
assert_has "inject cap: notice summarises beyond the name limit" "${out}" " more."
assert_has "inject cap: earliest rule still delivered" "${out}" "# Rule 01"
grep -q '^steer-inject: dropped([0-9]*):' "${INJ_ERR}" && ok ||
	bad "inject cap: stderr must carry the machine-readable dropped list"
# The stderr list is complete: every rule not in stdout is named there.
i=1
while [ "${i}" -le 12 ]; do
	rn="$(printf '%02d' "${i}")-big.md"
	if printf '%s' "${out}" | grep -q "^# Rule $(printf '%02d' "${i}")\$"; then
		grep -q " ${rn}" "${INJ_ERR}" && bad "inject cap: delivered ${rn} must not be listed as dropped" || ok
	else
		grep -q " ${rn}" "${INJ_ERR}" && ok || bad "inject cap: dropped ${rn} must be listed on stderr"
	fi
	i=$((i + 1))
done

# (d) The notice is sized from the data: fill the only part to within a few
#     characters of the budget, then drop eight long-named rules. The guard must
#     pop rules to make room rather than overrun (the old fixed 300-char reserve
#     was smaller than the notice and busted the cap).
IF_EDGE="$(inject_fixture inject-edge)"
IF_EREPO="$(new_repo inject-edge-repo)"
: >"${INJ_ERR}"
hdr="$(inject_chars "$(inject_part "${IF_EDGE}" "${IF_EREPO}" 1 1)")"
fill=$((9500 - hdr - 10 - 7 - 3))
{
	printf '# fill\n'
	i=0
	while [ "${i}" -lt "${fill}" ]; do
		printf 'x'
		i=$((i + 1))
	done
	printf '\n'
} >"${IF_EDGE}/rules/10-fill.md"
i=0
while [ "${i}" -lt 8 ]; do
	printf '# tail %s\ny\n' "${i}" >"${IF_EDGE}/rules/2${i}-a-very-long-rule-name-to-make-the-notice-big-${i}.md"
	i=$((i + 1))
done
: >"${INJ_ERR}"
out="$(inject_part "${IF_EDGE}" "${IF_EREPO}" 1 1)"
n="$(inject_chars "${out}")"
[ "${n}" -le 9500 ] && ok || bad "inject cap: notice must never push a part over budget (got ${n})"
assert_has "inject cap: edge case still carries the notice" "${out}" "RULESET INCOMPLETE"
assert_has "inject cap: popped rules are counted as dropped" "${out}" " more."

# (e) Malformed part arguments fall back to a single part rather than silence.
out="$(inject_part "${IF_SMALL}" "${IF_REPO}" x 3)"
assert_has "inject parts: malformed part argument falls back to one part" "${out}" "Be correct."
out="$(inject_part "${IF_SMALL}" "${IF_REPO}" 5 3)"
assert_has "inject parts: part beyond PARTS falls back to one part" "${out}" "Be correct."

# (f) Missing rules dir: part 1 carries the fallback banner, other parts are silent.
IF_NORULES="$(inject_fixture inject-norules)"
rmdir "${IF_NORULES}/rules"
out="$(inject_part "${IF_NORULES}" "${IF_REPO}" 1 3)"
assert_has "inject parts: missing rules dir - part 1 emits the fallback banner" "${out}" "rules directory was not found"
out="$(inject_part "${IF_NORULES}" "${IF_REPO}" 2 3)"
assert_empty "inject parts: missing rules dir - part 2 is silent" "${out}"

# (g) hooks.json registers the parts contiguously as `k N`, all with the same N.
HOOKS_JSON_FLAT="$(tr -d '\\' <"${HOOKS}/hooks.json")"
n_parts="$(printf '%s' "${HOOKS_JSON_FLAT}" | grep -c 'inject-standards\.sh" [0-9]* [0-9]*"')"
[ "${n_parts}" -ge 2 ] && ok || bad "hooks.json: inject-standards.sh must be registered as several parts (got ${n_parts})"
k=1
while [ "${k}" -le "${n_parts}" ]; do
	printf '%s' "${HOOKS_JSON_FLAT}" | grep -q "inject-standards\.sh\" ${k} ${n_parts}\"" && ok ||
		bad "hooks.json: inject-standards.sh part ${k}/${n_parts} not registered"
	k=$((k + 1))
done
# (h) The real ruleset arrives whole in the code-max shape (every predicate true).
IF_MAXREPO="$(new_repo inject-real-max)"
mkdir -p "${IF_MAXREPO}/infra" "${IF_MAXREPO}/apps" "${IF_MAXREPO}/spec" \
	"${IF_MAXREPO}/openspec/changes" "${IF_MAXREPO}/openspec/steer" "${IF_MAXREPO}/policy"
# automation-optin fails CLOSED, so "every predicate true" has to declare it -
# without the file 53-autonomous-loops is legitimately absent and this block's
# every-heading-delivered sweep would read that as a dropped rule.
printf 'loops: true\n' >"${IF_MAXREPO}/policy/automation.yml"
printf 'services: {}\n' >"${IF_MAXREPO}/compose.yaml"
# The fixture carries openspec/, so the tracker that DECIDES sits at the
# namespaced path - writing it to spec/tracker.md would leave tracker-github
# false and silently drop 36-issue-first from this "every predicate" shape.
printf 'system: github\n' >"${IF_MAXREPO}/openspec/steer/tracker.md"
: >"${INJ_ERR}"
k=1
all=""
while [ "${k}" -le "${n_parts}" ]; do
	out="$(inject_part "${PLUGIN}" "${IF_MAXREPO}" "${k}" "${n_parts}")"
	n="$(inject_chars "${out}")"
	[ "${n}" -le 9500 ] && ok || bad "inject real: part ${k} over budget (${n})"
	all="${all}${out}"
	k=$((k + 1))
done
printf '%s' "${all}" | grep -q "RULESET INCOMPLETE" &&
	bad "inject real: the shipped ruleset must fit its registered parts" || ok
for rf in "${PLUGIN}"/rules/*.md; do
	rl="$(sed -n '/^#/{p;q;}' "${rf}")"
	printf '%s' "${all}" | grep -qxF -- "${rl}" && ok ||
		bad "inject real: $(basename "${rf}") heading not delivered: ${rl}"
done

# ----- inject-standards.sh: the Copilot surfaces get ONE JSON envelope (#513) -----
# Copilot's SessionStart injects context only from a JSON object on stdout - the
# CLI reads a top-level `additionalContext`, VS Code `hookSpecificOutput....` -
# and older builds let the LAST hook returning context win, so the parted Claude
# delivery must not be mirrored: part 1 carries the whole eligible ruleset, every
# other part stays silent. Both surfaces run the Claude hooks.json as-is and are
# recognised from their payload shape (snake_case SessionStart with "timestamp"
# and no "permission_mode"; VS Code adds "model"). A Claude payload keeps the raw
# parted output.
CP_REPO="$(new_repo inject-copilot)"
mkdir -p "${CP_REPO}/infra" "${CP_REPO}/apps" "${CP_REPO}/spec"
printf 'system: github\n' >"${CP_REPO}/spec/tracker.md"
cp_vscode_json() { # <cwd>  -> the payload VS Code Copilot Chat sends (observed 1.135)
	printf '{"timestamp":"2026-09-02T16:03:56.200Z","hook_event_name":"SessionStart","session_id":"s","transcript_path":"/t","source":"new","model":"auto","cwd":"%s"}' "$1"
}
cp_cli_json() { # <cwd>  -> the Copilot CLI's payload to a PascalCase registration (observed 1.0.92)
	printf '{"hook_event_name":"SessionStart","session_id":"s","timestamp":"2026-10-20T13:03:25.381Z","cwd":"%s","source":"new","initial_prompt":"hi"}' "$1"
}
cp_camel_json() { # <cwd>  -> the CLI's camelCase payload, sent only to a camelCase registration
	printf '{"sessionId":"s","timestamp":1788363641659,"cwd":"%s","source":"new"}' "$1"
}
cp_claude_json() { # <cwd>  -> a Claude Code payload (carries permission_mode)
	printf '{"session_id":"s","transcript_path":"/t","cwd":"%s","permission_mode":"default","hook_event_name":"SessionStart","source":"startup"}' "$1"
}
# JSON envelope shape: exactly one object opening with the top-level key and
# carrying the nested VS Code key; a strict parser confirms it where one exists.
assert_envelope() { # <label> <out>
	case "$2" in
	'{"additionalContext":"'*'"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"'*'"}}') ok ;;
	*) bad "$1 (expected the two-key envelope, got: $(printf '%s' "$2" | head -c 160))" ;;
	esac
	if command -v python3 >/dev/null 2>&1; then
		printf '%s' "$2" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["additionalContext"]==d["hookSpecificOutput"]["additionalContext"]' 2>/dev/null &&
			ok || bad "$1 (envelope is not valid JSON with equal halves)"
	fi
}
# How many parts hooks.json really registers, read from the manifest rather than
# written here a second time: a literal would keep passing after the
# registration changed, leaving the silence assertions aimed at parts no session
# runs.
CP_PARTS="$(tr -d '\\' <"${HOOKS}/hooks.json" | grep -c 'inject-standards\.sh" [0-9]* [0-9]*"')"
[ "${CP_PARTS:-0}" -ge 2 ] || bad "inject copilot: hooks.json registers ${CP_PARTS} part(s) - the silence assertions below need at least two"
# (a) Copilot Chat in VS Code: one envelope carrying the whole ruleset, detected
# from the payload shape alone.
out="$(printf '%s' "$(cp_vscode_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_envelope "inject copilot: VS Code payload emits the JSON envelope" "${out}"
assert_has "inject copilot: envelope carries the first rule" "${out}" 'You are the router'
assert_has "inject copilot: envelope carries the last rule" "${out}" 'End-of-session checklist'
assert_has "inject copilot: envelope carries the scoped issue-first rule" "${out}" 'Issue-first (GitHub-adopted repos)'
assert_has "inject copilot: refresh hint names the VS Code update path" "${out}" 'Extensions view'
assert_has "inject copilot: refresh hint names the CLI update path" "${out}" 'copilot plugin update steer'
assert_has "inject copilot: refresh hint names the Copilot app update path" "${out}" 'Customize > Plugins in the Copilot app'
printf '%s' "${out}" | grep -q 'part 1/' && bad "inject copilot: envelope must not be labelled as a part" || ok
printf '%s' "${out}" | grep -q 'RULESET INCOMPLETE' && bad "inject copilot: no rule may be dropped (cap lifted)" || ok
# (a2) The Copilot CLI's payload (no "model") is detected the same way - before
# this, it fell through to the Claude raw path and the CLI discarded the ruleset.
out="$(printf '%s' "$(cp_cli_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_envelope "inject copilot: CLI payload emits the JSON envelope" "${out}"
assert_has "inject copilot: CLI envelope carries the last rule" "${out}" 'End-of-session checklist'
out2="$(printf '%s' "$(cp_cli_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 2 "${CP_PARTS}" 2>/dev/null)"
assert_empty "inject copilot: CLI part 2 of ${CP_PARTS} is silent" "${out2}"
# (b) Every part but 1 is silent on a Copilot surface, even though VS Code runs
# every `k N` registration in hooks.json - the LAST hook returning context
# wins there, so a mirrored delivery would overwrite the ruleset with a tail part.
out2="$(printf '%s' "$(cp_vscode_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 2 "${CP_PARTS}" 2>/dev/null)"
assert_empty "inject copilot: part 2 of ${CP_PARTS} is silent on a Copilot surface" "${out2}"
out2="$(printf '%s' "$(cp_vscode_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" "${CP_PARTS}" "${CP_PARTS}" 2>/dev/null)"
assert_empty "inject copilot: the last part is silent on a Copilot surface" "${out2}"
# (c) Fail-safe: a Claude payload (permission_mode) stays raw and parted; so does a
# payload of unknown shape (the camelCase form no registration here receives),
# which must degrade to the Claude path rather than to silence.
out="$(printf '%s' "$(cp_claude_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
case "${out}" in '<!-- Engineering standards'*) ok ;; *) bad "inject copilot: Claude payload must stay raw (got: $(printf '%s' "${out}" | head -c 80))" ;; esac
assert_has "inject copilot: Claude payload keeps the parted header" "${out}" "part 1/${CP_PARTS}"
assert_has "inject copilot: Claude payload keeps the Claude refresh hint" "${out}" '/plugin update steer@e22-plugins'
out="$(run_hook inject-standards.sh "$(cp_camel_json "${CP_REPO}")")"
case "${out}" in '<!-- Engineering standards'*) ok ;; *) bad "inject copilot: unknown payload shape must default to Claude raw (got: $(printf '%s' "${out}" | head -c 80))" ;; esac
# (d) Knowledge-work folder on a Copilot surface: still the envelope, still lean.
CP_KNOW="${WORK}/inject-copilot-know"
mkdir -p "${CP_KNOW}"
printf 'notes\n' >"${CP_KNOW}/README.md"
out="$(printf '%s' "$(cp_vscode_json "${CP_KNOW}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_envelope "inject copilot: knowledge-work folder gets the envelope" "${out}"
assert_has "inject copilot: knowledge-work envelope says so" "${out}" 'knowledge-work mode'
printf '%s' "${out}" | grep -q 'Issue-first (GitHub-adopted repos)' && bad "inject copilot: knowledge-work envelope must omit scoped rules" || ok
# (d2) A committed copilot-instructions.md identical to the plugin's is already
# loaded by Copilot, so the hook injects only the rules that file lacks (#767). A stale copy still gets the live rules, and Claude is unaffected.
mkdir -p "${CP_REPO}/.github"
cp "${PLUGIN}/templates/github/copilot-instructions.md" "${CP_REPO}/.github/"
out="$(printf '%s' "$(cp_vscode_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_envelope "inject copilot: current committed copy - notice arrives in the envelope" "${out}"
assert_has "inject copilot: current committed copy - notice says why" "${out}" 'not injected again'
printf '%s' "${out}" | grep -q 'You are the router' && bad "inject copilot: current committed copy must not be injected twice" || ok
# The flat file leaves out the path-scoped infra rule, so an IaC repo still
# gets that one always-on.
assert_has "inject copilot: current committed copy - rules it lacks still injected" "${out}" 'Stack - infrastructure / IaC'
out="$(printf '%s' "$(cp_claude_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_has "inject copilot: Claude still gets the ruleset beside a committed copy" "${out}" 'You are the router'
printf '\nstale\n' >>"${CP_REPO}/.github/copilot-instructions.md"
out="$(printf '%s' "$(cp_cli_json "${CP_REPO}")" | sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_has "inject copilot: stale committed copy - live ruleset injected" "${out}" 'You are the router'
rm -rf "${CP_REPO}/.github"
# (e) Missing rules dir on a Copilot surface: the fallback banner is still delivered
# - inside the envelope, so it is not discarded as non-JSON.
out="$(printf '%s' "$(cp_vscode_json "${CP_REPO}")" | CLAUDE_PLUGIN_ROOT="${IF_NORULES}" sh "${HOOKS}/inject-standards.sh" 1 "${CP_PARTS}" 2>/dev/null)"
assert_envelope "inject copilot: missing rules dir - banner arrives in the envelope" "${out}"
assert_has "inject copilot: missing rules dir - banner text present" "${out}" 'rules directory was not found'

# Codex: codex-hooks.json carries only the rule injection, with the same part
# count as hooks.json, and every part survives a host that sets PLUGIN_ROOT alone.
CX_MANIFEST="$(tr -d '\\' <"${HOOKS}/codex-hooks.json")"
CX_PARTS="$(printf '%s' "${CX_MANIFEST}" | grep -c 'inject-standards\.sh" [0-9]* [0-9]*"')"
CC_PARTS="$(tr -d '\\' <"${HOOKS}/hooks.json" | grep -c 'inject-standards\.sh" [0-9]* [0-9]*"')"
assert_eq "codex-hooks.json: same rule-part count as hooks.json" "${CX_PARTS}" "${CC_PARTS}"
assert_eq "codex-hooks.json: every part lifts Codex's context cap" \
	"$(printf '%s' "${CX_MANIFEST}" | grep -c '"additionalContextLimit": 0')" "${CC_PARTS}"
printf '%s' "${CX_MANIFEST}" | grep -q '"PreToolUse"\|"PostToolUse"\|"Stop"' &&
	bad "codex-hooks.json: gates read Claude tool payloads and must not be registered on Codex" || ok
CX_DIR="$(mktemp -d)"
git -C "${CX_DIR}" init -q
CX_OUT="$(
	cd "${CX_DIR}" || exit 1
	_k=1
	while [ "${_k}" -le "${CX_PARTS}" ]; do
		_cmd="$(printf '%s' "${CX_MANIFEST}" | grep -o "CLAUDE_PLUGIN_ROOT=[^,]*inject-standards\.sh\" ${_k} ${CX_PARTS}" | head -n 1)"
		printf '{"hook_event_name":"SessionStart","model":"gpt-5.5","source":"startup","cwd":"%s"}' "${CX_DIR}" |
			env -u CLAUDE_PLUGIN_ROOT PLUGIN_ROOT="${PLUGIN}" sh -c "${_cmd}" 2>/dev/null
		_k=$((_k + 1))
	done
)"
rm -rf "${CX_DIR}"
assert_has "codex: PLUGIN_ROOT alone renders the first rule" "${CX_OUT}" "You are the router"
assert_has "codex: PLUGIN_ROOT alone renders the Definition of Done" "${CX_OUT}" "## Definition of Done"
assert_has "codex: PLUGIN_ROOT alone renders the Spec workflow" "${CX_OUT}" "## Spec workflow"

finish
