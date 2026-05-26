#!/usr/bin/env bash
# always-test: PostToolUse hook. When a route handler, page component, or job
# definition is added or modified in a GOVERNED repo, block with exit 2 if no
# adjacent test file exists.
#
# Zone-gated (spec v0.4 §11.3): silent in the local MVP sandbox; full
# enforcement in governed-production repos. The sandbox does not need a minimum
# test floor (spec v0.4 §10.3).

set -uo pipefail

# Zone gate: silent in sandbox.
source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0

endpoint_patterns='(api|route|handler|page|screen|view|job|worker|task|endpoint)'

if printf '%s' "$file_path" | grep -qiE "$endpoint_patterns"; then
  case "$file_path" in
    *test*|*spec*|*__tests__*|*.test.*|*.spec.*) exit 0 ;;
  esac

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
    echo "always-test (governed, BLOCK): '$file_path' is a new endpoint/screen/job and has no adjacent test." >&2
    echo "  Governed-production repos require at least one smoke test per artifact." >&2
    echo "  Write the test, then re-attempt the edit." >&2
    exit 2
  fi
fi

exit 0
