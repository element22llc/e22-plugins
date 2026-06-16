# shellcheck shell=sh
# e22-standards hook helper — resolve the repository root from a hook's cwd.
#
# Hooks receive the session cwd, which may be a SUBDIRECTORY of the repo (the
# user cd'd into apps/web, infra, …). Testing for a literal "${CWD}/.git" then
# misses the repo entirely and the hook silently stops applying. Walk UP from cwd
# to the nearest ancestor containing a .git entry — the work-tree root — so spine
# / tracker lookups anchor correctly regardless of cwd depth.
#
# Why an upward walk instead of `git rev-parse`: this runs on the PreToolUse hot
# path (every Write/Edit), so it must be subprocess-free and not assume git is on
# PATH. The walk also handles the cases the reviewer called out:
#   - subdirectories            → walks up to the root,
#   - linked worktrees/submodules → .git is a FILE there; `-e` matches it,
#   - symlinked cwd             → `cd … && pwd -P` canonicalizes the path,
#   - bare repos / outside repo → no .git in any ancestor → non-zero (caller
#                                 exits 0).
#
# e22_repo_root <cwd> — prints the absolute work-tree root and returns 0, or
# prints nothing and returns non-zero when cwd is not inside a work tree.
e22_repo_root() {
	_d="$(CDPATH='' cd -- "${1:-.}" 2>/dev/null && pwd -P)" || return 1
	while [ -n "${_d}" ]; do
		[ -e "${_d}/.git" ] && {
			printf '%s' "${_d}"
			return 0
		}
		[ "${_d}" = "/" ] && break
		_d="$(dirname "${_d}")"
	done
	return 1
}
