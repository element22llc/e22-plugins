#!/usr/bin/env sh
# steer SessionStart hook — template drift detector (self-heal enforcement).
#
# WHY THIS EXISTS
#   Skills that copy a bundled template into the product repo
#   (PRODUCTIONIZATION.md / BUILD-STATUS.md / feature intent.md+contract.md)
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
#   POSIX sh, no jq, no process substitution. The instantiated files live in the
#   CONSUMER repo; the SessionStart cwd may be a SUBDIRECTORY of it, so we resolve
#   the work-tree root from the payload cwd (mirroring check-open-questions.sh)
#   rather than trusting relative paths — otherwise starting Claude in apps/web
#   would silently find no drift. Bundled templates come via ${CLAUDE_PLUGIN_ROOT}.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

TPL="${CLAUDE_PLUGIN_ROOT}/templates/spec"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
REPO="$(steer_repo_root "${CWD}")" || REPO="${CWD}"

# Print the `##`/`###` headings present in the template but absent from the existing
# file. Headings are the reliable drift signal: whole new sections (e.g. a later
# "## Outdated dependencies & bad practices") are exactly what gets missed. We
# deliberately do NOT diff checklist items here — filled-in placeholders and reworded
# items over-report and would put false positives in the notice. Once the model is
# pointed at the gap it opens the template and reconciles items too.
#
# We also skip headings carrying `<!-- steer:placeholder -->` (e.g. the seed
# `### Q-001 — [...]` open-question block). Those are BY DESIGN rewritten or deleted
# once a feature has a real question or is fully specced, so a verbatim match against
# the template heading never succeeds and every correctly-completed file would be
# flagged on every session. This mirrors check-open-questions.sh, which already
# ignores the same marker.
missing_sections() {
  _existing="$1"
  _template="$2"
  [ -f "$_existing" ] && [ -f "$_template" ] || return 0
  # One awk over the two files instead of a grep spawn per template heading: on a
  # 50-feature repo the old inner loop spawned 800+ greps at every SessionStart,
  # setting the startup latency floor. awk records the template's `##`/`###`
  # headings (skipping `steer:placeholder` seeds), deletes any the existing file
  # also has, and prints the remainder — an exact full-line match, as `grep -qxF`
  # did. Order-insensitive; `sort` gives a stable, deterministic report.
  awk '
    FNR == NR {
      if (($0 ~ /^## / || $0 ~ /^### /) && $0 !~ /steer:placeholder/) t[$0] = 1
      next
    }
    ($0 in t) { delete t[$0] }
    END { for (h in t) print h }
  ' "$_template" "$_existing" 2>/dev/null | sort
}

REPORT=""

# args: label, repo-relative existing-file, bundled-template
# The file is read from ${REPO}/<rel> (root-anchored), but the printed label keeps
# the relative path so the notice reads the same from any cwd.
check_pair() {
  _rel="$2"
  _out="$(missing_sections "${REPO}/${_rel}" "$3")"
  [ -n "$_out" ] || return 0
  REPORT="${REPORT}
- **${1}** (\`${_rel}\`) is missing:
$(printf '%s\n' "$_out" | sed 's/^/    - /')"
}

check_pair "PRODUCTIONIZATION.md" "spec/PRODUCTIONIZATION.md" "${TPL}/productionization.md"
check_pair "BUILD-STATUS.md"         "spec/BUILD-STATUS.md"         "${TPL}/build-status.md"

# Feature specs — there may be many; glob guards against the no-match literal.
for _intent in "${REPO}"/spec/features/*/intent.md; do
  [ -e "$_intent" ] || continue
  _rel="${_intent#"${REPO}/"}"
  check_pair "intent.md ($(dirname "$_rel"))" "$_rel" "${TPL}/feature-intent.md"
done
for _contract in "${REPO}"/spec/features/*/contract.md; do
  [ -e "$_contract" ] || continue
  _rel="${_contract#"${REPO}/"}"
  check_pair "contract.md ($(dirname "$_rel"))" "$_rel" "${TPL}/feature-contract.md"
done

[ -n "$REPORT" ] || exit 0

printf '<!-- steer: template drift detected -->\n'
printf '# ⚠ template reconciliation required — do this before anything else\n\n'
printf 'One or more spec files in this repo were instantiated under an OLDER plugin '
printf 'version and are missing sections the current bundled template now defines. '
printf 'These gaps are invisible if you resume "from the checklist" — that is exactly '
printf 'the failure this notice prevents.\n\n'
printf '**Before** resuming any spec workflow (/steer:adopt, /steer:build, '
printf '/steer:spec-scaffold) or summarizing status, splice each missing section into '
printf 'its file (leave it unchecked/empty), preserving everything already filled in. '
# shellcheck disable=SC2016  # literal ${CLAUDE_PLUGIN_ROOT} token is intentional notice text
printf 'Match against the bundled template under `${CLAUDE_PLUGIN_ROOT}/templates/spec/`; '
printf 'this is the plugin-wide Template reconciliation convention. This notice clears '
printf 'itself automatically once the files are reconciled.\n'
printf '%s\n' "$REPORT"
