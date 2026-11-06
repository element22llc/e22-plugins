#!/usr/bin/env sh
# steer hook fixture suite - POSIX sh, deterministic (no network, no jq needed).
# Runs every cases/*.sh file in parallel, or only the named ones, and totals
# their pass/fail counts. Run from anywhere:
#
#     sh plugins/steer/hooks/tests/run.sh                      # every case file
#     sh plugins/steer/hooks/tests/run.sh check-bash-actions   # cases/<name>.sh only
#
# Exit 0 when all cases pass, 1 otherwise. A case file sources lib.sh, owns its
# WORK dir, and ends with `finish`; one that dies before it, or writes stderr
# other than its FAIL lines, counts as a failure.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
LOGS="$(mktemp -d "${TMPDIR:-/tmp}/steer-hooktests-run.XXXXXX")"
trap 'rm -rf "${LOGS}"' EXIT

[ $# -gt 0 ] || set -- "${HERE}"/cases/*.sh
NAMES=""
for arg in "$@"; do
	name="$(basename -- "${arg}" .sh)"
	[ -f "${HERE}/cases/${name}.sh" ] || {
		printf 'run.sh: no case file cases/%s.sh\n' "${name}" >&2
		exit 2
	}
	NAMES="${NAMES} ${name}"
	sh "${HERE}/cases/${name}.sh" >"${LOGS}/${name}.out" 2>"${LOGS}/${name}.err" &
done
wait

PASS=0
FAIL=0
for name in ${NAMES}; do
	cat "${LOGS}/${name}.err" >&2
	# Without `set -e` a shell error - an undefined assert_* name, a missing file -
	# returns nonzero and the case runs on to a clean tally, so the error itself is
	# the only trace. Cases write nothing to stderr but their FAIL lines.
	stray="$(grep -v '^FAIL: ' "${LOGS}/${name}.err")"
	if [ -n "${stray}" ]; then
		printf '%s\n' "${stray}" | sed "s/^/FAIL: ${name} wrote to stderr: /" >&2
		FAIL=$((FAIL + 1))
	fi
	tally="$(tail -n 1 "${LOGS}/${name}.out")"
	p="$(printf '%s' "${tally}" | sed -n 's/^\([0-9]*\) passed, \([0-9]*\) failed$/\1/p')"
	n="$(printf '%s' "${tally}" | sed -n 's/^\([0-9]*\) passed, \([0-9]*\) failed$/\2/p')"
	if [ -z "${p}" ]; then
		printf 'FAIL: %s exited before its tally (last line: %s)\n' "${name}" "${tally}" >&2
		FAIL=$((FAIL + 1))
		continue
	fi
	PASS=$((PASS + p))
	FAIL=$((FAIL + n))
done

printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
[ "${FAIL}" -eq 0 ]
