# shellcheck shell=sh
# steer hook helper — resolve the repository root from a hook's cwd.
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
# steer_repo_root <cwd> — prints the absolute work-tree root and returns 0, or
# prints nothing and returns non-zero when cwd is not inside a work tree.
steer_repo_root() {
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

# steer_delivery_mode <repo_root> — prints the repo's declared delivery mode,
# 'solo-trunk' or 'pr-flow', read from the machine-readable marker on the
# product CLAUDE.md's `## Delivery mode` section:
#   <!-- steer:delivery-mode=solo-trunk -->   (or =pr-flow)
#
# Fail-open: no CLAUDE.md, no marker, or anything unreadable → 'pr-flow', which
# preserves the pre-marker behavior (issue-first branch/PR flow). The matcher is
# anchored to the comment line and uses the hyphenated token `=solo-trunk`, so the
# explanatory prose in the default template — which names "solo trunk (pre-MVP)"
# while staying in PR flow — never matches.
steer_delivery_mode() {
	_cm="${1:-.}/CLAUDE.md"
	[ -f "${_cm}" ] || {
		printf 'pr-flow'
		return 0
	}
	if grep -Eiq '^[[:space:]]*<!--[[:space:]]*steer:delivery-mode=solo-trunk[[:space:]]*-->' "${_cm}" 2>/dev/null; then
		printf 'solo-trunk'
		return 0
	fi
	printf 'pr-flow'
}
