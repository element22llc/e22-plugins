#!/usr/bin/env sh
# e22-standards SessionStart hook — plugin freshness check.
#
# WHY THIS EXISTS
#   The standards in this plugin only matter if the consumer is running a current
#   copy. Nothing nudges the user to `/plugin update`, so a repo can silently drift
#   versions behind for weeks. This hook makes "you're out of date" a session-start
#   signal instead of something nobody notices.
#
# MECHANISM
#   Claude Code keeps a real git clone of the marketplace under
#   `<plugins>/marketplaces/<marketplace>` (the installed copy under
#   `<plugins>/cache/...` is NOT a git repo). We compare that clone's checked-out
#   HEAD against the remote default-branch tip via `git ls-remote` — which reuses
#   the user's existing git auth, so it works even though the repo is PRIVATE and a
#   raw https fetch would 404. Everything written to stdout becomes session
#   `additionalContext` (same path as inject-standards.sh / check-template-drift.sh).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   - POSIX sh, no jq, no process substitution.
#   - Fail-SOFT everywhere: unknown layout, no clone, offline, auth failure, or any
#     git error → exit 0 silently. This hook must never block or noise up a session.
#   - SILENT when current: an up-to-date repo gets zero output, and the notice
#     self-clears once `/plugin update` lands (same self-healing shape as the drift
#     hook).
#   - The network call is bounded so it can never hang a session start:
#     `ssh -o ConnectTimeout=4 -o BatchMode=yes` caps the SSH path and
#     `GIT_TERMINAL_PROMPT=0` stops any interactive credential prompt (https path).
#   - Invoked via `sh <script>` from hooks.json, so the executable bit is irrelevant
#     (marketplace install does not chmod).

ROOT="${CLAUDE_PLUGIN_ROOT}"
[ -n "${ROOT}" ] || exit 0

# Derive the marketplace clone from the installed plugin path. Observed layout:
#   <plugins>/cache/<marketplace>/<plugin>/<version>   ← ${CLAUDE_PLUGIN_ROOT}
#   <plugins>/marketplaces/<marketplace>               ← the git clone we want
# If the path doesn't contain /cache/, we don't recognize the layout → fail soft.
case "${ROOT}" in
  */cache/*) ;;
  *) exit 0 ;;
esac
PLUGINS_ROOT="${ROOT%%/cache/*}"      # <plugins>
AFTER="${ROOT#*/cache/}"              # <marketplace>/<plugin>/<version>
MARKETPLACE="${AFTER%%/*}"            # <marketplace>
[ -n "${MARKETPLACE}" ] || exit 0
CLONE="${PLUGINS_ROOT}/marketplaces/${MARKETPLACE}"
[ -d "${CLONE}/.git" ] || exit 0

# Bound the network call; never prompt, never hang.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o ConnectTimeout=4 -o BatchMode=yes"

LOCAL="$(git -C "${CLONE}" rev-parse HEAD 2>/dev/null)"
[ -n "${LOCAL}" ] || exit 0

# ls-remote against the remote's default branch (no hardcoded branch name, no
# object download, no working-tree mutation). Empty result = offline/auth → silent.
REMOTE="$(git -C "${CLONE}" ls-remote origin HEAD 2>/dev/null | head -n 1 | cut -f 1)"
[ -n "${REMOTE}" ] || exit 0

# In sync → say nothing.
[ "${LOCAL}" = "${REMOTE}" ] && exit 0

# Best-effort installed-version read (no jq): first "version" string in plugin.json.
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${ROOT}/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)"
[ -z "${VERSION}" ] && VERSION="unknown"

printf '<!-- e22-standards: plugin update available -->\n'
printf '# ℹ️ Element 22 standards — update available\n\n'
printf 'This repo is running **e22-standards v%s**, but the `%s` marketplace has newer ' "${VERSION}" "${MARKETPLACE}"
printf 'commits on its default branch — your always-on org standards may be stale.\n\n'
printf 'Two steps, **both required** — the update writes the new files to disk but does '
printf 'NOT refresh the rules already loaded into this session:\n\n'
printf '1. `/plugin update e22-standards@%s`  — pull the latest version\n' "${MARKETPLACE}"
printf '2. `/clear` (or start a fresh session)  — reload so the new rules/hooks take effect\n\n'
printf 'If you stop after step 1, this session keeps running the stale standards. '
printf 'This notice clears itself once the update + reload land.\n'
exit 0
