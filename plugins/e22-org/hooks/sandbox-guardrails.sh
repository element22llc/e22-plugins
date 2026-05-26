#!/usr/bin/env bash
# e22-org: PreToolUse hook. Complements security-rails (which already blocks
# secrets, AWS keys, Stripe live keys, raw-SQL interpolation). This hook covers
# what security-rails does not: real PII patterns and explicit production-DB
# connection strings. Hard-blocks in BOTH zones — spec v0.4 §12 boundary #3
# (no real PII in sandbox) is non-negotiable.

set -uo pipefail

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
content="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); ti=d.get("tool_input",{}); print(ti.get("content") or ti.get("new_string") or "")' 2>/dev/null || true)"

[ -z "$content" ] && exit 0

block() {
  echo "e22-org BLOCKED: $1" >&2
  echo "  File: $file_path" >&2
  [ -n "${2:-}" ] && echo "  Match: $2" >&2
  echo "  See plugins/e22-org/CLAUDE.md → 'Sandbox guardrails'." >&2
  exit 2
}

# 1. US SSN shape: NNN-NN-NNNN with realistic ranges (not all-zeros, not 666-).
if printf '%s' "$content" | grep -qE '(^|[^0-9])(?!000|666|9)[0-9]{3}-(?!00)[0-9]{2}-(?!0000)[0-9]{4}([^0-9]|$)' 2>/dev/null \
   || printf '%s' "$content" | grep -qE '\b[1-8][0-9]{2}-[0-9]{2}-[0-9]{4}\b'; then
  block "looks like a real US Social Security Number. Use a synthetic placeholder (e.g. 000-00-0000)."
fi

# 2. Credit-card-shaped digit runs (13-19 digits in common groupings). Heuristic:
#    require Visa/MC/Amex prefixes to reduce false positives on long numeric IDs.
if printf '%s' "$content" | grep -qE '\b(4[0-9]{3}([- ]?[0-9]{4}){3}|5[1-5][0-9]{2}([- ]?[0-9]{4}){3}|3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5}))\b'; then
  block "looks like a real credit-card number. Use a synthetic placeholder (e.g. 4242 4242 4242 4242)."
fi

# 3. IBAN shape: 2-letter country code + 2 check digits + up to 30 alphanumerics.
if printf '%s' "$content" | grep -qE '\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b'; then
  block "looks like a real IBAN. Use a synthetic placeholder."
fi

# 4. Production-DB connection strings: scheme://user:pass@host... where host
#    contains 'prod' or 'production' as a word segment.
if printf '%s' "$content" | grep -qiE '(postgres|postgresql|mysql|mongodb|redis)://[^/[:space:]]+@[^/[:space:]]*\b(prod|production)\b'; then
  block "production database connection string detected. The sandbox cannot use production DBs (spec v0.4 §12 boundary #2)."
fi

exit 0
