#!/usr/bin/env sh
# Committed-state ASCII gate for THIS repo (rule 85, "ASCII everywhere").
#
# The shipped write hook (plugins/steer/hooks/check-ascii-writes.sh) deliberately
# exempts the plugin's own source repo, so without this gate the one repo that
# defines the standard would be the one repo not held to it. It also covers the
# hook's documented gap: a Bash heredoc write carries no editor payload, and
# much of this repo's own authoring happens that way.
#
# It reuses the hook's character table (hooks/lib/typographic.sh) rather than
# restating it, so the sweep and the write-time gate can never disagree about
# what counts as a violation.
#
# RAW BYTES ONLY. steer_typographic_names also matches the \uXXXX text spelling,
# which is right on the write path (a host may serialize hook input that way).
# Here it would be wrong: the hook fixtures and the Python tests legitimately
# contain literal backslash-u strings as test data. This gate reads committed
# text, where only the actual character is a violation, so those escapes are
# removed before the scan.
#
# Scope is `git ls-files`, so ignored paths and sibling worktrees are excluded;
# binary and non-text files are skipped. A file that must contain one of these
# characters declares `steer:allow-typographic`.
#
# Run from the repo root::
#
#     sh scripts/check-ascii.sh
#
# Exit 0 when clean, 1 when any tracked file carries a typographic character.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
. "${HERE}/plugins/steer/hooks/lib/typographic.sh"

REPORT="$(mktemp "${TMPDIR:-/tmp}/steer-check-ascii.XXXXXX")"
trap 'rm -f "${REPORT}"' EXIT

# No path in this repo contains a newline, and git quotes anything unusual, so a
# line-oriented read is safe (POSIX sh has no `read -d ''`).
git -C "${HERE}" ls-files | while IFS= read -r rel; do
	f="${HERE}/${rel}"
	[ -f "${f}" ] || continue
	LC_ALL=C grep -Iq . "${f}" 2>/dev/null || continue # binary or empty
	grep -q 'steer:allow-typographic' "${f}" 2>/dev/null && continue
	hits="$(sed 's/\\[uU][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]//g' "${f}" |
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
