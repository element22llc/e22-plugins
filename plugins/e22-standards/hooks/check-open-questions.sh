#!/usr/bin/env sh
# e22-standards SessionStart hook — open-questions nudge (anti-rot).
#
# WHY THIS EXISTS
#   Open questions in the spec spine (each feature's intent.md → "## Open
#   questions", and vision.md / PRODUCTIONIZATION.md) get written down once,
#   gated at PO acceptance, then forgotten. Nothing resurfaces them, so they
#   rot. The /e22-questions skill resolves them — but a skill is pull, not push:
#   it only runs when someone remembers to invoke it. This hook makes the
#   backlog visible every session so it can't quietly accumulate.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path
#   as inject-standards.sh / check-template-drift.sh). The hook stays SILENT
#   when there are no open questions, so a clean repo gets zero noise and the
#   notice clears itself once questions are answered or explicitly deferred.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd is the CONSUMER repo, so spec
#   files are addressed by relative path.

# Count unchecked open questions in one file — scoped to the "## Open questions"
# section only (intent.md also has PO-acceptance checkboxes elsewhere we must
# NOT count), and skipping the bundled template's bracketed placeholder seed
# (`- [ ] [Anything ambiguous …]`) so a freshly scaffolded feature doesn't fire.
count_open() {
  _f="$1"
  [ -f "$_f" ] || { printf '0\n'; return 0; }
  awk '
    /^## Open questions/ { inq=1; next }   # enter the section
    /^## / { inq=0 }                       # any later level-2 heading ends it
    /^# /  { inq=0 }
    inq && /^- \[ \] / {
      rest = substr($0, 7)                 # text after "- [ ] "
      if (rest !~ /^\[/) c++               # skip bracketed [placeholder] seeds
    }
    END { print c+0 }
  ' "$_f"
}

TOTAL=0
REPORT=""

# args: label, file
check_file() {
  _n="$(count_open "$2")"
  [ "$_n" -gt 0 ] 2>/dev/null || return 0
  TOTAL=$((TOTAL + _n))
  REPORT="${REPORT}
- \`${2}\` — ${_n}"
}

check_file "vision" "spec/vision.md"
for _intent in spec/features/*/intent.md; do
  [ -e "$_intent" ] || continue
  check_file "intent" "$_intent"
done
check_file "productionization" "spec/PRODUCTIONIZATION.md"

[ "$TOTAL" -gt 0 ] 2>/dev/null || exit 0

printf '<!-- e22-standards: open questions outstanding -->\n'
printf 'ℹ **%s open question(s) await answers** across this product'"'"'s specs:\n' "$TOTAL"
printf '%s\n\n' "$REPORT"
printf 'They do not block work, but they rot if left — they were written down '
printf 'once and nothing else resurfaces them. Run **/e22-questions** to sweep '
printf 'them and drive each to an answer (or an explicit deferral). This notice '
printf 'clears itself once they are resolved.\n'
