#!/usr/bin/env bash
# security-rails: PreToolUse hook for Write/Edit/MultiEdit. Scans the proposed
# content for risky patterns and blocks (exit 2) if any match.
#
# Slim ruleset (post-v0.3): universal blocks only.
#   - Plaintext secrets (keys/tokens adjacent to suspicious labels)
#   - AWS access keys (AKIA…)
#   - Stripe live keys (sk_live_…)
#   - Raw SQL with f-string interpolation
#
# Code-injection patterns (eval, Function ctor, exec, dangerouslySetInnerHTML,
# innerHTML, pickle, os.system, GitHub Actions YAML) are covered by Anthropic's
# security-guidance plugin — a required complement (see CONSTITUTION.md).
#
# Lane-aware production-data blocks (PROD_ env vars, prod hostnames) were
# removed with the v0.3 spec revision; isolation belongs at the infra layer and
# returns when platform decisions land.

set -uo pipefail

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
content="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); ti=d.get("tool_input",{}); print(ti.get("content") or ti.get("new_string") or "")' 2>/dev/null || true)"

[ -z "$content" ] && exit 0

block() {
  echo "security-rails BLOCKED: $1" >&2
  echo "  File: $file_path" >&2
  [ -n "${2:-}" ] && echo "  Match: $2" >&2
  echo "  See CONSTITUTION.md → 'Things Claude must not do'." >&2
  exit 2
}

# 1. Plaintext secrets — keys/tokens longer than 20 chars adjacent to suspicious labels.
if printf '%s' "$content" | grep -qE '(api[_-]?key|secret[_-]?key|access[_-]?token|password|private[_-]?key)["'"'"' :=]+["'"'"']?[A-Za-z0-9/_+=-]{20,}'; then
  block "looks like a plaintext credential. Reference secrets via the product's secret store (declared per-product) instead."
fi

# 2. AWS access key format.
if printf '%s' "$content" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  block "AWS access key pattern detected (AKIA…). Never commit credentials."
fi

# 3. Stripe live keys.
if printf '%s' "$content" | grep -qE 'sk_live_[0-9a-zA-Z]{24,}'; then
  block "Stripe live secret key detected. This is a production credential — never commit it."
fi

# 4. Raw SQL with f-string interpolation (SQL injection risk).
if printf '%s' "$content" | grep -qE '(execute|cursor\.execute|query)\s*\(\s*f["'"'"']'; then
  block "raw SQL with f-string interpolation. Use parameterized queries (execute(sql, params))."
fi

exit 0
