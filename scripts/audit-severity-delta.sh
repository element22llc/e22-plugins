#!/bin/sh
# Print the severity ceiling for every path changed since the last release.
#
# The audit's judgment dimensions are scoped to this delta, so this is also the
# answer to "how much surface does this release actually put at risk?" -- and to
# "can anything in this release block the cut at all?", which the trailing line
# answers directly.
set -eu

ref="${1:-}"
if [ -z "$ref" ]; then
	ref="$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null || true)"
fi
if [ -z "$ref" ]; then
	echo "no release tag found; pass a ref explicitly: mise run audit:severity -- <ref>" >&2
	exit 1
fi

echo "severity ceilings for paths changed since ${ref}:"
uv run python scripts/audit_severity.py --changed-since "$ref" --explain
