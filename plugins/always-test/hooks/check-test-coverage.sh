#!/usr/bin/env bash
# always-test: PostToolUse hook. When a route handler, page component, or job
# definition is added or modified, check for an adjacent test file.
#
# Lane-scaled (spec §9.10):
#   - prototype lane: soft warning to stderr, exit 0
#   - production lane: block with exit 2
#
# Lane is read from /.workflow/branch.yaml#lane (the authoritative source per
# spec §9.1); falls back to "production" if branch.yaml is missing — strict by
# default.

set -uo pipefail

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0

# Heuristic: file paths that smell like a new endpoint, page, or job.
endpoint_patterns='(api|route|handler|page|screen|view|job|worker|task|endpoint)'

if printf '%s' "$file_path" | grep -qiE "$endpoint_patterns"; then
  # Don't nag about the test file itself.
  case "$file_path" in
    *test*|*spec*|*__tests__*|*.test.*|*.spec.*) exit 0 ;;
  esac

  # Look for an adjacent test file. The product's CLAUDE.md should declare its
  # convention; these are the common defaults across TS/Python repos.
  dir="$(dirname "$file_path")"
  base="$(basename "$file_path" | sed -E 's/\.[a-zA-Z]+$//')"
  found=0
  for candidate in \
    "${dir}/${base}.test.ts" \
    "${dir}/${base}.test.tsx" \
    "${dir}/${base}.spec.ts" \
    "${dir}/${base}.test.py" \
    "${dir}/${base}_test.py" \
    "${dir}/__tests__/${base}.test.ts" \
    "${dir}/__tests__/${base}.test.tsx" \
    "${dir}/tests/test_${base}.py"
  do
    if [ -f "$candidate" ]; then
      found=1
      break
    fi
  done

  if [ "$found" -eq 0 ]; then
    # Read lane from branch.yaml (spec §9.1).
    lane="production"
    if [ -f ".workflow/branch.yaml" ]; then
      lane="$(grep -E '^lane:' .workflow/branch.yaml | head -1 | sed -E 's/^lane:[[:space:]]*//' | tr -d '"' || echo production)"
    fi

    if [ "$lane" = "prototype" ]; then
      echo "always-test (prototype, warn): '$file_path' looks like a new endpoint/screen/job and has no adjacent test. Scaffold at least one smoke test before this turn ends." >&2
      exit 0
    else
      echo "always-test (production, BLOCK): '$file_path' is a new endpoint/screen/job and has no adjacent test." >&2
      echo "  Production lane requires at least one smoke test per artifact (spec §9.10)." >&2
      echo "  Write the test, then re-attempt the edit." >&2
      exit 2
    fi
  fi
fi

exit 0
