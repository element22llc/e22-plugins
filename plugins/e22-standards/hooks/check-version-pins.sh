#!/usr/bin/env sh
# e22-standards PreToolUse hook — version-pin policy (three tiers).
#
# Inspects the *new* content a Write/Edit/MultiEdit introduces for pinned major
# versions of common backing-service / runtime Docker images and applies a
# three-tier policy driven by the endoflife.date API (no version numbers are
# hardcoded, so the hook cannot itself go stale):
#
#   EOL / unsupported            -> DENY   (the pinned cycle's support has ended)
#   supported but behind latest  -> WARN   (advisory additionalContext; allowed)
#   latest supported / newer     -> ALLOW  (silent)
#
# This is NOT a Node-style LTS model — for CPython and friends "supported" means
# the cycle is not past its endoflife.date EOL, and the org baseline for the
# silent-allow tier is the latest supported stable cycle.
#
# F13 — tool-aware: only the introduced content is inspected (Write->content,
# Edit->new_string, MultiEdit->new_strings). old_string is NEVER inspected, so an
# upgrade edit (e.g. bumping a postgres image tag from an older to a newer major)
# is not falsely blocked by the old value. Bash command text is intentionally
# skipped (documented bypass); the CI repo-scan is the stronger backstop for
# committed pins.
#
# Design:
#   - Fail-open everywhere: no network, unknown product, unparseable input -> the
#     write proceeds. This hook must never break a session.
#   - Deliberate older pins: append `# pin-ok: <reason>` on the same line (and
#     record an ADR per the versioning policy) to bypass.
#   - EOL data is cached per slug per UTC day (atomic write; failures are never
#     cached). Set E22_EOL_FIXTURE_DIR=<dir> to read <slug>.json from disk instead
#     of the network (used by the fixture suite; the prod curl path is unchanged).
#   - POSIX sh; jq used when present, else a narrow fallback. Invoked via
#     `sh <script>` from hooks.json.

