#!/usr/bin/env sh
# steer PostToolUse hook — format the file a Write/Edit just touched.
#
# WHY
#   Formatting drift is the cheapest CI failure there is: the model writes
#   near-formatted code, the CI lint gate rejects it, and a whole push-and-wait
#   round-trip is spent on whitespace. Formatting at the point of mutation —
#   with the repo's OWN formatter, only when the repo actually uses one —
#   removes that loop without introducing any new tool or opinion.
#
# SCOPE (deliberately narrow)
#   • Fires only when the repo has OPTED IN to a formatter this hook knows:
#     a root biome.json/biome.jsonc (biome — the default-stack Node formatter)
#     or a root pyproject.toml (ruff — the default Python formatter). No
#     config → silent no-op; this hook never introduces a formatter.
#   • Formats ONLY the single file the tool just wrote — never a tree sweep.
#   • The formatter binary must already be on PATH (mise-managed repos have it
#     via `mise activate`); a missing binary → silent no-op, never an install.
#   • The plugin's own source repo is exempt (its pre-commit owns formatting).
#
# MECHANISM
#   PostToolUse on Write|Edit|MultiEdit. Best-effort, silent, and always exit
#   0: a formatter error must never fail the hook (the file may legitimately be
#   mid-refactor and unparseable). Emits nothing — the write already happened;
#   there is no decision to influence.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. Fail-open everywhere.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

FILE="$(steer_field file_path)"
[ -n "${FILE}" ] || exit 0

CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Not a git work tree → not a repo we manage. The plugin's own source repo →
# its pre-commit hooks own formatting.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Resolve a relative path against cwd so the existence check and the formatter
# both see the real file.
case "${FILE}" in
/*) TARGET="${FILE}" ;;
*) TARGET="${CWD}/${FILE}" ;;
esac
[ -f "${TARGET}" ] || exit 0

case "${TARGET}" in
*.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs | *.json | *.jsonc | *.css)
	{ [ -f "${ROOT}/biome.json" ] || [ -f "${ROOT}/biome.jsonc" ]; } || exit 0
	command -v biome >/dev/null 2>&1 || exit 0
	biome format --write "${TARGET}" >/dev/null 2>&1 || true
	;;
*.py)
	[ -f "${ROOT}/pyproject.toml" ] || exit 0
	command -v ruff >/dev/null 2>&1 || exit 0
	ruff format "${TARGET}" >/dev/null 2>&1 || true
	;;
esac
exit 0
