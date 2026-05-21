#!/usr/bin/env bash
# house-style: PostToolUse hook. Run the product's configured linter/formatter on
# the edited file. Lane-aware:
#   prototype/*: surface lint findings as warnings to stderr, exit 0
#   production: exit 2 on lint failures so Claude must fix before continuing
#
# We do not encode the lint tool here — the product's CLAUDE.md should declare it.
# This hook just dispatches on common extensions to common tools, falling back to
# silently passing if no tool is installed.

set -uo pipefail

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
case "$branch" in
  prototype/*) strict=0 ;;
  *)           strict=1 ;;
esac

output=""
rc=0

case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    if command -v biome >/dev/null 2>&1; then
      output="$(biome check --no-errors-on-unmatched "$file_path" 2>&1)" || rc=$?
    elif command -v eslint >/dev/null 2>&1; then
      output="$(eslint "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      output="$(ruff check "$file_path" 2>&1)" || rc=$?
    elif command -v flake8 >/dev/null 2>&1; then
      output="$(flake8 "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.tf)
    if command -v terraform >/dev/null 2>&1; then
      output="$(terraform fmt -check=true -diff=true "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.go)
    if command -v gofmt >/dev/null 2>&1; then
      output="$(gofmt -l "$file_path" 2>&1)" || rc=$?
      [ -n "$output" ] && rc=1
    fi
    ;;
  *)
    exit 0 ;;
esac

if [ "$rc" -ne 0 ]; then
  if [ "$strict" -eq 1 ]; then
    echo "house-style (production lane, strict): lint failed for $file_path" >&2
    [ -n "$output" ] && echo "$output" >&2
    exit 2
  else
    echo "house-style (prototype lane, lenient): lint findings for $file_path — not blocking, but expect to clean these up at /package-handoff" >&2
    [ -n "$output" ] && echo "$output" >&2
    exit 0
  fi
fi

exit 0
