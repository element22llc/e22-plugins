#!/usr/bin/env sh
# steer SessionStart hook.
#
# Everything this script writes to stdout becomes `additionalContext` for the
# session — i.e. the always-on engineering operating rules. It runs once per
# session (startup | resume | clear) when the plugin is enabled.
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

printf '<!-- Engineering standards — steer plugin v%s. Run `/plugin update steer@e22-plugins` to refresh. -->\n\n' "${VERSION}"

# Work mode decides how much of the ruleset applies. 'knowledge' = a confidently
# non-code folder (the typical Claude Cowork product-owner case: a connected
# folder of specs/docs, no git repo) → inject only the lean, always-on
# PO-relevant set and skip every code/infra/tracker-scoped rule. Anything else,
# or any doubt, → 'code' = the full ruleset (fail-safe; never silently drops a
# rule). See steer_work_mode in lib/scope.sh.
WORK_MODE="$(steer_work_mode "${CWD}")"
if [ "${WORK_MODE}" = "knowledge" ]; then
  printf '<!-- steer: knowledge-work mode — this is a non-code folder, so the code/infra/tracker-specific rules are intentionally omitted (not missing). The spec-workflow, decision-capture, living-docs, roles and output rules below still apply. -->\n\n'
fi

if [ -d "${RULES_DIR}" ]; then
  for f in "${RULES_DIR}"/*.md; do
    [ -e "${f}" ] || continue
    # A rule may scope itself with a first-line `<!-- steer:inject-when=<token> -->`
    # marker. Inject it only when that scope applies; strip the marker line so it
    # never reaches context. No marker (the common case) → emit unchanged.
    IFS= read -r _first <"${f}" || _first=""
    case "${_first}" in
    '<!-- steer:inject-when='*' -->')
      # A knowledge-work folder skips EVERY conditional rule — none of the
      # code/infra/tracker-scoped rules apply there — leaving only the unmarked,
      # always-on PO-relevant core. (Marker line is dropped with the rule.)
      [ "${WORK_MODE}" = "knowledge" ] && continue
      _token="${_first#<!-- steer:inject-when=}"
      _token="${_token% -->}"
      steer_inject_when_ok "${_token}" "${CONSUMER_ROOT}" || continue
      tail -n +2 "${f}"
      ;;
    *)
      cat "${f}"
      ;;
    esac
    printf '\n\n'
  done
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

exit 0
