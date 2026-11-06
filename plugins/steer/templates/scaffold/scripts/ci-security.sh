#!/usr/bin/env sh
# steer - security gate: HIGH/CRITICAL dependency CVEs (Trivy) and code findings (Semgrep).
# Invoked by `mise run ci:security`. Rationale: /steer:reference conventions -> "Security scanning".
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

if ! steer_ci_has_node && ! steer_ci_has_python; then
	steer_ci_notice 'No Node or Python stack detected - no dependencies or code to scan.'
	exit 0
fi

# --ignore-unfixed: the gate blocks on what the author can act on; a CVE with no
# fix yet stays visible as a Dependabot alert.
set -- fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1
# Trivy loads the YAML ignore file (with expired_at) only when named.
[ -f .trivyignore.yaml ] && set -- "$@" --ignorefile .trivyignore.yaml
steer_ci_group 'trivy fs (dependency CVEs, HIGH/CRITICAL)'
trivy "$@" .
steer_ci_endgroup

steer_ci_group 'semgrep (code findings, ERROR = high)'
semgrep scan --config p/default --severity ERROR --error --metrics off --quiet
steer_ci_endgroup
