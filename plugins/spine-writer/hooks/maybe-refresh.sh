#!/usr/bin/env bash
# spine-writer: PostToolUse hook. After a "meaningful" edit (new endpoint,
# schema migration, new screen, dependency change) in a GOVERNED repo, surface
# a reminder to refresh the Spine. We don't auto-invoke the agent here — that
# would be costly and noisy; we let Claude decide whether the change is
# meaningful enough to warrant /spine-refresh.
#
# Zone-gated (spec v0.4 §10.3): no continuous Spine writing during exploration.
# Silent in the local MVP sandbox; nudges only in governed-production repos.
# This hook never blocks.

set -uo pipefail

source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0

meaningful=0
case "$file_path" in
  */routes/*|*/api/*|*/handlers/*) meaningful=1 ;;
  */migrations/*|*schema*) meaningful=1 ;;
  */pages/*|*/screens/*|*/components/*) meaningful=1 ;;
  package.json|pyproject.toml|Cargo.toml|go.mod) meaningful=1 ;;
esac

[ "$meaningful" -eq 0 ] && exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
slug="$(echo "$branch" | sed -E 's|^(proposal|feat|fix)/||')"

if [ -f "proposals/${slug}/product-spine.md" ]; then
  spine_age_minutes=$(( ( $(date +%s) - $(stat -f %m "proposals/${slug}/product-spine.md" 2>/dev/null || stat -c %Y "proposals/${slug}/product-spine.md" 2>/dev/null || echo 0) ) / 60 ))
  if [ "$spine_age_minutes" -gt 60 ]; then
    echo "spine-writer: meaningful change to '$file_path' but proposals/${slug}/product-spine.md is ${spine_age_minutes} minutes stale. Consider running /spine-refresh." >&2
  fi
else
  echo "spine-writer: meaningful change to '$file_path' on branch '${branch}' but no Product Spine exists at proposals/${slug}/product-spine.md. Run /spine-refresh to create one." >&2
fi

exit 0
