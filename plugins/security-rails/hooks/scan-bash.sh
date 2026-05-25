#!/usr/bin/env bash
# security-rails: PreToolUse hook for Bash. Blocks (exit 2) commands that
# violate the constitution's "Things Claude must not do" list.
#
# Slim ruleset (post-v0.3):
#   - Force-push to any branch
#   - Direct push to main/master
#   - Direct production database client (psql against a prod-named host)
#
# IaC-apply blocks (terragrunt/tofu/terraform) and prototype-lane PROD_
# env-var blocks were removed with the v0.3 spec revision — infra-coupled,
# return when platform decisions land.

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

# Block force-push to any branch.
if printf '%s' "$cmd" | grep -qE 'git push.*(--force|-f\b)'; then
  block "force-push detected. Force-push is destructive and bypasses review."
fi

# Block direct push to main / master.
if printf '%s' "$cmd" | grep -qE 'git push.*\b(main|master)\b'; then
  block "direct push to main/master. Use a PR — see the constitution."
fi

# Block direct production database commands (Postgres only — psql is the
# guarded client; other clients against a prod-named host are caught by the
# product's own conventions, not this hook).
if printf '%s' "$cmd" | grep -qiE '\bpsql\s+.*\b(prod|production)\b'; then
  block "direct production database client. Production data access must go through audited paths."
fi

exit 0
