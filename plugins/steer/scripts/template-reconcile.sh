#!/usr/bin/env sh
# template-reconcile.sh — read-only structural diff for the *Template
# reconciliation* convention (templates/reference/SPEC-FRAMEWORK.md).
#
# WHAT IT READS
#   $1  existing-file   — a file already in the product repo (e.g. spec/BUILD-STATUS.md)
#   $2  bundled-template — the current bundled template under $CLAUDE_PLUGIN_ROOT
#                          (e.g. "$CLAUDE_PLUGIN_ROOT/templates/spec/build-status.md")
#
# WHAT IT COMPARES
#   Structural anchors only: `##`/`###` headings and `- [ ]` checklist items.
#   Checkbox state is flattened ([x]/[X] -> [ ]) and lines are sorted-unique, so
#   checked-vs-unchecked and ordering never produce a false diff. Line endings
#   are normalized too (CR stripped from BOTH files), so a CRLF file on either
#   side compares by content and never manufactures a phantom gap. Lines carrying
#   the `steer:placeholder` marker are dropped from BOTH files before the diff:
#   those are seed stubs (e.g. the `### Q-001 — [...]` open-question block in a
#   fresh intent) that the dev is meant to fill in and delete the marker from —
#   so a completed file legitimately lacks them and must never be flagged as
#   "missing". It prints the remaining anchors the bundled template has that the
#   existing file lacks — a *candidate* list that may still OVER-REPORT (a
#   reworded item shows as "missing" when it isn't). Open the bundled template
#   and splice with judgment.
#
# WHETHER IT MODIFIES ANYTHING
#   No. It only reads the two files and writes the candidate list to stdout.
#   Neither input is edited, and nothing is written outside stdout/stderr.
#
# EXIT CODES
#   0  ran OK — read stdout: empty means the existing file is current AS TO
#      HEADINGS AND CHECKLIST ITEMS, the only anchors extracted — a template that
#      gained a TABLE ROW yields empty output too, so diff tables by eye;
#      any lines are candidate anchors to splice in. (Gaps-found is signaled via
#      stdout, NOT a nonzero code, so skills running this through a tool's Bash
#      wrapper don't see a normal "gaps found" run reported as a failure.)
#   2  usage error — wrong number of arguments.
#   3  an input file is missing or unreadable.
#
# Usage:
#   sh template-reconcile.sh <existing-file> <bundled-template>

set -u

usage() {
	echo "usage: template-reconcile.sh <existing-file> <bundled-template>" >&2
	exit 2
}

[ "$#" -eq 2 ] || usage
existing=$1
bundled=$2

[ -r "$existing" ] || {
	echo "template-reconcile: cannot read existing file: $existing" >&2
	exit 3
}
[ -r "$bundled" ] || {
	echo "template-reconcile: cannot read bundled template: $bundled" >&2
	exit 3
}

# Extract + normalize structural anchors. `|| true` so a file with zero anchors
# (grep exit 1) doesn't abort the pipeline. Placeholder-marked seed lines
# (`steer:placeholder`) are stripped first so filled-in/deleted stubs never
# surface as a "missing" anchor.
#
# CR is deleted FIRST, before anything else looks at the line. A CRLF file on
# either side would otherwise give every anchor an invisible trailing `\r`, so
# no anchor could ever match its LF counterpart and the bundled template's
# ENTIRE anchor set would be reported as missing — a silent false positive in
# the one step whose contract is "additive, never clobber", and one a caller
# acting on the output would turn into ~100 duplicate spliced sections. Repo
# `.gitattributes` (`* text=auto eol=lf`) keeps CRLF out of the bundled side,
# but the consumer file's endings are not ours to control, so normalize both.
norm() {
	tr -d '\r' <"$1" |
		{ grep -hE '^(#{2,3} |- \[)' || true; } |
		{ grep -v 'steer:placeholder' || true; } |
		sed -E 's/\[[xX]\]/[ ]/' | sort -u
}

tmp_existing=$(mktemp) || {
	echo "template-reconcile: mktemp failed" >&2
	exit 3
}
tmp_bundled=$(mktemp) || {
	rm -f "$tmp_existing"
	echo "template-reconcile: mktemp failed" >&2
	exit 3
}
trap 'rm -f "$tmp_existing" "$tmp_bundled"' EXIT

norm "$existing" >"$tmp_existing"
norm "$bundled" >"$tmp_bundled"

# Anchors present in the bundled template but absent from the existing file.
comm -13 "$tmp_existing" "$tmp_bundled"
exit 0
