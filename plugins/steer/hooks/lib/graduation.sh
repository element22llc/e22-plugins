# shellcheck shell=sh
# (sourced, not executed — no shebang; the directive sets ShellCheck's dialect.)
#
# steer hook helper — local solo-trunk graduation signals.
#
# One detector, two consumers: check-graduation.sh (SessionStart nudge) and
# check-trunk-push.sh (PreToolUse gate on `git push`). Both must agree on what
# "this repo has outgrown solo-trunk" means, so the signal set lives here and
# nowhere else. All signals are LOCAL and offline — filesystem plus (when git is
# available) ref inspection; the networked signal (a second collaborator) stays
# with /steer:audit and /steer:protect, which already use gh.
#
# steer_graduation_signals <repo_root> — prints one markdown bullet per detected
# signal (empty output = no signal) and returns 0. Fail-soft: any ambiguity or a
# missing tool just skips that signal.
steer_graduation_signals() {
	_gr_root="$1"
	_gr_out=""

	# Signal 1 — a prod/production promotion branch exists (local or
	# remote-tracking). Its required-PR-review is the production approval gate, so
	# its existence means the repo has a promotion model that solo-trunk's
	# direct-to-main flow undercuts. git is used only if present — it correctly
	# resolves loose/packed/worktree refs a filesystem peek would miss.
	if command -v git >/dev/null 2>&1; then
		for _gr_ref in refs/heads/prod refs/heads/production \
			refs/remotes/origin/prod refs/remotes/origin/production; do
			if git -C "${_gr_root}" show-ref --verify --quiet "${_gr_ref}" 2>/dev/null; then
				_gr_out="${_gr_out}
- a \`prod\`/\`production\` promotion branch exists"
				break
			fi
		done
	fi

	# Signal 2 — a deploy target is configured. A deploy workflow or an infra/
	# tree means the project ships somewhere; compose.yaml is NOT a signal (the
	# scaffold ships it for local dev). Filesystem-only; the glob guards against
	# no-match.
	for _gr_wf in "${_gr_root}"/.github/workflows/*deploy*.yml "${_gr_root}"/.github/workflows/*deploy*.yaml; do
		if [ -e "${_gr_wf}" ]; then
			_gr_out="${_gr_out}
- a deploy workflow is present (\`.github/workflows/\`)"
			break
		fi
	done
	if [ -d "${_gr_root}/infra" ]; then
		_gr_out="${_gr_out}
- an \`infra/\` tree is present"
	fi

	printf '%s' "${_gr_out}"
}
