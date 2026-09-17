#!/usr/bin/env sh
# Committed-state ASCII gate for THIS repo (rule 85, "ASCII everywhere").
#
# The shipped write hook (plugins/steer/hooks/check-ascii-writes.sh) deliberately
# exempts the plugin's own source repo, so without this gate the one repo that
# defines the standard would be the one repo not held to it. It also covers the
# hook's documented gap: a Bash heredoc write carries no editor payload, and
# much of this repo's own authoring happens that way.
#
# TWO PASSES, because this runs in the fast pre-commit tier. A single LC_ALL=C
# grep over every tracked file finds the offending FILES in one process; the
# per-character naming (hooks/lib/typographic.sh, ~40 shell string matches per
# file) then runs only for the few that actually hit. Naming every file instead
# took 24 seconds on this repo, which is most of the fast gate's budget for a
# check that is almost always a no-op.
#
# RAW BYTES ONLY, by construction: the bulk pattern below matches the characters
# themselves, never the `\uXXXX` text spelling. That spelling is a violation on
# the write path (a host may serialize hook input that way) but not in committed
# text, where the hook fixtures and Python tests legitimately carry literal
# backslash-u strings as test data. The naming pass strips those escapes so a
# reported file cannot pick up a spurious second character.
#
# Scope is `git ls-files`, so ignored paths and sibling worktrees are excluded;
# `grep -I` skips binary files. A file that must contain one of these characters
# declares `steer:allow-typographic`.
#
# Run from the repo root::
#
#     sh scripts/check-ascii.sh
#
# Exit 0 when clean, 1 when any tracked file carries a typographic character.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
. "${HERE}/plugins/steer/hooks/lib/typographic.sh"

# The rule-85 set as raw UTF-8 bytes: U+00A0; U+2010..U+2015, U+2018/19,
# U+201C/1D, U+2026, U+2022, U+2009, U+202F; U+2190/92/94; U+21D2. Kept in step
# with the table in hooks/lib/typographic.sh, which names them.
PATTERN="$(printf '\302\240|\342\200[\220-\225\230\231\234\235\246\242\211\257]|\342\206[\220\222\224]|\342\207\222')"

REPORT="$(mktemp "${TMPDIR:-/tmp}/steer-check-ascii.XXXXXX")"
trap 'rm -f "${REPORT}"' EXIT

cd "${HERE}" || exit 1
git ls-files -z |
	LC_ALL=C xargs -0 grep -lIE -- "${PATTERN}" 2>/dev/null |
	while IFS= read -r rel; do
		[ -f "${rel}" ] || continue
		grep -q 'steer:allow-typographic' "${rel}" 2>/dev/null && continue
		hits="$(sed 's/\\[uU][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]//g' "${rel}" |
			steer_typographic_names)"
		[ -n "${hits}" ] || continue
		printf '%s: %s\n' "${rel}" "${hits}" >>"${REPORT}"
	done

if [ -s "${REPORT}" ]; then
	cat "${REPORT}" >&2
	printf 'check-ascii: %s file(s) carry typographic characters (rule 85). Use - ... -> and straight quotes, or declare steer:allow-typographic.\n' \
		"$(wc -l <"${REPORT}" | tr -d ' ')" >&2
	exit 1
fi

printf 'check-ascii: OK\n'
