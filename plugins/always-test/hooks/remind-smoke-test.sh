#!/usr/bin/env bash
# always-test: Stop hook. When Claude is about to end a turn, scan the diff for
# newly-added endpoint/screen/job files that still have no test file, and ask
# Claude to keep going.
#
# Lane-scaled (spec §9.10):
#   - prototype lane: one happy-path test per artifact
#   - production lane: per-product testing strategy (unit + integration + smoke)
#
# Stop hooks return exit 2 to ask Claude to continue. We do that on both lanes
# when tests are missing — the wording differs.

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
  lane="production"
  if [ -f ".workflow/branch.yaml" ]; then
    lane="$(grep -E '^lane:' .workflow/branch.yaml | head -1 | sed -E 's/^lane:[[:space:]]*//' | tr -d '"' || echo production)"
  fi

  if [ "$lane" = "prototype" ]; then
    cat >&2 <<EOF
always-test (prototype): the following new/changed files look like endpoints/screens/jobs and have no adjacent test:
$(printf '%b' "$missing" | sed 's/^/  - /')

Scaffold at least one happy-path smoke test for each before ending the turn. On the prototype lane one test per artifact is enough; \`/package-handoff\` will refuse to package if any test run failed since the branch was cut (spec §9.10).
EOF
  else
    cat >&2 <<EOF
always-test (production): the following new/changed files look like endpoints/screens/jobs and have no adjacent test:
$(printf '%b' "$missing" | sed 's/^/  - /')

Scaffold tests before ending the turn per the product's testing strategy — typically unit + integration + smoke. Production CI will fail on coverage delta if these land untested (spec §9.10).
EOF
  fi
  exit 2
fi

exit 0
