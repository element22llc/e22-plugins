# shellcheck shell=sh
# steer hook helper — classify a repo's /spec spine state.
#
# A bare `spec/` directory is NOT proof of an spec spine: an empty folder, a
# foreign OpenAPI `spec/`, or a half-migrated spine would all silence the
# bootstrap nudges if we keyed off `[ -d spec ]`. The reliable ownership marker
# is `spec/.version` (written by init / adopt). The required spine files
# mirror the bundled scaffold + init.
#
# Version-drift routing (a spine OLDER or NEWER than the installed plugin) is
# intentionally NOT decided here — /steer:sync and
# /steer:next own the semver comparison. This helper answers only the
# structural question so the always-on hooks stay fast and dependency-free.
#
# STEER_SPINE_REQUIRED — spine files that must exist for a .version-stamped repo to
# count as complete. Keep in sync with the scaffold and init step 4.
STEER_SPINE_REQUIRED="vision.md users.md glossary.md tracker.md HISTORY.md"

# steer_spine_state <repo_root> — prints exactly one of:
#   unmanaged  no spec/ dir                                → bootstrap (init/adopt)
#   foreign    spec/ exists but no spec/.version           → not an spec spine
#   damaged    spec/.version present but a required file is missing → repair/sync
#   managed    spec/.version + every required file present  → silent
steer_spine_state() {
	_root="${1:-.}"
	[ -d "${_root}/spec" ] || {
		printf 'unmanaged'
		return 0
	}
	[ -f "${_root}/spec/.version" ] || {
		printf 'foreign'
		return 0
	}
	# Walk the space-separated list by parameter expansion rather than relying
	# on word-splitting of an unquoted `${STEER_SPINE_REQUIRED}`. Field-splitting
	# of unquoted variables is a POSIX-sh behaviour that zsh does NOT perform by
	# default, so a plain `for _f in ${STEER_SPINE_REQUIRED}` iterates once with
	# the whole string under zsh and misclassifies a managed repo as damaged.
	# This helper is sourced by the /steer:setup skill snippet, which the model
	# runs in the host shell (zsh on macOS), so it must be correct there too.
	_rest="${STEER_SPINE_REQUIRED}"
	while [ -n "${_rest}" ]; do
		_f="${_rest%% *}"
		case "${_rest}" in
			*' '*) _rest="${_rest#* }" ;;
			*) _rest="" ;;
		esac
		[ -f "${_root}/spec/${_f}" ] || {
			printf 'damaged'
			return 0
		}
	done
	printf 'managed'
}
