#!/usr/bin/env sh
# steer helper — one-shot, READ-ONLY /spec spine + topology facts.
#
# WHY THIS EXISTS
#   Several skills must know four things before they can route: where the repo
#   root is, what state the /spec spine is in, this repo's role in a polyrepo
#   product, and which repository the tracker declares. Every one of those
#   answers lives in a `hooks/lib/*.sh` helper, and the skills used to reach
#   them by `.`-sourcing those files inline and then calling the functions. A
#   permission rule matches a SINGLE command string, so that compound snippet
#   matched no rule at all — and no grant in this plugin covers a dot-source
#   either. The onboarding front door therefore prompted the user on its very
#   first action (the issue #266 class, on the one surface
#   where a prompt is most expensive). Wrapping the reads in a bundled script
#   makes the call grantable with the established
#   `Bash(sh *scripts/<name>.sh*)` form, and brings it under
#   check_skill_script_grants, which only ever inspected `scripts/` calls.
#
# SCOPE
#   Read-only: writes nothing, mutates nothing, never talks to the network.
#   Structural facts only — it deliberately does NOT compare `spec/.version`
#   against the plugin version (that semver call belongs to /steer:sync and
#   /steer:next) and does NOT resolve this repo's own "owner/name" from the git
#   remote (see the NOTE in hooks/lib/scope.sh: skills resolve that via
#   `gh repo view`, which is correct under URL rewrites and GHE).
#
#   Every field prints explicitly — "none" rather than silence — so an absent
#   value can never be confused with a failed read.
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-spine-state.sh" [repo-root]
#   (defaults to resolving the work-tree root from the current directory)
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq.

set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
. "${PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${PLUGIN_ROOT}/hooks/lib/spine.sh"
. "${PLUGIN_ROOT}/hooks/lib/scope.sh"

ROOT="${1:-}"
IN_WORKTREE=yes
if [ -z "${ROOT}" ]; then
	# Fall back to the current directory rather than printing nothing: a repo that
	# is not yet `git init`ed is a real greenfield case /steer:setup must route,
	# not an error to fail silently on.
	ROOT="$(steer_repo_root ".")" || {
		ROOT="$(CDPATH='' cd -- "." && pwd -P)"
		IN_WORKTREE=no
	}
fi
[ -d "${ROOT}" ] || {
	printf 'scan-spine-state: not a directory: %s\n' "${ROOT}" >&2
	exit 1
}

printf '## Spine state (structural facts only — version drift and repo identity resolved by the caller)\n\n'
printf -- '- root: %s\n' "${ROOT}"
if [ "${IN_WORKTREE}" = no ]; then
	printf -- '- git: not inside a work tree (no .git in any ancestor)\n'
fi
printf -- '- spine: %s\n' "$(steer_spine_state "${ROOT}")"
printf -- '- polyrepo role: %s\n' "$(steer_polyrepo_role "${ROOT}" || printf 'none (single-repo product)')"
printf -- '- tracker repo: %s\n' "$(steer_tracker_repo "${ROOT}" || printf 'none declared')"
