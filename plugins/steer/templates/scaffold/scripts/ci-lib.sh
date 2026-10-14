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
