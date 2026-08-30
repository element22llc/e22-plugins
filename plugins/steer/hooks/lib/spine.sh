# shellcheck shell=sh
# steer hook helper — classify a repo's /spec spine state.
#
# A bare `spec/` directory is NOT proof of an spec spine: an empty folder, a
# foreign OpenAPI `spec/`, or a half-migrated spine would all silence the
# bootstrap nudges if we keyed off `[ -d spec ]`. The reliable ownership marker
# is `spec/.version` (written by init / adopt / build; sync re-stamps). The required spine files
# mirror the bundled scaffold + init.
#
# Version-drift routing (a spine OLDER or NEWER than the installed plugin) is
# intentionally NOT decided here — /steer:sync and
# /steer:next own the semver comparison. This helper answers only the
# structural question so the always-on hooks stay fast and dependency-free.
#
# STEER_SPINE_REQUIRED — spine files that must exist for a .version-stamped repo to
# count as complete. Keep in sync with the scaffold and init step 4.
# The action history is NOT in this list: it is a directory (spec/history/) whose
# legacy single-file shape is still valid, so it needs an either-or test rather
# than a file existence check. See the history block in steer_spine_state below.
STEER_SPINE_REQUIRED="vision.md users.md glossary.md tracker.md"

# STEER_SPINE_REQUIRED_MEMBER — the required set for a POLYREPO MEMBER, whose spine
# is partial BY DESIGN: the product-level artifacts live once in the workspace repo,
# so a member carries only the pointer. Without this split a member would report
# `damaged` on every check and /steer:sync would "repair" it by reinstalling the
# very product-level files the topology exists to de-duplicate — recreating the
# split-brain spine. Detected by the presence of spec/PRODUCT.md, inlined here as a
# single file test rather than sourcing lib/scope.sh, so spine.sh keeps its current
# dependency surface (repo-root.sh only) and stays usable on the hook hot path.
STEER_SPINE_REQUIRED_MEMBER="PRODUCT.md"

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
	# This helper is also sourced outside the hooks, by scripts/scan-spine-state.sh
	# and scripts/workspace-snapshot.sh, so it must stay correct under whatever
	# shell runs those — keep the expansion portable rather than relying on the
	# hook runner's `sh`.
	# A polyrepo member's product-level artifacts live in the workspace repo, not
	# here; requiring them would report `damaged` by design. See
	# STEER_SPINE_REQUIRED_MEMBER above.
	if [ -f "${_root}/spec/PRODUCT.md" ]; then
		_rest="${STEER_SPINE_REQUIRED_MEMBER}"
	else
		_rest="${STEER_SPINE_REQUIRED}"
		# Action history: a DIRECTORY of immutable per-entry files (spec/history/).
		# A repo bootstrapped before that shape still carries the single-file
		# spec/HISTORY.md and is carried forward by the /steer:sync ledger entry
		# (MIGRATIONS.md), so EITHER shape counts as present here — reporting
		# `damaged` on every not-yet-migrated repo would fire the repair nudge for
		# a spine that is structurally fine, just older. A migrated repo has both
		# (the frozen archive alongside the directory), which also passes.
		[ -d "${_root}/spec/history" ] || [ -f "${_root}/spec/HISTORY.md" ] || {
			printf 'damaged'
			return 0
		}
	fi
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
