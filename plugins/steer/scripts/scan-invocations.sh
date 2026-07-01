#!/usr/bin/env sh
# scan-invocations.sh — read-only invalid-invocation detector for /steer:sync's
# invocation-hygiene step (templates/reference/INVOCATION.md).
#
# WHY THIS EXISTS
#   A managed repo's live prose (CLAUDE.md, README.md, the PR template) is written
#   at bootstrap/adoption time and then frozen: the strings never re-resolve against
#   the plugin. When skills are renamed, folded into a mode of another skill
#   (`conventions` -> `/steer:reference conventions`), or made user-invocable:false
#   (`spec-scaffold`), the repo keeps emitting invocations that no longer work — and
#   Claude Code has no built-in check that a referenced skill exists. The plugin's own
#   CI linter (scripts/check_standards.py) already catches these, but only in the
#   plugin's OWN prose; nothing re-checks a consumer repo. This detector closes that
#   gap for /steer:sync.
#
# WHAT IT READS
#   $1  repo-root    — a managed repo to inspect (default: ".")
#   $2  plugin-root  — the plugin source, to derive the VALID invocation surface
#                      (default: $CLAUDE_PLUGIN_ROOT, else this script's parent dir).
#
# HOW "VALID" IS DERIVED (never a hardcoded list — self-updating with the plugin)
#   * skill names           = the directory names under $PLUGIN/skills/
#   * user-invocable:false  = skills whose SKILL.md frontmatter sets it (gateways a
#                             user cannot type — reached only via a front door)
#   * reference modes       = the `<!-- steer:modes a,b,c -->` marker in
#                             skills/reference/SKILL.md
#   So a future skill rename/add changes the verdicts here with no edit to this file.
#
# WHAT IT SCANS (live instruction surfaces ONLY — the false-positive guard)
#   CLAUDE.md, README.md, .github/pull_request_template.md. It deliberately does NOT
#   scan append-only / historical / provenance prose (spec/HISTORY.md, spec/reports/*,
#   spec/decisions/* ADRs, spec/sources/*, spec/reference/*, feature intent.md
#   provenance lines) — a past `/e22-adopt` there is a legitimate record of what was
#   run, not live guidance, and must never be rewritten.
#
# OUTPUT (stdout) — one TAB-separated line PER problem occurrence (clean repo = silent):
#   <file>\t<lineno>\t<found>\t<class>\t<suggested-fix>
#   class ∈ legacy-e22 | reference-mode | noncallable-gateway | unknown
#     legacy-e22           /e22-<skill> pre-rebrand prefix; <skill> resolves
#                          -> fix /steer:<skill>
#     reference-mode       /steer:<mode> where <mode> is a `reference` topic, not a
#                          skill -> fix /steer:reference <mode>
#     noncallable-gateway  /steer:<skill> where <skill> is user-invocable:false; a
#                          user cannot type it -> route to a front door (human decides)
#     unknown              /steer:<tok> resolves to no skill and is not a mode ->
#                          flag only, no mechanical fix
#   A valid invocation (a real callable skill, or /steer:reference <mode>) emits
#   NOTHING. suggested-fix is `-` when there is no mechanical rewrite.
#   Findings are reported on STDOUT, NEVER via a nonzero exit — so a skill running
#   this through a tool's Bash wrapper does not read a normal "findings" run as a
#   failure (same contract as scan-capabilities.sh).
#
# EXIT CODES
#   0  ran OK — read stdout for the findings.
#   2  usage error — too many arguments.
#   3  repo-root is missing or unreadable.
#
# SECURITY: read-only; never executes repo content; no network; no jq. Diagnostics
#   name the path + token, never surrounding file contents.
#
# Usage:
#   sh scan-invocations.sh [repo-root] [plugin-root]
#
# NOTE: plugin-internal (a /steer:sync tool). NOT shipped into consumer repos, so it
# carries no byte-identical-copy obligation. Keep the class vocabulary in lockstep
# with INVOCATION.md ("Drift detection & auto-repair").

set -u

usage() {
	echo "usage: scan-invocations.sh [repo-root] [plugin-root]" >&2
	exit 2
}

[ "$#" -le 2 ] || usage

