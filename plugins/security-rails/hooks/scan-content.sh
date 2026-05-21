#!/usr/bin/env bash
# security-rails: PreToolUse hook for Write/Edit/MultiEdit. Scans the proposed
# content for risky patterns. Blocks (exit 2) on any of:
#
#   - Plaintext secrets (long base64-like strings adjacent to "secret"/"token"/"key")
#   - Production hostnames (configured per-product in security-rails.config)
#   - Raw SQL with string interpolation (`f"... {var} ..."` style)
#   - On prototype/* branches: production-credential patterns (PROD_*, *_PROD_*,
#     stripe live keys, etc.) — these are blocked on prototype branches regardless.
#
# Soft-warns on prototype branches for things that are only blocked in production
# (e.g. lint smells, console.log left in committed code).

set -uo pipefail

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
content="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); ti=d.get("tool_input",{}); print(ti.get("content") or ti.get("new_string") or "")' 2>/dev/null || true)"

[ -z "$content" ] && exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
case "$branch" in
  prototype/*) lane="prototype" ;;
  *)           lane="production" ;;
esac

block() {
  echo "security-rails BLOCKED: $1" >&2
  echo "  File: $file_path" >&2
  echo "  Lane: $lane" >&2
  [ -n "${2:-}" ] && echo "  Match: $2" >&2
  echo "  See CONSTITUTION.md → 'Things Claude must not do'." >&2
  exit 2
}

# Universal blocks — apply in BOTH lanes.

# 1. Plaintext secrets — keys/tokens longer than 32 chars adjacent to suspicious labels.
if printf '%s' "$content" | grep -qE '(api[_-]?key|secret[_-]?key|access[_-]?token|password|private[_-]?key)["'"'"' :=]+["'"'"']?[A-Za-z0-9/_+=-]{20,}'; then
  block "looks like a plaintext credential. Reference secrets via AWS Secrets Manager or SSM Parameter Store names instead."
fi

# 2. AWS access key format
if printf '%s' "$content" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  block "AWS access key pattern detected (AKIA…). Never commit credentials."
fi

# 3. Stripe live keys
if printf '%s' "$content" | grep -qE 'sk_live_[0-9a-zA-Z]{24,}'; then
  block "Stripe live secret key detected. This is a production credential — never commit it."
fi

# 4. Raw SQL with f-string interpolation (SQL injection risk)
if printf '%s' "$content" | grep -qE '(execute|cursor\.execute|query)\s*\(\s*f["'"'"']'; then
  block "raw SQL with f-string interpolation. Use parameterized queries (execute(sql, params)) — see CONSTITUTION.md."
fi

# Prototype-lane specific: NO prod-shaped credentials, NO prod hostnames.
if [ "$lane" = "prototype" ]; then
  if printf '%s' "$content" | grep -qiE '(PROD_|_PROD_|PRODUCTION_)(API|DB|DATABASE|AUTH|TOKEN|KEY|URL|HOST)'; then
    block "production-named credential on a prototype branch. The Four Guarantees forbid prototype access to prod credentials."
  fi
  if printf '%s' "$content" | grep -qiE 'https?://[a-z0-9.-]*\b(prod|production)\.[a-z0-9.-]+'; then
    block "production hostname referenced on a prototype branch. Use sandbox/staging URLs only."
  fi
fi

exit 0
