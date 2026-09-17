#!/usr/bin/env sh
# steer — infrastructure-as-code checks (OpenTofu/Terraform fmt, Ansible lint).
# Invoked by `mise run ci:iac`.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from —
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

ran=0

if steer_ci_has_tf; then
	ran=1
	# `tofu` is on PATH only when the ROOT toolchain pins it (app-profile repos keep IaC under infra/): skip, don't fail.
	if command -v tofu >/dev/null 2>&1; then
		steer_ci_group 'tofu fmt'
		tofu fmt -check -recursive -diff
		steer_ci_endgroup
	else
		steer_ci_notice "*.tf/*.hcl present but 'tofu' is not on PATH at the repo root (an app-profile repo pins IaC tools under infra/, not root). Skipping the root format check."
	fi
fi

if steer_ci_has_ansible; then
	ran=1
	steer_ci_group 'ansible-lint'
	# Pin uvx tools: unpinned takes today's PyPI latest, and Dependabot cannot see versions inside run: blocks.
	if ls .yamllint .yamllint.yml .yamllint.yaml >/dev/null 2>&1; then
		uvx yamllint@1.38.0 .
	fi
	uvx ansible-lint@26.6.0
	steer_ci_endgroup
fi

if [ "${ran}" -eq 0 ]; then
	steer_ci_notice 'No IaC stack detected - nothing to check.'
fi
