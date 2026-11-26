#!/usr/bin/env sh
# steer - infrastructure-as-code checks (OpenTofu/Terraform fmt, Ansible lint).
# Invoked by `mise run ci:iac`.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

ran=0

if steer_ci_has_tf; then
	ran=1
	# Only a ROOT pin makes `tofu` resolve (app-profile repos keep IaC under infra/): skip, don't fail.
	# Run it rather than `command -v`: an unpinned mise shim is on PATH yet errors when invoked.
	if tofu version >/dev/null 2>&1; then
		steer_ci_group 'tofu fmt'
		# Git's file list, not -recursive: a git-ignored vendored dir is not the repo's own code.
		# Dot paths stay out, as tofu's walk left them; core.fsmonitor=false stops ls-files running a repo hook.
		tf="$(git -c core.fsmonitor=false -c core.quotePath=false ls-files --cached --others --exclude-standard -- \
			'*.tf' '*.tofu' '*.tfvars' '*.tftest.hcl' '*.tofutest.hcl' ':(exclude).*' ':(exclude)*/.*')"
		set --
		# -f: a tracked file deleted in the work tree is still listed.
		while IFS= read -r f; do
			if [ -f "${f}" ]; then set -- "$@" "${f}"; fi
		done <<EOF
${tf}
EOF
		if [ "$#" -gt 0 ]; then
			tofu fmt -check -diff "$@"
		else
			printf 'No OpenTofu files found - nothing to format.\n'
		fi
		steer_ci_endgroup
	else
		steer_ci_notice "*.tf/*.hcl present but 'tofu' does not resolve at the repo root (an app-profile repo pins IaC tools under infra/, not root). Skipping the root format check."
	fi
fi

if steer_ci_has_ansible; then
	ran=1
	steer_ci_group 'ansible-lint'
	# Pin uvx tools: unpinned takes today's PyPI latest, and Dependabot cannot see versions inside run: blocks.
	if [ -f .yamllint ] || [ -f .yamllint.yml ] || [ -f .yamllint.yaml ]; then
		# yamllint walks git-ignored dirs: lint only what both its config and git's file list select.
		yaml="$(uvx yamllint@1.38.0 --list-files .)"
		tracked="$(git -c core.fsmonitor=false -c core.quotePath=false ls-files --cached --others --exclude-standard)"
		yaml="$({
			printf '%s\n' "${yaml}" | sed 's|^\./||' | LC_ALL=C sort -u
			printf '%s\n' "${tracked}" | LC_ALL=C sort -u
		} | LC_ALL=C sort | uniq -d)"
		[ -z "${yaml}" ] || printf '%s\n' "${yaml}" | tr '\n' '\000' | xargs -0 uvx yamllint@1.38.0
	fi
	uvx ansible-lint@26.6.0
	steer_ci_endgroup
fi

if [ "${ran}" -eq 0 ]; then
	steer_ci_notice 'No IaC stack detected - nothing to check.'
fi
