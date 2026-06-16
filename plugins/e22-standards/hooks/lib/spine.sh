# shellcheck shell=sh
# e22-standards hook helper — classify a repo's /spec spine state.
#
# A bare `spec/` directory is NOT proof of an E22 spine: an empty folder, a
# foreign OpenAPI `spec/`, or a half-migrated spine would all silence the
# bootstrap nudges if we keyed off `[ -d spec ]`. The reliable ownership marker
# is `spec/.version` (written by e22-init / e22-adopt). The required spine files
# mirror the bundled scaffold + e22-init.
#
# Version-drift routing (a spine OLDER or NEWER than the installed plugin) is
# intentionally NOT decided here — /e22-standards:e22-sync and
# /e22-standards:e22-next own the semver comparison. This helper answers only the
# structural question so the always-on hooks stay fast and dependency-free.
#
# E22_SPINE_REQUIRED — spine files that must exist for a .version-stamped repo to
# count as complete. Keep in sync with the scaffold and e22-init step 4.
E22_SPINE_REQUIRED="vision.md users.md glossary.md tracker.md HISTORY.md"

# e22_spine_state <repo_root> — prints exactly one of:
#   unmanaged  no spec/ dir                                → bootstrap (init/adopt)
#   foreign    spec/ exists but no spec/.version           → not an E22 spine
#   damaged    spec/.version present but a required file is missing → repair/sync
#   managed    spec/.version + every required file present  → silent
e22_spine_state() {
	_root="${1:-.}"
	[ -d "${_root}/spec" ] || {
		printf 'unmanaged'
		return 0
	}
	[ -f "${_root}/spec/.version" ] || {
		printf 'foreign'
		return 0
	}
	for _f in ${E22_SPINE_REQUIRED}; do
		[ -f "${_root}/spec/${_f}" ] || {
			printf 'damaged'
			return 0
		}
	done
	printf 'managed'
}
