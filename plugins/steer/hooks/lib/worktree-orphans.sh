# shellcheck shell=sh
# (sourced, not executed - no shebang; the directive sets ShellCheck's dialect.)
#
# steer helper - find the Compose stacks that deleted linked worktrees left
# behind. Read-only. Shared by scripts/scan-worktrees.sh (/steer:setup worktrees)
# and hooks/check-worktree-orphans.sh (the session notice).
#
# worktree-env.sh names a linked worktree's project `<primary>-<worktree>`. A
# project with this primary's prefix is an orphan when either
#   * `docker compose ls` lists it and its config dir is gone, or
#   * only its labelled volumes remain - a `docker:down` already removed the
#     containers, so `compose ls` no longer lists it - and no live worktree of
#     this primary, nor a sibling directory of the primary, carries that name.
# Volumes carry no working-dir label, so the second case matches by name only:
# callers list the names and remove nothing without a human's yes.

# steer_wt_project_name <ident> - the sanitization worktree-env.sh applies.
steer_wt_project_name() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' |
		sed 's/-\{1,\}/-/g;s/^-//;s/-$//'
}

# steer_wt_orphans <primary> - one `<project>\t<config dir, or ->` line per
# orphan. Returns 1 when docker cannot answer (not on PATH, daemon down).
steer_wt_orphans() {
	_wo_primary="$1"
	command -v docker >/dev/null 2>&1 || return 1
	_wo_ls="$(docker compose ls --all --format json 2>/dev/null)" || return 1
	_wo_base="$(basename "${_wo_primary}")"
	_wo_prefix="$(steer_wt_project_name "${_wo_base}")-"
	_wo_parent="$(dirname "${_wo_primary}")"

	_wo_known=" "
	_wo_wts="$(git -C "${_wo_primary}" worktree list --porcelain 2>/dev/null |
		sed -n 's/^worktree //p' | sed '1d')"
	while IFS= read -r _wo_wt; do
		[ -n "${_wo_wt}" ] || continue
		_wo_known="${_wo_known}$(steer_wt_project_name "${_wo_base}-$(basename "${_wo_wt}")") "
	done <<EOF
${_wo_wts}
EOF

	_wo_rows="$(printf '%s' "${_wo_ls}" | tr '{' '\n' |
		sed -n 's/.*"Name":"\([^"]*\)".*"ConfigFiles":"\([^",]*\).*/\1|\2/p')"
	while IFS='|' read -r _wo_name _wo_cfg; do
		[ -n "${_wo_name}" ] && [ -n "${_wo_cfg}" ] || continue
		case "${_wo_name}" in "${_wo_prefix}"?*) ;; *) continue ;; esac
		_wo_known="${_wo_known}${_wo_name} "
		_wo_dir="$(dirname "${_wo_cfg}")"
		[ -d "${_wo_dir}" ] && continue
		printf '%s\t%s\n' "${_wo_name}" "${_wo_dir}"
	done <<EOF
${_wo_rows}
EOF

	_wo_vols="$(docker volume ls --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | sort -u)"
	while IFS= read -r _wo_name; do
		[ -n "${_wo_name}" ] || continue
		case "${_wo_name}" in "${_wo_prefix}"?*) ;; *) continue ;; esac
		case "${_wo_known}" in *" ${_wo_name} "*) continue ;; esac
		[ -d "${_wo_parent}/${_wo_name}" ] && continue
		printf '%s\t-\n' "${_wo_name}"
	done <<EOF
${_wo_vols}
EOF
	return 0
}
