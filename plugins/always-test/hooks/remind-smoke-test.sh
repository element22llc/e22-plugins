#!/usr/bin/env bash
# always-test: Stop hook. When Claude is about to end a turn in a GOVERNED
# repo, scan the diff for newly-added endpoint/screen/job files that still
# have no test file, and ask Claude to keep going (exit 2).
#
# Zone-gated: silent in the local MVP sandbox.

set -uo pipefail

source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

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
always-test (governed): the following new/changed files look like endpoints/screens/jobs and have no adjacent test:
$(printf '%b' "$missing" | sed 's/^/  - /')

Scaffold tests before ending the turn per the product's testing strategy — typically unit + integration + smoke. Production CI will fail on coverage delta if these land untested.
EOF
  exit 2
fi

exit 0
