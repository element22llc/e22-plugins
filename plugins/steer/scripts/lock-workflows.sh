#!/usr/bin/env sh
# lock-workflows.sh - lock the repo's workflow actions in .github/workflows/actions.lock.
#
# Run from the repo root by any skill that writes or changes .github/workflows/
# (scaffold MANIFEST -> "Lock every workflow you install or change"). Extra
# arguments go to `gh actions-lock` (e.g. --relock, --migrate-local-actions).
#
# Installs the pinned gh-actions-lock extension, replacing a different installed
# version so local and CI resolve the same lockfile format. Needs the network.
#
# Exit: 0 locked (or no workflows to lock); 3 gh missing or not signed in; any
# other non-zero is gh actions-lock's own failure, reported on stderr. On non-zero
# the caller must not commit the workflow files.
set -eu

# Bumped by scripts/refresh_template_pins.py; keep equal to ci-lib.sh's copy.
STEER_ACTIONS_LOCK_VERSION=v0.4.1

for f in .github/workflows/*.yml .github/workflows/*.yaml; do
	[ -e "$f" ] && break
	f=''
done
if [ -z "$f" ]; then
	echo "lock-workflows: no workflows under .github/workflows/ - nothing to lock."
	exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "lock-workflows: gh is not installed, so the workflows cannot be locked. Install GitHub CLI (https://cli.github.com), then rerun." >&2
	exit 3
fi
if ! gh auth status >/dev/null 2>&1; then
	echo "lock-workflows: gh is not signed in, so the workflows cannot be locked. Run 'gh auth login', then rerun." >&2
	exit 3
fi

have="$(gh extension list 2>/dev/null | awk -F'\t' '$2 == "github/gh-actions-lock" { print $3 }')"
if [ "${have}" != "${STEER_ACTIONS_LOCK_VERSION}" ]; then
	if [ -n "${have}" ]; then
		echo "lock-workflows: replacing gh-actions-lock ${have} with the pinned ${STEER_ACTIONS_LOCK_VERSION}."
		gh extension remove actions-lock >/dev/null
	fi
	gh extension install github/gh-actions-lock --pin "${STEER_ACTIONS_LOCK_VERSION}"
fi

gh actions-lock "$@"
