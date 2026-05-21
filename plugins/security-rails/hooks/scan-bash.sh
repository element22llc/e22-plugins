#!/usr/bin/env bash
# security-rails: PreToolUse hook for Bash. Blocks (exit 2) commands that violate
# the constitution's "Things Claude must not do" list.

set -uo pipefail

payload="$(cat || true)"
cmd="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("command",""))' 2>/dev/null || true)"

[ -z "$cmd" ] && exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

block() {
  echo "security-rails BLOCKED Bash command: $1" >&2
  echo "  Command: $cmd" >&2
  echo "  Branch:  $branch" >&2
  echo "  See CONSTITUTION.md → 'Things Claude must not do'." >&2
  exit 2
}

# Block force-push to any branch
if printf '%s' "$cmd" | grep -qE 'git push.*(--force|-f\b)'; then
  block "force-push detected. Force-push is destructive and bypasses review."
fi

# Block direct push to main / master
if printf '%s' "$cmd" | grep -qE 'git push.*\b(main|master)\b'; then
  block "direct push to main/master. Use a PR — see the constitution."
fi

# Block terraform apply outside of CI
if printf '%s' "$cmd" | grep -qE '\bterraform\s+apply\b'; then
  block "terraform apply may only run inside GitHub Actions CI."
fi

# Block direct production database commands
if printf '%s' "$cmd" | grep -qiE '(psql|mysql|mongosh)\s+.*\b(prod|production)\b'; then
  block "direct production database client. Production data access must go through audited paths."
fi

# Prototype-lane: block anything that smells like prod access
case "$branch" in
  prototype/*)
    if printf '%s' "$cmd" | grep -qiE '\b(PROD_|PRODUCTION_)[A-Z_]+\s*=' ; then
      block "setting a production-named env var on a prototype branch violates the Four Guarantees."
    fi
    if printf '%s' "$cmd" | grep -qE 'curl\s+.*\bhttps?://[a-z0-9.-]*\b(prod|production)\.'; then
      block "calling a production endpoint from a prototype branch."
    fi
    ;;
esac

exit 0
