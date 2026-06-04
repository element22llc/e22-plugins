#!/usr/bin/env sh
# e22-standards PreToolUse hook — version-pin verification.
#
# Blocks Write/Edit/Bash tool calls that pin a stale major for common backing-
# service / runtime Docker images (e.g. postgres:16 when current stable is 18).
# "Current stable" comes from the endoflife.date API, queried at write time —
# the hook hardcodes no version numbers, so it cannot itself go stale.
#
# Why this exists: the prose rule ("default to current stable, don't trust
# training-data memory") fails in practice because the model is *confidently*
# stale, not unsure — so the "if unsure, ask" escape hatch never fires. This
# hook enforces the procedure mechanically.
#
# Design notes:
#   - Fail-open everywhere: no network, unknown product, unparseable input →
#     exit 0 and let the write proceed. This hook must never break a session.
#   - Deliberate older pins are allowed: append `# pin-ok: <reason>` on the
#     same line (and record an ADR per the versioning policy).
#   - Major-only tags (postgres:18) float the minor; only majors are compared.
#     maj.min pins (python:3.11) are compared at maj.min granularity.
#   - Markdown/text files are exempt — prose legitimately mentions old versions.
#   - POSIX sh, no jq: tool_input arrives as JSON on stdin; image tags survive
#     JSON encoding verbatim, so pattern-grep is sufficient.
#   - Invoked via `sh <script>` from hooks.json, so the executable bit is
#     irrelevant (marketplace install does not chmod).

INPUT="$(cat)"
[ -z "${INPUT}" ] && exit 0

# Docs are exempt — changelogs/ADRs legitimately reference old versions.
printf '%s' "${INPUT}" | grep -E '"file_path"[[:space:]]*:[[:space:]]*"[^"]*\.(md|mdx|txt)"' >/dev/null 2>&1 && exit 0

# Turn escaped newlines into real ones so a pin and its same-line `pin-ok`
# marker can be matched line-wise.
CONTENT="$(printf '%s' "${INPUT}" | sed 's/\\n/\
/g')"

# Image-style version pins we police.
PINS="$(printf '%s' "${CONTENT}" | grep -Eo '(postgres|node|python|redis|valkey|nginx|mysql|mariadb|mongo):[0-9]+(\.[0-9]+)?' | sort -u)"
[ -z "${PINS}" ] && exit 0

# "maj" or "maj.min" → comparable integer (major*1000 + minor).
ver_num() {
  _maj="${1%%.*}"
  _rest="${1#*.}"
  [ "${_rest}" = "$1" ] && _rest=0
  _min="${_rest%%.*}"
  printf '%d' "$(( _maj * 1000 + _min ))"
}

STALE=""
for PIN in ${PINS}; do
  PRODUCT="${PIN%%:*}"
  VERSION="${PIN#*:}"

  # Same-line justification marker → deliberate pin, allow.
  printf '%s' "${CONTENT}" | grep -E "${PIN}[^0-9.].*pin-ok" >/dev/null 2>&1 && continue

  # Docker image name → endoflife.date product slug.
  case "${PRODUCT}" in
    postgres) EOL_SLUG="postgresql" ;;
    node)     EOL_SLUG="nodejs" ;;
    mongo)    EOL_SLUG="mongodb" ;;
    *)        EOL_SLUG="${PRODUCT}" ;;
  esac

  # Newest cycle is first in the API response.
  LATEST="$(curl -fsS --max-time 4 "https://endoflife.date/api/${EOL_SLUG}.json" 2>/dev/null \
    | tr ',' '\n' \
    | sed -n 's/.*"cycle"[[:space:]]*:[[:space:]]*"\{0,1\}\([0-9][0-9.]*\).*/\1/p' \
    | head -n 1)"
  [ -z "${LATEST}" ] && continue # offline / unknown product → fail open

  case "${VERSION}" in
    *.*) PIN_N="$(ver_num "${VERSION}")" ; LATEST_N="$(ver_num "${LATEST}")" ;;
    *)   PIN_N="${VERSION}"              ; LATEST_N="${LATEST%%.*}" ;;
  esac
  [ "${PIN_N}" -lt "${LATEST_N}" ] || continue

  STALE="${STALE}${PIN} (current stable: ${LATEST}); "
done

[ -z "${STALE}" ] && exit 0

REASON="Stale version pin(s) detected — ${STALE}source: endoflife.date, checked just now. Org standard (run /e22-conventions): default to current stable and do not trust training-data memory for versions. Either bump to current stable, or — if the older pin is deliberate (deploy-target parity, LTS policy) — record an ADR and append ' # pin-ok: <reason>' on the same line, then retry."
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "${REASON}"
exit 0
