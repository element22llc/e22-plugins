#!/usr/bin/env sh
# steer - security gate: committed secrets (gitleaks), HIGH/CRITICAL dependency CVEs (Trivy) and
# code findings (Semgrep).
# Invoked by `mise run ci:security`. Rationale: /steer:reference conventions -> "Security scanning".
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

# Commits, not the working tree: the git-ignored .env never fails a local run, and a secret
# committed then deleted is still caught. HEAD only - a bare run walks every fetched branch,
# so one unmerged branch would fail everyone's PR. --redact keeps the secret out of the log.
steer_ci_group 'gitleaks (committed secrets, HEAD history)'
gitleaks git --no-banner --redact --log-opts=HEAD .
steer_ci_endgroup

if ! steer_ci_has_node && ! steer_ci_has_python; then
	steer_ci_notice 'No Node or Python stack detected - no dependencies or code to scan beyond secrets.'
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

# Every Semgrep output format and error message can quote the matched source, and
# GitHub's masking misses a wrapped secret: only rule id, path and line reach the log.
# The rule id leads so a PR-controlled path cannot start a `::` workflow command.
findings="$(mktemp)"
trap 'rm -f "${findings}"' EXIT
# dash skips the EXIT trap on a signal, which would leave the matches on disk.
trap 'exit 1' HUP INT TERM
steer_ci_group 'semgrep (code findings, ERROR = high)'
rc=0
semgrep scan --config p/default --severity ERROR --error --metrics off --quiet --json --output "${findings}" >/dev/null 2>&1 || rc=$?
grep -oE '"check_id":"[^"]*","path":"([^"\\]|\\.)*","start":[{]"line":[0-9]+' "${findings}" |
	sed 's/^"check_id":"\([^"]*\)","path":"\(.*\)","start":{"line":\([0-9]*\)$/\1 \2:\3/'
steer_ci_endgroup
case "${rc}" in
0) ;;
127) steer_ci_error "semgrep is not installed: run 'mise install'." ;;
1) steer_ci_error "Semgrep found ERROR-severity code findings, listed above as rule id and path:line. The log withholds the matched source: run 'semgrep scan --config p/default --severity ERROR' locally to see it. Fix each, or waive it with '# nosemgrep: <rule-id>' and a why-comment." ;;
*) steer_ci_error "Semgrep failed (exit ${rc}) before finishing the scan. Its output is withheld because it can quote scanned source: run 'semgrep scan --config p/default' locally to see why." ;;
esac
exit "${rc}"
