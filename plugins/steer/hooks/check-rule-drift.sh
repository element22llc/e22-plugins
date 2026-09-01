#!/usr/bin/env sh
# steer SessionStart check — the deferred repository ruleset is present and current.
#
# WHY THIS EXISTS
#   Claude Code caps a hook's stdout at 10,000 characters, so steer's
#   SessionStart injection carries only the five always-on core rules. The other
#   30 live in the repo as `.claude/rules/steer-*.md` and are injected by Claude
#   Code when a file their `paths:` frontmatter matches is read.
#
#   That makes them **repo-bound, not plugin-bound**: `/plugin update` refreshes
#   the core immediately and does nothing for these. A repo adopted before they
#   shipped, or not synced since a rule changed, runs with most of the standards
#   missing or out of date — and every other signal in the session looks normal.
#   The hook payload at least says "RULESET INCOMPLETE" when it has to drop a
#   rule; there was no equivalent for the half that lives in the repo. This is it.
#
#   It is deliberately ALWAYS-ON rather than a `/steer:sync` finding: a stale
#   install is worst exactly when nobody thinks to run sync.
#
# MECHANISM
#   Delegates every judgement to scripts/scan-rule-drift.sh (read-only) and only
#   formats the result. Silent when the ruleset is current — the common case must
#   cost nothing. Own stdout budget: hook caps are per-hook, not per-event
#   (verified), so this cannot eat into the ruleset payload.
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq. Always exits 0.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN="${HERE%/hooks}"

. "${PLUGIN}/hooks/lib/json.sh"
. "${PLUGIN}/hooks/lib/repo-root.sh"
. "${PLUGIN}/hooks/lib/spine.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null || :)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}" 2>/dev/null)" || exit 0
[ -n "${ROOT}" ] || exit 0

# The plugin's own tree is not a consumer of its own scaffold.
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# An unmanaged repo already gets the onboarding card from check-unmanaged-repo.sh;
# telling it the rules are missing too would be noise about a repo that has not
# opted in yet.
case "$(steer_spine_state "${ROOT}")" in
unmanaged) exit 0 ;;
esac

SCAN="${PLUGIN}/scripts/scan-rule-drift.sh"
[ -f "${SCAN}" ] || exit 0
OUT="$(sh "${SCAN}" "${ROOT}" "${PLUGIN}" 2>/dev/null)" || exit 0

SUMMARY="$(printf '%s\n' "${OUT}" | grep '^SUMMARY	' | head -n 1)"
[ -n "${SUMMARY}" ] || exit 0
COUNTS="$(printf '%s' "${SUMMARY}" | cut -f2)"
DETAIL="$(printf '%s' "${SUMMARY}" | cut -f3)"

# All current → silent.
case "${DETAIL}" in
"0 absent, 0 stale, 0 edited, 0 orphan") exit 0 ;;
esac

n_absent="$(printf '%s\n' "${OUT}" | grep -c '	absent	' || :)"
n_stale="$(printf '%s\n' "${OUT}" | grep -c '	stale	' || :)"
n_edited="$(printf '%s\n' "${OUT}" | grep -c '	edited	' || :)"
n_orphan="$(printf '%s\n' "${OUT}" | grep -c '	orphan	' || :)"

printf '## steer: the path-scoped ruleset in this repo is out of date\n\n'
printf 'Only the always-on core (5 rules) arrives through the SessionStart hook —\n'
printf 'Claude Code caps hook output at 10,000 characters. The other 30 rules live in\n'
printf '`.claude/rules/steer-*.md` **in this repo**, so `/plugin update` does not\n'
printf 'refresh them. Right now **%s** are current.\n\n' "${COUNTS}"

if [ "${n_absent}" -gt 0 ]; then
	printf -- '- **%s not installed** — those standards are not in force in this repo at all:\n' "${n_absent}"
	printf '%s\n' "${OUT}" | grep '	absent	' | cut -f1 | sed 's/^/    - `/;s/$/`/' | head -n 8
	[ "${n_absent}" -gt 8 ] && printf '    - …and %s more\n' "$((n_absent - 8))"
fi
if [ "${n_stale}" -gt 0 ]; then
	printf -- '- **%s stale** — the plugin changed the rule; this repo still has the old text:\n' "${n_stale}"
	printf '%s\n' "${OUT}" | grep '	stale	' | cut -f1 | sed 's/^/    - `/;s/$/`/' | head -n 8
	[ "${n_stale}" -gt 8 ] && printf '    - …and %s more\n' "$((n_stale - 8))"
fi
if [ "${n_edited}" -gt 0 ]; then
	printf -- '- **%s changed since install** — kept as-is; sync shows a diff, never overwrites:\n' "${n_edited}"
	printf '%s\n' "${OUT}" | grep '	edited	' | cut -f1 | sed 's/^/    - `/;s/$/`/' | head -n 8
	[ "${n_edited}" -gt 8 ] && printf '    - …and %s more\n' "$((n_edited - 8))"
fi
if [ "${n_orphan}" -gt 0 ]; then
	printf -- '- **%s orphaned** — no longer shipped by this plugin version:\n' "${n_orphan}"
	printf '%s\n' "${OUT}" | grep '	orphan	' | cut -f1 | sed 's/^/    - `/;s/$/`/' | head -n 8
fi

printf '\nRun **`/steer:sync`** to reconcile. Until then, treat the standards as partial:\n'
printf 'say so if the user asks you to rely on one of the rules listed above.\n'
exit 0
