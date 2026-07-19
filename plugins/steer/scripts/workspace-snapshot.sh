#!/usr/bin/env sh
# steer helper — one-shot, READ-ONLY workspace snapshot (local dimensions).
#
# WHY THIS EXISTS
#   /steer:next reconstructs the whole workspace state cold on every run. Done
#   manually that is a dozen separate tool calls (git status, git branch, a
#   Read per intent.md, a sweep for ADRs, work claims, version drift, …), each
#   a model round-trip (PLAN.md Phase 1 item 5). This script gathers every
#   LOCAL dimension of that reconstruction in a single call and prints a
#   compact, sectioned summary the model reads once.
#
# SCOPE
#   Local state only — git, the /spec spine, features, open questions, ADRs,
#   work claims, build/adoption markers, and the declared tracker SYSTEM. It
#   never talks to the network: live PR/CI state stays with `gh` reads and
#   live issue state stays with /steer:tracker-sync (the skill fetches those
#   separately, batched). Read-only: writes nothing, mutates nothing.
#
#   Every dimension prints explicitly — "none" rather than silence — matching
#   /steer:next's rule that silence must never read as "nothing there".
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/workspace-snapshot.sh" [repo-root]
#   (defaults to resolving the work-tree root from the current directory)
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq.

set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}"
. "${PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${PLUGIN_ROOT}/hooks/lib/spine.sh"

ROOT="${1:-}"
if [ -z "${ROOT}" ]; then
	ROOT="$(steer_repo_root ".")" || ROOT="."
fi
[ -d "${ROOT}" ] || {
	printf 'workspace-snapshot: not a directory: %s\n' "${ROOT}" >&2
	exit 1
}

printf '## Workspace snapshot (local state only — live PR/CI and tracker state fetched separately)\n\n'
printf -- '- root: %s\n' "${ROOT}"

# --- git -----------------------------------------------------------------
printf '\n### Git\n'
if git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	_branch="$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
	_head="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || printf 'none')"
	printf -- '- branch: %s (HEAD %s)\n' "${_branch}" "${_head}"
	_ab="$(git -C "${ROOT}" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)" &&
		printf -- '- upstream: behind %s / ahead %s\n' "${_ab%%	*}" "${_ab##*	}" ||
		printf -- '- upstream: none\n'
	_staged="$(git -C "${ROOT}" diff --cached --name-only 2>/dev/null | grep -c '' || :)"
	_unstaged="$(git -C "${ROOT}" diff --name-only 2>/dev/null | grep -c '' || :)"
	_untracked="$(git -C "${ROOT}" ls-files --others --exclude-standard 2>/dev/null | grep -c '' || :)"
	printf -- '- working tree: %s staged, %s unstaged, %s untracked\n' \
		"${_staged}" "${_unstaged}" "${_untracked}"
else
	printf -- '- not a git repository\n'
fi

# --- spine + version drift ------------------------------------------------
printf '\n### Spine\n'
printf -- '- state: %s\n' "$(steer_spine_state "${ROOT}")"
_spec_ver="$(head -1 "${ROOT}/spec/.version" 2>/dev/null || printf 'none')"
_plug_ver="$(sed -n 's/.*"version"[^"]*"\([^"]*\)".*/\1/p' \
	"${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
printf -- '- spec/.version: %s (plugin: %s)\n' "${_spec_ver}" "${_plug_ver:-unknown}"

# --- features ---------------------------------------------------------------
printf '\n### Features (spec/features/*/intent.md)\n'
_found=0
for _intent in "${ROOT}"/spec/features/*/intent.md; do
	[ -f "${_intent}" ] || continue
	_found=1
	_id="$(basename "$(dirname "${_intent}")")"
	_status="$(sed -n 's/^> *Status: *//p' "${_intent}" | head -1)"
	_contract="no"
	[ -f "$(dirname "${_intent}")/contract.md" ] && _contract="yes"
	_qn="$(grep -c '^### Q-' "${_intent}" 2>/dev/null || :)"
	printf -- '- %s: status=%s contract=%s question-headings=%s\n' \
		"${_id}" "${_status:-unknown}" "${_contract}" "${_qn}"
done
[ "${_found}" -eq 1 ] || printf -- '- none\n'

# --- open questions (detail, placeholder seeds excluded) ---------------------
printf '\n### Open questions (### Q-NNN entries; template placeholders excluded)\n'
_qfound=0
for _qf in "${ROOT}"/spec/vision.md "${ROOT}"/spec/features/*/intent.md; do
	[ -f "${_qf}" ] || continue
	_qout="$(awk '
		/^### Q-/ {
			if ($0 ~ /steer:placeholder/) { inq = 0; next }
			inq = 1; print "  " $0; next
		}
		/^#/ { inq = 0 }
		inq && /^[-*] *(status|impact|required_before|owner):/ { print "    " $0 }
	' "${_qf}" 2>/dev/null)"
	if [ -n "${_qout}" ]; then
		_qfound=1
		printf -- '- %s\n%s\n' "${_qf#"${ROOT}"/}" "${_qout}"
	fi
done
[ "${_qfound}" -eq 1 ] || printf -- '- none\n'

# --- decisions ----------------------------------------------------------------
printf '\n### Decisions (spec/decisions/)\n'
_dfound=0
for _adr in "${ROOT}"/spec/decisions/[0-9]*.md; do
	[ -f "${_adr}" ] || continue
	_dfound=1
	_dstatus="$(sed -n 's/^- \*\*Status:\*\* *//p' "${_adr}" | head -1)"
	printf -- '- %s: %s\n' "$(basename "${_adr}")" "${_dstatus:-unknown}"
done
[ "${_dfound}" -eq 1 ] || printf -- '- none\n'

# --- work claims ------------------------------------------------------------
printf '\n### Work claims (spec/.work/)\n'
_wfound=0
for _wm in "${ROOT}"/spec/.work/*; do
	[ -e "${_wm}" ] || continue
	_wfound=1
	_wdetail="$(grep '^- \(issue\|branch\):' "${_wm}" 2>/dev/null | tr '\n' ' ')"
	printf -- '- %s %s\n' "$(basename "${_wm}")" "${_wdetail}"
done
[ "${_wfound}" -eq 1 ] || printf -- '- none\n'

# --- PO build / adoption ------------------------------------------------------
printf '\n### Build & adoption markers\n'
if [ -f "${ROOT}/spec/BUILD-STATUS.md" ]; then
	_open="$(grep -c '^- \[ \]' "${ROOT}/spec/BUILD-STATUS.md" 2>/dev/null || :)"
	printf -- '- BUILD-STATUS.md: present (%s open handoff box(es))\n' "${_open}"
else
	printf -- '- BUILD-STATUS.md: none\n'
fi
if [ -f "${ROOT}/spec/PRODUCTIONIZATION.md" ]; then
	_life="$(sed -n 's/^> *Lifecycle: *//p' "${ROOT}/spec/PRODUCTIONIZATION.md" | head -1)"
	printf -- '- PRODUCTIONIZATION.md: %s\n' "${_life:-present (no Lifecycle line)}"
else
	printf -- '- PRODUCTIONIZATION.md: none\n'
fi

# --- tracker (declared system only — never live state) -------------------------
printf '\n### Tracker\n'
_tsys="$(sed -n 's/^system: *//p' "${ROOT}/spec/tracker.md" 2>/dev/null | head -1)"
printf -- '- system: %s (live issue state via /steer:tracker-sync, not this script)\n' \
	"${_tsys:-none declared}"

exit 0