ROOT="${1:-.}"
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN="${2:-${CLAUDE_PLUGIN_ROOT:-${HERE%/scripts}}}"

[ -d "$ROOT" ] && [ -r "$ROOT" ] || {
	echo "scan-invocations: cannot read repo-root: $ROOT" >&2
	exit 3
}

SKILLS_DIR="$PLUGIN/skills"

# --- valid invocation surface, derived live from the plugin ------------------

# All skill names (space-separated, padded so `case " $SKILLS " in *" x "*)` works).
SKILLS=" "
if [ -d "$SKILLS_DIR" ]; then
	for _d in "$SKILLS_DIR"/*/; do
		[ -f "${_d}SKILL.md" ] || continue
		_name="$(basename "$_d")"
		SKILLS="${SKILLS}${_name} "
	done
fi

# Skills whose frontmatter declares `user-invocable: false` (gateways).
NONCALLABLE=" "
if [ -d "$SKILLS_DIR" ]; then
	for _d in "$SKILLS_DIR"/*/; do
		_md="${_d}SKILL.md"
		[ -f "$_md" ] || continue
		# Frontmatter only: read up to the second `---`. A tolerant grep is enough —
		# the value is `false` (optionally quoted) on a `user-invocable:` line.
		if grep -Eq '^user-invocable:[[:space:]]*("?false"?)[[:space:]]*$' "$_md" 2>/dev/null; then
			NONCALLABLE="${NONCALLABLE}$(basename "$_d") "
		fi
	done
fi

# Reference modes from the `<!-- steer:modes a,b,c -->` marker (single source of
# truth for which `/steer:reference <mode>` topics exist).
MODES=" "
_ref="$SKILLS_DIR/reference/SKILL.md"
if [ -f "$_ref" ]; then
	_line="$(grep -oE '<!--[[:space:]]*steer:modes[[:space:]]+[a-z0-9,_-]+' "$_ref" 2>/dev/null | head -n1)"
	_csv="${_line##*steer:modes}"
	# strip leading spaces, split commas -> spaces
	_csv="$(printf '%s' "$_csv" | tr ',' ' ')"
	for _m in $_csv; do
		MODES="${MODES}${_m} "
	done
fi

in_set() { case "$2" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# --- scan the live instruction surfaces --------------------------------------

# Fixed allowlist: unambiguously live, human-facing instruction prose. Extend
# deliberately — never add append-only/provenance files (see header).
SURFACES="CLAUDE.md README.md .github/pull_request_template.md"

for REL in $SURFACES; do
	F="$ROOT/$REL"
	[ -f "$F" ] || continue

	# `/steer:<tok>` occurrences (grep -o: one match per line as `<lineno>:<match>`).
	grep -noE '/steer:[a-z][a-z-]*' "$F" 2>/dev/null | while IFS=: read -r _ln _tok; do
		tok="${_tok#/steer:}"
		if in_set "$tok" "$MODES"; then
			emit "$REL" "$_ln" "$_tok" "reference-mode" "/steer:reference $tok"
		elif in_set "$tok" "$NONCALLABLE"; then
			emit "$REL" "$_ln" "$_tok" "noncallable-gateway" "-"
		elif in_set "$tok" "$SKILLS"; then
			: # valid callable skill — emit nothing
		else
			emit "$REL" "$_ln" "$_tok" "unknown" "-"
		fi
	done

	# `/e22-<tok>` occurrences — pre-rebrand prefix. Skip the marketplace id
	# (`/e22-plugins`), the one legitimate slash-prefixed e22- token.
	grep -noE '/e22-[a-z][a-z-]*' "$F" 2>/dev/null | while IFS=: read -r _ln _tok; do
		tok="${_tok#/e22-}"
		[ "$tok" = "plugins" ] && continue
		if in_set "$tok" "$SKILLS"; then
			emit "$REL" "$_ln" "$_tok" "legacy-e22" "/steer:$tok"
		else
			# a renamed/removed skill (e.g. /e22-drift) — legacy but not a pure
			# token swap; flag for a human.
			emit "$REL" "$_ln" "$_tok" "unknown" "-"
		fi
	done
done

exit 0
