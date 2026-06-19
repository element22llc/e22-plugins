# shellcheck shell=sh
# (sourced, not executed — no shebang; the directive sets ShellCheck's dialect.)
#
# steer hook helper — record a steer SELF-fault for later upstream reporting.
#
# WHY HOOKS DON'T PHONE HOME
#   Hooks run on the session hot path, may have no network or `gh` auth, and a
#   per-session GitHub write would be slow, fragile, and spammy. So when steer's
#   OWN machinery misbehaves (a rules dir vanished, a sourced lib is missing, a
#   helper script crashed), the hook records a one-line fault to a session-local
#   log instead. surface-faults.sh raises unreported faults at SessionStart, and
#   the always-on self-report rule then offers `/steer:report` — which does the
#   gated, scrubbed, deduped upstream filing with the user in the loop.
#
# LOG SHAPE
#   Per-repo, git-ignored, append-only at  <repo-root>/.claude/steer-faults.log.
#   Records are pipe-delimited:  <plugin-version>|<source>|<signature>
#   <signature> MUST be a stable, path-free, secret-free symptom token — it
#   becomes the dedup fingerprint upstream. Never interpolate cwd, file
#   contents, or user input into it.

# steer_plugin_version — best-effort plugin version (no jq); "unknown" if absent.
steer_plugin_version() {
	_v="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		"${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)"
	[ -n "${_v}" ] && printf '%s' "${_v}" || printf 'unknown'
}

# steer_faults_file <repo-root> — path to the fault log for a repo root.
steer_faults_file() { printf '%s/.claude/steer-faults.log' "$1"; }

# steer_faults_surfaced_file <repo-root> — path to the surfaced-count marker.
steer_faults_surfaced_file() { printf '%s/.claude/steer-faults.surfaced' "$1"; }

# steer_record_fault <repo-root> <source> <signature>
#   Append a fault record, deduped by <source>|<signature> so a recurring fault
#   is recorded (and later surfaced) exactly once. Fail-soft: any error
#   (unresolved root, unwritable dir) is swallowed — recording a fault must never
#   abort the hook that called it.
steer_record_fault() {
	_root="$1"
	_src="$2"
	_sig="$3"
	[ -n "${_root}" ] || return 0
	# Keep the delimiter and newlines out of the free-ish fields.
	_src="$(printf '%s' "${_src}" | tr '|\n' '__')"
	_sig="$(printf '%s' "${_sig}" | tr '|\n' '__')"
	_dir="${_root}/.claude"
	[ -d "${_dir}" ] || mkdir -p "${_dir}" 2>/dev/null || return 0
	_log="${_dir}/steer-faults.log"
	if [ -f "${_log}" ] && grep -qF "|${_src}|${_sig}" "${_log}" 2>/dev/null; then
		return 0
	fi
	printf '%s|%s|%s\n' "$(steer_plugin_version)" "${_src}" "${_sig}" \
		>>"${_log}" 2>/dev/null || return 0
}
