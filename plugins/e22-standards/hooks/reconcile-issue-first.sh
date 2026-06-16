#!/usr/bin/env sh
# e22-standards Stop hook — issue-first working-tree reconciliation (end-of-turn).
#
# WHY THIS EXISTS
#   rule 36-issue-first wants every implementation-affecting mutation tied to a
#   GitHub issue in a GitHub-adopted repo. The PreToolUse nudge
#   (check-issue-before-mutation.sh) catches *editor* writes (Write/Edit/
#   MultiEdit) at the point of action — but it is deliberately blind to Bash:
#   a `cat > src/foo.ts`, `sed -i`, `mv`, or codegen run mutates the repo without
#   ever passing a file_path through PreToolUse, so those changes are invisible to
#   the point-of-action nudge. This hook reconciles the *actual working tree* once
#   the turn ends: if implementation-affecting changes landed on a branch that
#   does not reference a GitHub issue, it surfaces them so the work can be tied to
#   an issue rather than slipping in untracked.
#
# MECHANISM
#   Reports, does not enforce — the mutation already happened; this is post-hoc
#   safety feedback, not a gate (non-goal: a hard block on local edits). Surfaces
#   the concrete governed paths to Claude exactly ONCE per session+repo via a Stop
#   `decision: block` + reason, then self-disarms. Two independent loop guards:
#     1. stop_hook_active=true (the continuation triggered by our own block) → exit.
#     2. a per-session+repo marker in TMPDIR → exit on any later Stop.
#   Silent unless /spec/tracker.md says system: github, silent on an issue-
#   referenced branch, and silent when only exempt paths (spec/docs/generated/
#   lockfile) changed. Shares lib/classify.sh with the PreToolUse nudge so both
#   agree on what counts as implementation-affecting.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. Fail-open everywhere: any ambiguity → exit 0, never
#   block. Honest limitation: a best-effort end-of-turn reconciliation, not a gate.

E22_INPUT="$(cat)"
[ -z "${E22_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"

# Loop guard 1: never re-enter while Claude is already continuing from our block.
printf '%s' "${E22_INPUT}" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

SID="$(e22_field session_id)"
CWD="$(e22_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Not a git repo, or the plugin's own source repo → not our concern.
[ -e "${CWD}/.git" ] || exit 0
[ -d "${CWD}/.claude-plugin" ] && exit 0

# Scoped to GitHub-adopted repos: need /spec/tracker.md declaring system: github.
TRACKER="${CWD}/spec/tracker.md"
[ -f "${TRACKER}" ] || exit 0
grep -iq '^[[:space:]]*system:[[:space:]]*github' "${TRACKER}" 2>/dev/null || exit 0

# Need git to inspect the working tree; fail open if unavailable.
command -v git >/dev/null 2>&1 || exit 0

# On an issue-referenced branch the work is already governed → stay silent.
# Heuristic: an issue number embedded in the branch name (the E22 default is
# issue/<number>-<slug>; also matches PROJ-123, 123-foo, fix/45_x). main/master/
# develop and number-free topic branches do NOT match → they get reconciled.
BRANCH="$(git -C "${CWD}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
printf '%s' "${BRANCH}" | grep -qE '(^|[/_#-])[0-9]+([/_-]|$)' && exit 0

# Changed paths in the working tree (staged, unstaged, untracked). Strip the
# porcelain status prefix and any rename "old -> new" arrow (keep the new path).
CHANGED="$(git -C "${CWD}" status --porcelain 2>/dev/null | sed 's/^...//; s/^.* -> //')"
[ -n "${CHANGED}" ] || exit 0

# Any implementation-affecting (nudge-class) path among the changes? Exempt-only
# turns (spec/docs/generated/lockfile) produce no governed list → stay silent.
GOVERNED=""
_oifs="${IFS}"
IFS='
'
for _path in ${CHANGED}; do
  [ -n "${_path}" ] || continue
  _p="$(printf '%s' "${_path}" | sed 's/^"//; s/"$//')"   # git quotes odd paths
  _cls="$(e22_classify_path "${_p}")"
  if [ "$(e22_class_nudges "${_cls}")" = "nudge" ]; then
    GOVERNED="${GOVERNED}${_p} (${_cls}); "
  fi
done
IFS="${_oifs}"

[ -n "${GOVERNED}" ] || exit 0

# Loop guard 2 / fire-once: at most one advisory per session+repo.
CWD_KEY="$(printf '%s' "${CWD}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/e22-issuefirst-stop.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: > "${MARK}" 2>/dev/null || true

# Single-line, JSON-safe reason (strip quotes/backslashes from dynamic parts, as
# check-issue-before-mutation.sh does). Cap the path list so the message stays short.
SAFE_BRANCH="$(printf '%s' "${BRANCH}" | tr -d '"\\')"
SAFE_LIST="$(printf '%s' "${GOVERNED}" | tr -d '"\\' | cut -c1-400)"

REASON="Element 22 issue-first reconciliation: this GitHub-adopted repo ended the turn with implementation-affecting changes in the working tree on branch '${SAFE_BRANCH}', which does not reference a GitHub issue: ${SAFE_LIST}Issue-first (rule 36) ties every implementation-affecting mutation to a GitHub issue. If this work is intended, capture or reuse an issue and route it through /e22-standards:e22-work (branch like issue/<n>-slug); if it is throwaway, you can disregard this. One-time advisory for this session — it will not repeat and does not block."

printf '{"decision":"block","reason":"%s"}\n' "${REASON}"
exit 0
