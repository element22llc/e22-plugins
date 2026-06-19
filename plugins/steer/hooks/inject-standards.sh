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
#   - Fail-soft: even if the rules dir is missing we still emit the banner, so a
#     session is never left with silently-empty org context.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/report-fault.sh"

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

if [ -d "${RULES_DIR}" ]; then
  for f in "${RULES_DIR}"/*.md; do
    [ -e "${f}" ] || continue
    cat "${f}"
    printf '\n\n'
  done
else
  printf '# Engineering standards\n\nThe steer rules directory was not found at %s. Reinstall or update the plugin (`/plugin`).\n' "${RULES_DIR}"
  # A vanished rules dir is a steer install defect, not a user error — record it
  # (path-free, stable signature) so surface-faults.sh can offer `/steer:report`.
  [ -n "${CONSUMER_ROOT}" ] && [ ! -d "${CONSUMER_ROOT}/.claude-plugin" ] &&
    steer_record_fault "${CONSUMER_ROOT}" "inject-standards.sh" "rules directory missing — plugin install incomplete or corrupted"
fi
