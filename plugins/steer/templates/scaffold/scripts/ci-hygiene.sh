#!/usr/bin/env sh
# steer - stack-agnostic CI hygiene: workflow lint, shell lint, version-pin policy.
# Runs in every repo regardless of stack. Invoked by `mise run ci:hygiene`.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

# `if` rather than `pred && stacks=...`: under `set -e` a false predicate as the
# last statement of a list would exit the script.
stacks=''
if steer_ci_has_node; then stacks="${stacks} node"; fi
if steer_ci_has_python; then stacks="${stacks} python"; fi
if steer_ci_has_tf; then stacks="${stacks} terraform"; fi
if steer_ci_has_ansible; then stacks="${stacks} ansible"; fi
if steer_ci_has_pulumi; then stacks="${stacks} pulumi"; fi

if [ -z "${stacks}" ]; then
	steer_ci_notice "No application or infra stack detected (no package.json / pyproject.toml / *.tf / Ansible / Pulumi layout). Stack-agnostic hygiene runs; stack validation is not yet active."
else
	printf 'Detected stack:%s\n' "${stacks}"
fi

if [ -d .github/workflows ]; then
	steer_ci_group 'actionlint'
	actionlint -color
	steer_ci_endgroup
fi

steer_ci_group 'shellcheck'
if [ -n "$(git ls-files '*.sh' '*.bash')" ]; then
	git ls-files '*.sh' '*.bash'
	git ls-files -z '*.sh' '*.bash' | xargs -0 shellcheck
else
	printf 'No shell scripts found - nothing to lint.\n'
fi
steer_ci_endgroup

# Committed-state backstop for the interactive version-pin hook (policy/versions.yml floors).
if [ -f scripts/scan-version-pins.sh ]; then
	steer_ci_group 'version-pin policy'
	sh scripts/scan-version-pins.sh .
	steer_ci_endgroup
fi
