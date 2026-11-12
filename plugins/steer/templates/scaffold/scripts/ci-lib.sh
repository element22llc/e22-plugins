#!/usr/bin/env sh
# steer - shared stack detection for the `ci:*` mise tasks (sourced, never run).
# Every predicate must stay in lockstep with the plugin's hooks/lib/scope.sh:
# CI and the always-on rules must agree on what stack a repo is, or a rule fires
# for a stack CI never validates.

steer_ci_has_node() {
	[ -f package.json ] || [ -f pnpm-workspace.yaml ]
}

steer_ci_has_python() {
	[ -f pyproject.toml ] || git ls-files '*/pyproject.toml' | grep -q .
}

# A bare roles/ dir is NOT Ansible - it needs playbooks/ beside it (mirrors steer_repo_does_iac).
steer_ci_has_ansible() {
	[ -f ansible.cfg ] || [ -f site.yml ] || [ -f site.yaml ] || { [ -d roles ] && [ -d playbooks ]; }
}

steer_ci_has_tf() {
	git ls-files '*.tf' '*.hcl' | grep -q .
}

steer_ci_has_pulumi() {
	[ -f Pulumi.yaml ] || [ -f Pulumi.yml ]
}

# `::notice::`/`::error::` are GitHub annotation syntax; locally they are plain prose.
steer_ci_notice() {
	printf '::notice::%s\n' "$*"
}

steer_ci_error() {
	printf '::error::%s\n' "$*" >&2
}

steer_ci_group() {
	printf '::group::%s\n' "$*"
}

steer_ci_endgroup() {
	printf '::endgroup::\n'
}

# Pinned gh-actions-lock for the online check; scripts/refresh_template_pins.py bumps it.
STEER_ACTIONS_LOCK_VERSION=v0.4.1

# Every action a workflow uses must be locked in .github/workflows/actions.lock, or the
# runner refuses the run at startup with no job log. CI sets STEER_CI_ACTIONS_LOCK=verify
# and checks provenance online; locally an installed extension checks coverage offline.
steer_ci_actions_lock() {
	set -- .github/workflows/*.yml .github/workflows/*.yaml
	[ -e "$1" ] || [ -e "$2" ] || return 0
	if [ "${STEER_CI_ACTIONS_LOCK:-}" = verify ]; then
		if ! gh actions-lock --help >/dev/null 2>&1; then
			gh extension install github/gh-actions-lock --pin "${STEER_ACTIONS_LOCK_VERSION}" || return 1
		fi
		set -- --verify
	elif gh actions-lock --help >/dev/null 2>&1; then
		set -- --verify-local
	else
		steer_ci_notice "gh-actions-lock is not installed, so CI alone checks the actions lockfile. Install it: gh extension install github/gh-actions-lock"
		return 0
	fi
	gh actions-lock "$@" && return 0
	steer_ci_error "The actions lockfile is missing or stale. Run 'gh actions-lock' and commit .github/workflows/actions.lock with the workflow change; never hand-edit it."
	return 1
}

# Resolve the git ref a changed-files gate should diff against, echoing it on
# stdout. Echoes nothing and returns 1 when no base is resolvable - every caller
# must then FAIL OPEN (skip the gate), never fail the build: a gate that cannot
# see the diff has learned nothing, and blocking on that punishes shallow clones
# and first pushes rather than catching a real defect.
steer_ci_base() {
	case "${STEER_CI_EVENT:-local}" in
	pull_request)
		# Resolve locally first: the shipped checkout sets persist-credentials: false,
		# so on a private repo the fetch below cannot authenticate (#707).
		# The PR merge ref's first parent is the base it was computed against - trusted
		# only when its second parent is the PR head, else HEAD^1 may be a merged-in main.
		if [ -n "${STEER_CI_HEAD_SHA:-}" ] &&
			[ "$(git rev-parse --verify --quiet 'HEAD^2' 2>/dev/null)" = "${STEER_CI_HEAD_SHA}" ]; then
			git rev-parse --verify --quiet 'HEAD^1'
			return 0
		fi
		# The event's base SHA can trail a base that moved on: a superset diff, never a miss.
		if [ -n "${STEER_CI_BASE_SHA:-}" ] &&
			git rev-parse --verify --quiet "${STEER_CI_BASE_SHA}^{commit}" >/dev/null 2>&1; then
			printf '%s\n' "${STEER_CI_BASE_SHA}"
			return 0
		fi
		[ -n "${STEER_CI_BASE_REF:-}" ] || return 1
		git fetch --no-tags --quiet origin "${STEER_CI_BASE_REF}" 2>/dev/null || return 1
		printf 'origin/%s\n' "${STEER_CI_BASE_REF}"
		;;
	push)
		# 0000... is git's "no prior commit" sentinel (branch creation / first push).
		case "${STEER_CI_BEFORE:-}" in
		"" | 0000000000000000000000000000000000000000) return 1 ;;
		esac
		# A force-push leaves `before` in no fetched ref.
		git cat-file -e "${STEER_CI_BEFORE}^{commit}" 2>/dev/null || return 1
		printf '%s\n' "${STEER_CI_BEFORE}"
		;;
	*)
		base="${STEER_CI_BASE:-origin/main}"
		git rev-parse --verify --quiet "${base}" >/dev/null 2>&1 || return 1
		printf '%s\n' "${base}"
		;;
	esac
}
