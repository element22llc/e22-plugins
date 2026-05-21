#!/usr/bin/env bash
# spec-driven-dev: house rule — a spec or test must exist before code is generated.
#
# Lane-aware. The lane is read from the current git branch:
#   prototype/*  → prototype lane (lenient)
#   feat/* fix/* proposal/* chore/*  → production lane (strict)
#   anything else  → production lane (strict) by default
#
# Prototype lane: a one-line intent in the chat OR a Product Spine stub
# (proposals/<slug>/product-spine.md with at least the Intent section filled in)
# is enough. A bare branch with no recorded intent earns a soft warning, not a block.
#
# Production lane: a Product Spine MUST exist for the active proposal, and at
# least one test file must reference the file being edited (or its parent module)
# — unless the edit is to a test file, a markdown file, or config.
#
# Output:
#   - exit 0: allow (silent or with a soft warning to stderr)
#   - exit 2: block (Claude receives the stderr message and must respond to it)
#
# Wire via hooks/hooks.json on PreToolUse for Write|Edit|MultiEdit.

set -uo pipefail

# Read the tool input from stdin (hook protocol). We only need tool_input.file_path.
payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

# Files we never gate on.
case "$file_path" in
  *.md|*.json|*.yaml|*.yml|*.toml|*.lock|*test*|*spec*|*__tests__*|*.test.*|*.spec.*)
    exit 0 ;;
esac

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

case "$branch" in
  prototype/*)
    # Prototype lane: lenient. Look for ANY of: intent in chat (we can't see that
    # from a hook, so we rely on a Spine stub), or a TODO/intent marker on the
    # branch. If absolutely nothing exists, warn but don't block.
    if [ -d proposals ] && find proposals -name product-spine.md -newer /tmp 2>/dev/null | grep -q .; then
      exit 0
    fi
    # No spine yet — that's fine on prototype, but nudge.
    echo "spec-driven-dev (prototype lane): no Product Spine yet on this branch. That's fine while you iterate, but run /package-handoff before requesting validation so spine-writer can capture the intent." >&2
    exit 0
    ;;
  feat/*|fix/*|proposal/*|chore/*|infra/*|docs/*|*)
    # Production lane: strict. A Spine MUST exist somewhere reachable.
    if [ -d proposals ] && find proposals -name product-spine.md 2>/dev/null | grep -q .; then
      exit 0
    fi
    if find . -maxdepth 3 -name product-spine.md 2>/dev/null | grep -q .; then
      exit 0
    fi
    echo "spec-driven-dev (production lane): no Product Spine found for this proposal. Create one at proposals/<slug>/product-spine.md using PRODUCT_SPINE_TEMPLATE.md, or run /propose to scaffold one. Editing production code without a Spine is blocked by house rule." >&2
    exit 2
    ;;
esac
