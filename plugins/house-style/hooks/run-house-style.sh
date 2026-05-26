#!/usr/bin/env bash
# house-style: PostToolUse hook. Run the product's configured linter/formatter
# on the edited file. Zone-gated (spec v0.4 §11.3): silent in the local MVP
# sandbox — lint nags during exploration are exactly the friction v0.4 removes
# — full enforcement (exit 2 on failure) in governed-production repos.
#
# Tech-stack and latest-stable-version guidance is delivered separately as
# always-loaded instructions in plugins/house-style/CLAUDE.md (loaded in both
# zones so the PO benefits from the team's tech-stack choices during MVP work).
#
# We do not encode the lint tool here — the product's CLAUDE.md should declare
# it. This hook dispatches on common extensions to common tools, falling back
# to silently passing if no tool is installed.

set -uo pipefail

source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

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
  *.tf|*.tofu)
    if command -v tofu >/dev/null 2>&1; then
      output="$(tofu fmt -check=true -diff=true "$file_path" 2>&1)" || rc=$?
    elif command -v terraform >/dev/null 2>&1; then
      output="$(terraform fmt -check=true -diff=true "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.hcl)
    if command -v terragrunt >/dev/null 2>&1; then
      output="$(terragrunt hclfmt --terragrunt-check --terragrunt-diff "$file_path" 2>&1)" || rc=$?
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
  echo "house-style (governed, BLOCK): lint failed for $file_path" >&2
  [ -n "$output" ] && echo "$output" >&2
  exit 2
fi

exit 0
