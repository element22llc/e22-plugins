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

# steer_action_root <cwd> [action_path] — the work-tree root of the thing the tool
# is ACTING ON, falling back to the session cwd's root.
#
# WHY: hooks receive the session cwd, and resolving the root from cwd alone is
# wrong whenever a git repo is nested inside another work tree — a vendored or
# gitignored clone, a tools/ checkout, or a polyrepo member cloned inside its
# workspace. The upward walk from cwd stops at the OUTER repo while the tool
# operates on the INNER one, so every marker read off that root (delivery mode,
# profile, graduation signals, tracker) describes the wrong repo.
#
# Both directions are real and one is silent (#396):
#   - false positive — an outer solo-trunk repo makes the trunk-push gate ask
#     about a push into an inner pr-flow repo, where a branch push is autonomous;
#   - false negative — an outer pr-flow repo makes the gate stay SILENT on a
#     direct-to-main push into an inner solo-trunk repo that has outgrown pre-MVP.
#
# <action_path> is whatever the payload says is being acted on: `tool_input
# .file_path` / `.notebook_path` for an editor write (see steer_target_path in
# lib/json.sh), or the `-C <dir>` target of a git command. Relative paths resolve
# against <cwd>, matching how the tool itself would interpret them.
#
# A path that does not exist yet is the common case, not an edge case — a Write
# creating a new file, possibly in a new directory. Walk up to the nearest
# EXISTING ancestor before resolving, so the new file is attributed to the repo
# that will contain it rather than falling back to cwd.
#
# Fail-soft, and deliberately in the direction of today's behaviour: no path, an
# unresolvable path, or a path outside any work tree all fall back to the cwd
# root, so a single-repo session — the overwhelmingly common case — is unchanged.
# Subprocess-free (`dirname` is avoided in the loop): this runs on the PreToolUse
# hot path.
steer_action_root() {
	_ar_cwd="${1:-.}"
	_ar_path="${2:-}"
	if [ -n "${_ar_path}" ]; then
		case "${_ar_path}" in
		/*) _ar_c="${_ar_path}" ;;
		*) _ar_c="${_ar_cwd}/${_ar_path}" ;;
		esac
		# Walk up to the nearest existing directory. Bounded by construction: each
		# iteration strips one trailing component and stops at "/" or a bare name.
		while [ -n "${_ar_c}" ] && [ ! -d "${_ar_c}" ]; do
			case "${_ar_c}" in
			*/*) _ar_c="${_ar_c%/*}" ;;
			*) _ar_c="" ;;
			esac
			[ -z "${_ar_c}" ] && break
		done
		if [ -n "${_ar_c}" ] && [ -d "${_ar_c}" ]; then
			if _ar_r="$(steer_repo_root "${_ar_c}")"; then
				printf '%s' "${_ar_r}"
				return 0
			fi
		fi
	fi
	steer_repo_root "${_ar_cwd}"
}

# steer_git_c_target <command> — the `-C <dir>` target of a git invocation, or
# nothing when the command carries none. Pairs with steer_action_root so a
# `git -C backend push` is gated against `backend`, not the session cwd.
#
# The trunk-push matcher in check-bash-actions.sh already PARSES `-C <dir>` to
# decide the command is a push; before #396 it then discarded the target and
# resolved from cwd. This extracts what that matcher already recognises.
#
# Pure string scanning, no subprocess. Only the FIRST `git -C` in a compound
# command is returned: a command chaining pushes into two different repos is not
# something a single root can describe, and the caller falls back to cwd rather
# than guessing which one governs.
steer_git_c_target() {
	_gc_rest="$1"
	case "${_gc_rest}" in
	*git*-C*) ;;
	*) return 1 ;;
	esac
	# Advance to the first "-C" that is preceded by whitespace, then take the
	# following whitespace-delimited word.
	while [ -n "${_gc_rest}" ]; do
		case "${_gc_rest}" in
		*" -C "*)
			_gc_rest="${_gc_rest#*" -C "}"
			# Strip any further leading spaces, then cut at the next separator.
			while [ "${_gc_rest#" "}" != "${_gc_rest}" ]; do _gc_rest="${_gc_rest#" "}"; done
			_gc_tgt="${_gc_rest%%[[:space:];&|]*}"
			[ -n "${_gc_tgt}" ] || return 1
			printf '%s' "${_gc_tgt}"
			return 0
			;;
		*) return 1 ;;
		esac
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

# steer_repo_profile <repo_root> — prints the repo's declared profile, read from
# the machine-readable marker on the product CLAUDE.md's `## Profile` section:
#   <!-- steer:profile=infra -->   (or =app / =service / =library / =cli / =workspace)
#
# `workspace` is the polyrepo spine host: a repo that carries the product `/spec`
# and a `spec/workspace.yml` member manifest but no application code of its own. It is
# a scaffold-time profile like the rest; the always-on gate for polyrepo rule text
# is the `has-workspace-manifest` trait in lib/scope.sh, not this marker.
#
# The profile is a SCAFFOLD-TIME concept (it decides what /steer:init lays down);
# always-on rules gate on filesystem traits (has-apps / has-compose / has-infra),
# not on this marker, so the two can never disagree. This reader exists for
# scaffold/sync/report/docs consumers and is a sibling of steer_delivery_mode.
#
# Fail-open: no CLAUDE.md, no marker, or anything unreadable → 'app', which
# preserves the pre-marker behavior (every managed repo was an app monorepo).
# Read once per hook invocation, never per rule.
steer_repo_profile() {
	_cm="${1:-.}/CLAUDE.md"
	[ -f "${_cm}" ] || {
		printf 'app'
		return 0
	}
	# Case-sensitive on purpose: the marker is machine-written lowercase, and the
	# grep character class + the case arms below must agree (a `-i` grep would
	# match `=Infra` then fall through every lowercase arm to the `app` default —
	# a silent misclassification). A mis-cased hand edit is malformed → app.
	_p="$(grep -Eo '^[[:space:]]*<!--[[:space:]]*steer:profile=[a-z]+[[:space:]]*-->' "${_cm}" 2>/dev/null | head -n 1)"
	case "${_p}" in
	*=app*) printf 'app' ;;
	*=infra*) printf 'infra' ;;
	*=service*) printf 'service' ;;
	*=library*) printf 'library' ;;
	*=cli*) printf 'cli' ;;
	*=workspace*) printf 'workspace' ;;
	*) printf 'app' ;;
	esac
}