E22_INPUT="$(cat)"
[ -z "${E22_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"

# Docs legitimately mention old versions -> exempt.
FILE="$(e22_field file_path)"
[ -n "${FILE}" ] && [ "$(e22_classify_path "${FILE}")" = "documentation" ] && exit 0

# F13: inspect only the introduced content (empty for Bash / unknown tools).
CONTENT="$(e22_mutation_content)"
[ -z "${CONTENT}" ] && exit 0

PINS="$(printf '%s' "${CONTENT}" | grep -Eo '(postgres|node|python|redis|valkey|nginx|mysql|mariadb|mongo):[0-9]+(\.[0-9]+)?' | sort -u)"
[ -z "${PINS}" ] && exit 0

# "maj" or "maj.min" -> comparable integer (major*1000 + minor).
ver_num() {
  _maj="${1%%.*}"
  _rest="${1#*.}"
  [ "${_rest}" = "$1" ] && _rest=0
  _min="${_rest%%.*}"
  printf '%d' "$(( _maj * 1000 + _min ))"
}

TODAY="$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"
CACHE_DIR="${TMPDIR:-/tmp}/e22-eol-cache"

# eol_json <slug> — the API response for a product, from (in order) the fixture
# dir, today's cache, or a fresh fetch. Only successful, non-empty responses are
# cached, and the cache write is atomic.
eol_json() {
  _slug="$1"
  if [ -n "${E22_EOL_FIXTURE_DIR}" ]; then
    [ -f "${E22_EOL_FIXTURE_DIR}/${_slug}.json" ] && cat "${E22_EOL_FIXTURE_DIR}/${_slug}.json"
    return
  fi
  _cache="${CACHE_DIR}/${_slug}.${TODAY}.json"
  if [ -s "${_cache}" ]; then
    cat "${_cache}"
    return
  fi
  _resp="$(curl -fsS --max-time 4 "https://endoflife.date/api/${_slug}.json" 2>/dev/null)"
  [ -z "${_resp}" ] && return            # never cache a failure
  mkdir -p "${CACHE_DIR}" 2>/dev/null || true
  if printf '%s' "${_resp}" | head -c 1 | grep -q '\['; then   # looks like JSON
    printf '%s' "${_resp}" > "${_cache}.tmp.$$" 2>/dev/null \
      && mv "${_cache}.tmp.$$" "${_cache}" 2>/dev/null || true
  fi
  printf '%s' "${_resp}"
}

# latest_cycle <json> — newest cycle (first element).
latest_cycle() {
  if e22_have_jq; then
    printf '%s' "$1" | jq -r '.[0].cycle // empty' 2>/dev/null
  else
    printf '%s' "$1" | tr ',' '\n' \
      | sed -n 's/.*"cycle"[[:space:]]*:[[:space:]]*"\{0,1\}\([0-9][0-9.]*\).*/\1/p' \
      | head -n 1
  fi
}

# cycle_eol <json> <cycle> — the eol value for a cycle ("false"/"true"/date/empty).
# Requires jq; without jq returns empty (EOL undetermined -> never hard-deny).
cycle_eol() {
  e22_have_jq || return
  _e="$(printf '%s' "$1" | jq -r --arg c "$2" '.[] | select((.cycle|tostring)==$c) | (.eol|tostring)' 2>/dev/null | head -n 1)"
  printf '%s' "${_e}"
}

DENY="" ; WARN=""
for PIN in ${PINS}; do
  PRODUCT="${PIN%%:*}"
  VERSION="${PIN#*:}"

  # Same-line justification marker -> deliberate pin, allow.
  printf '%s' "${CONTENT}" | grep -E "${PIN}([^0-9.]|\$).*pin-ok" >/dev/null 2>&1 && continue

  case "${PRODUCT}" in
    postgres) SLUG="postgresql" ;;
    node)     SLUG="nodejs" ;;
    mongo)    SLUG="mongodb" ;;
    *)        SLUG="${PRODUCT}" ;;
  esac

  JSON="$(eol_json "${SLUG}")"
  [ -z "${JSON}" ] && continue            # offline / unknown -> fail open

  LATEST="$(latest_cycle "${JSON}")"
  [ -z "${LATEST}" ] && continue

  # eol for the pinned cycle (exact, then major-only).
  EOL="$(cycle_eol "${JSON}" "${VERSION}")"
  [ -z "${EOL}" ] && EOL="$(cycle_eol "${JSON}" "${VERSION%%.*}")"

  # Tier 1 — EOL / unsupported.
  _is_eol=0
  case "${EOL}" in
    true) _is_eol=1 ;;
    false|null|"") _is_eol=0 ;;
    [0-9][0-9][0-9][0-9]-*)
      # ISO dates sort lexically == chronologically. The cycle is past EOL when
      # its date sorts strictly before today. (POSIX `test` has no `<`; some sh
      # implementations accept it, but it is undefined — so compare via sort.)
      if [ "$(printf '%s\n%s\n' "${EOL}" "${TODAY}" | sort | head -n 1)" = "${EOL}" ] \
         && [ "${EOL}" != "${TODAY}" ]; then
        _is_eol=1
      fi
      ;;
  esac
  if [ "${_is_eol}" -eq 1 ]; then
    DENY="${DENY}${PIN} (cycle EOL ${EOL}; current stable: ${LATEST}); "
    continue
  fi

  # Tier 2/3 — behind latest -> advisory; latest or newer -> silent allow.
  PIN_N="$(ver_num "${VERSION}")"
  LATEST_N="$(ver_num "${LATEST}")"
  if [ "${PIN_N}" -lt "${LATEST_N}" ] 2>/dev/null; then
    WARN="${WARN}${PIN} (supported, but current stable is ${LATEST}); "
  fi
done

# Tier 1 dominates: any EOL pin is a hard deny.
if [ -n "${DENY}" ]; then
  REASON="EOL/unsupported version pin(s) — ${DENY}source: endoflife.date. These cycles are past end-of-life; bump to a supported stable. Org standard (/e22-standards:e22-conventions): default to current stable, do not trust training-data memory. If the older pin is deliberate (deploy-target parity, vendor LTS), record an ADR and append ' # pin-ok: <reason>' on the same line, then retry."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "${REASON}"
  exit 0
fi

# Tier 2: advisory only — allow the write, surface a reminder.
if [ -n "${WARN}" ]; then
  CTX="Version-pin advisory — ${WARN}source: endoflife.date. These are still supported but behind the current stable; consider bumping (or record an ADR + ' # pin-ok: <reason>' if the pin is deliberate). Not blocking."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
  exit 0
fi

exit 0
