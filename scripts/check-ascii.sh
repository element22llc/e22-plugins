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
# per-character naming (scripts/typographic.sh, ~40 shell string matches per
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
# declares `steer:allow-typographic`. Three paths are exempt by name, each
# shipping nothing:
#   CHANGELOG.md, .changes/v*.md - released history, assembled by `changie merge`
#     from fragments this gate already checked; rewriting it would edit releases.
#   presentation/ - the slide decks use emoji as deliberate visual markers.
#
# Run from the repo root::
#
#     sh scripts/check-ascii.sh
#
# Exit 0 when clean, 1 when any tracked file carries a typographic character.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
. "${HERE}/scripts/typographic.sh"

# The rule-85 set as raw UTF-8 bytes: U+00A0/A7/B7, U+00D7/F7; U+2010..U+2015,
# U+2018/19, U+201C/1D, U+2026, U+2022, U+2009, U+202F; U+2139; U+2190/92/94,
# U+21D2/D4; U+2208/12/48/60/61/64/65/86; U+2500..U+257F; U+26A0, U+2705/13/17,
# U+274C/53; U+FE0F; U+1F000..U+1FFFF. Kept in step with the table in
# scripts/typographic.sh, which names them.
PATTERN="$(printf '\302[\240\247\267]|\303[\227\267]|\342\200[\220-\225\230\231\234\235\246\242\211\257]|\342\204\271|\342\206[\220\222\224]|\342\207[\222\224]|\342\210[\210\222]|\342\211[\210\240\241\244\245]|\342\212\206|\342[\224\225]|\342\232\240|\342\234[\205\223\227]|\342\235[\214\223]|\357\270\217|\360\237')"

REPORT="$(mktemp "${TMPDIR:-/tmp}/steer-check-ascii.XXXXXX")"
trap 'rm -f "${REPORT}"' EXIT

cd "${HERE}" || exit 1
git ls-files -z |
	LC_ALL=C xargs -0 grep -lIE -- "${PATTERN}" 2>/dev/null |
	while IFS= read -r rel; do
		[ -f "${rel}" ] || continue
		case "${rel}" in CHANGELOG.md | .changes/v*.md | presentation/*) continue ;; esac
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
