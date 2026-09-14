#!/usr/bin/env sh
# steer — shared stack detection for the `ci:*` mise tasks (sourced, never run).
# Every predicate must stay in lockstep with the plugin's hooks/lib/scope.sh:
# CI and the always-on rules must agree on what stack a repo is, or a rule fires
# for a stack CI never validates.

steer_ci_has_node() {
	[ -f package.json ] || [ -f pnpm-workspace.yaml ]
}

steer_ci_has_python() {
	[ -f pyproject.toml ] || git ls-files '*/pyproject.toml' | grep -q .
}

# A bare roles/ dir is NOT Ansible — it needs playbooks/ beside it (mirrors steer_repo_does_iac).
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
