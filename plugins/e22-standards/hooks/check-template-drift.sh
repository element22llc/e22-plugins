#!/usr/bin/env sh
# e22-standards SessionStart hook — template drift detector (self-heal enforcement).
#
# WHY THIS EXISTS
#   Skills that copy a bundled template into the product repo
#   (PRODUCTION-READINESS.md / BUILD-STATUS.md / feature intent.md+contract.md)
#   carry an in-prose "reconcile against the current template on resume" step. In
#   practice the model routinely SKIPS that step: when the file looks complete it
#   resumes "from the checklist" and never diffs, so sections added by a later
#   `/plugin update` stay invisible. Prose can't force the action — a SKILL.md is
#   advisory. This hook makes the drift unavoidable instead: it runs the diff
#   deterministically at session start and injects a concrete, high-salience notice
#   naming exactly which sections are missing.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path as
#   inject-standards.sh). The hook stays SILENT when there is no drift, so a
#   reconciled repo gets zero noise and the notice clears itself once the files are
#   brought up to date.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd is the CONSUMER repo, so the
#   instantiated files are addressed by relative path and templates via
#   ${CLAUDE_PLUGIN_ROOT}.

ROOT="${CLAUDE_PLUGIN_ROOT}"
TPL="${ROOT}/templates/spec"

# Print the `##`/`###` headings present in the template but absent from the existing
# file. Headings are the reliable drift signal: whole new sections (e.g. a later
# "## Outdated dependencies & bad practices") are exactly what gets missed. We
# deliberately do NOT diff checklist items here — filled-in placeholders and reworded
# items over-report and would put false positives in the notice. Once the model is
# pointed at the gap it opens the template and reconciles items too.
missing_sections() {
  _existing="$1"
  _template="$2"
  [ -f "$_existing" ] && [ -f "$_template" ] || return 0
  grep -E '^#{2,3} ' "$_template" 2>/dev/null | while IFS= read -r _h; do
    grep -qxF "$_h" "$_existing" 2>/dev/null || printf '%s\n' "$_h"
  done
}

REPORT=""

# args: label, existing-file, bundled-template
check_pair() {
  _out="$(missing_sections "$2" "$3")"
  [ -n "$_out" ] || return 0
  REPORT="${REPORT}
- **${1}** (\`${2}\`) is missing:
$(printf '%s\n' "$_out" | sed 's/^/    - /')"
}

check_pair "PRODUCTION-READINESS.md" "spec/PRODUCTION-READINESS.md" "${TPL}/production-readiness.md"
check_pair "BUILD-STATUS.md"         "spec/BUILD-STATUS.md"         "${TPL}/build-status.md"

# Feature specs — there may be many; glob guards against the no-match literal.
for _intent in spec/features/*/intent.md; do
  [ -e "$_intent" ] || continue
  check_pair "intent.md ($(dirname "$_intent"))" "$_intent" "${TPL}/feature-intent.md"
done
for _contract in spec/features/*/contract.md; do
  [ -e "$_contract" ] || continue
  check_pair "contract.md ($(dirname "$_contract"))" "$_contract" "${TPL}/feature-contract.md"
done

[ -n "$REPORT" ] || exit 0

printf '<!-- e22-standards: template drift detected -->\n'
printf '# ⚠ E22 template reconciliation required — do this before anything else\n\n'
printf 'One or more spec files in this repo were instantiated under an OLDER plugin '
printf 'version and are missing sections the current bundled template now defines. '
printf 'These gaps are invisible if you resume "from the checklist" — that is exactly '
printf 'the failure this notice prevents.\n\n'
printf '**Before** resuming any E22 spec workflow (/e22-adopt, /e22-build, '
printf '/e22-spec-scaffold) or summarizing status, splice each missing section into '
printf 'its file (leave it unchecked/empty), preserving everything already filled in. '
# shellcheck disable=SC2016  # literal ${CLAUDE_PLUGIN_ROOT} token is intentional notice text
printf 'Match against the bundled template under `${CLAUDE_PLUGIN_ROOT}/templates/spec/`; '
printf 'this is the plugin-wide Template reconciliation convention. This notice clears '
printf 'itself automatically once the files are reconciled.\n'
printf '%s\n' "$REPORT"
