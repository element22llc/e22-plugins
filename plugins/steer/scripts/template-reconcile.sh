#!/usr/bin/env sh
# template-reconcile.sh — read-only structural diff for the *Template
# reconciliation* convention (templates/reference/spec-framework.md).
#
# WHAT IT READS
#   $1  existing-file   — a file already in the product repo (e.g. spec/BUILD-STATUS.md)
#   $2  bundled-template — the current bundled template under $CLAUDE_PLUGIN_ROOT
#                          (e.g. "$CLAUDE_PLUGIN_ROOT/templates/spec/build-status.md")
#
# WHAT IT COMPARES
#   Structural anchors only: `##`/`###` headings and `- [ ]` checklist items.
#   Checkbox state is flattened ([x]/[X] -> [ ]) and lines are sorted-unique, so
#   checked-vs-unchecked and ordering never produce a false diff. It prints the
#   anchors the bundled template has that the existing file lacks — a *candidate*
#   list that OVER-REPORTS (a placeholder the dev replaced, or a reworded item,
#   shows as "missing" when it isn't). Open the bundled template and splice with
#   judgment; never re-add a placeholder the dev already filled in.
#
# WHETHER IT MODIFIES ANYTHING
#   No. It only reads the two files and writes the candidate list to stdout.
#   Neither input is edited, and nothing is written outside stdout/stderr.
#
# EXIT CODES
#   0  ran OK — read stdout: empty means the existing file is already current;
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
# (grep exit 1) doesn't abort the pipeline.
norm() {
	{ grep -hE '^(#{2,3} |- \[)' "$1" || true; } | sed -E 's/\[[xX]\]/[ ]/' | sort -u
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
