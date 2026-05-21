#!/usr/bin/env bash
# always-test: Stop hook. When Claude is about to end a turn, scan the unstaged
# diff for newly-added endpoint/screen/job files that still have no test file,
# and ask Claude to keep going.

set -uo pipefail

# Find any uncommitted .ts/.tsx/.js/.jsx/.py files added or modified in this session.
changed="$(git diff --name-only --diff-filter=AM 2>/dev/null; git diff --cached --name-only --diff-filter=AM 2>/dev/null)"
[ -z "$changed" ] && exit 0

missing=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *test*|*spec*|*__tests__*|*.test.*|*.spec.*|*.md|*.json|*.yaml|*.yml|*.toml) continue ;;
  esac
  if printf '%s' "$f" | grep -qiE '(api|route|handler|page|screen|view|job|worker|task|endpoint)'; then
    dir="$(dirname "$f")"
    base="$(basename "$f" | sed -E 's/\.[a-zA-Z]+$//')"
    found=0
    for c in "${dir}/${base}.test.ts" "${dir}/${base}.test.tsx" "${dir}/${base}.spec.ts" "${dir}/${base}.test.py" "${dir}/${base}_test.py" "${dir}/__tests__/${base}.test.ts" "${dir}/__tests__/${base}.test.tsx" "${dir}/tests/test_${base}.py"; do
      [ -f "$c" ] && { found=1; break; }
    done
    [ "$found" -eq 0 ] && missing="${missing}${f}\n"
  fi
done <<< "$changed"

if [ -n "$missing" ]; then
  cat >&2 <<EOF
always-test: the following new/changed files look like endpoints/screens/jobs and have no adjacent test:
$(printf '%b' "$missing" | sed 's/^/  - /')

Scaffold at least one smoke test for each before ending the turn. On a prototype branch, one happy-path test is enough; on a production-lane branch, scaffold unit + integration + smoke per the product's testing strategy.
EOF
  # Soft signal — Stop hook can return exit 2 to ask Claude to continue.
  exit 2
fi

exit 0
