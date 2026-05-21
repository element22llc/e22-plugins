#!/usr/bin/env bash
# always-test: PostToolUse hook. When a route handler, page component, or job
# definition is added or modified, surface a reminder to scaffold a smoke test
# alongside it. We do NOT block — we surface, because the right moment to write
# the test is "next turn", not "before this edit is saved."

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

  # Look for an adjacent test file (rough heuristic — product-specific layouts
  # differ; the product's CLAUDE.md should declare its convention).
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
    echo "always-test: '$file_path' looks like a new endpoint/screen/job and has no adjacent test. Scaffold at least one smoke test before this turn ends." >&2
  fi
fi

exit 0
