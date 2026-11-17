# Worktree fixtures shared by the check-worktree-trust, worktree-teardown and
# scan-worktrees cases: a stubbed `mise` that answers trust queries and logs
# its argv, and wt_pair. Sourced after lib.sh (needs WORK).
# shellcheck shell=sh disable=SC2034  # WT_LOG is read by the sourcing case files

WT_STUBS="${WORK}/wtstubs"
WT_LOG="${WORK}/wtmise.log"
mkdir -p "${WT_STUBS}"
# The stub answers `trust --show -C <dir>` from MISE_STUB_TRUSTED, a
# colon-delimited list of dirs to call trusted; every other queried dir that
# holds a mise.toml is untrusted, and one with no config prints nothing (mise's
# real behaviour: --show lists config directories only). `trust -q -C <dir>`
# just logs, so a case can assert trust was or was not applied.
# It also ABBREVIATES the home dir to `~` on the way out, as real mise does -
# printing the absolute path instead is what let a hook that matched only the
# absolute form pass this suite while being inert on every real repo under home.
# The stub keys that on $HOME because the test controls it; real mise uses $HOME
# when set and the OS home when not, which is why the hook matches structurally
# rather than reconstructing the abbreviation. Case (i) is the regression that pins it.
cat >"${WT_STUBS}/mise" <<'STUB'
#!/bin/sh
printf 'mise %s\n' "$*" >>"${MISE_STUB_LOG:?}"
_dir=""
_show=0
while [ $# -gt 0 ]; do
	case "$1" in
	--show) _show=1 ;;
	-C)
		shift
		_dir="$1"
		;;
	esac
	shift
done
[ "${_show}" -eq 1 ] || exit 0
_state=untrusted
_rest="${MISE_STUB_TRUSTED:-}:"
while [ -n "${_rest}" ]; do
	_one="${_rest%%:*}"
	_rest="${_rest#*:}"
	[ "${_one}" = "${_dir}" ] && _state=trusted
	[ -z "${_rest}" ] && break
done
_out="${_dir}"
case "${HOME:-}" in
"") ;;
*) case "${_dir}" in
	"${HOME}") _out="~" ;;
	"${HOME}"/*) _out="~${_dir#"${HOME}"}" ;;
	esac ;;
esac
# Real mise lists every config directory on the path, ANCESTORS FIRST and the
# queried directory last. MISE_STUB_ANCESTORS is a colon-delimited list of
# already-abbreviated ancestor DIRS (no spaces - run_hook word-splits $ENV), each
# emitted as `<dir>: trusted` before the target line, so a case can pin the
# ordering the matcher has to survive.
_anc="${MISE_STUB_ANCESTORS:-}"
while [ -n "${_anc}" ]; do
	_one="${_anc%%:*}"
	_rest="${_anc#*:}"
	[ -n "${_one}" ] && printf '%s: trusted\n' "${_one}"
	[ "${_rest}" = "${_anc}" ] && break
	_anc="${_rest}"
done
# The queried directory gets a line ONLY if it holds a config - mise lists config
# directories, and its ancestors are listed either way. That asymmetry is what a
# loose matcher turned into "an ancestor's state stands in for this directory's".
[ -f "${_dir}/mise.toml" ] || exit 0
printf '%s: %s\n' "${_out}" "${_state}"
exit 0
STUB
chmod +x "${WT_STUBS}/mise"

# wt_pair <name> - a primary checkout with a mise.toml plus a LINKED worktree of
# it (the `.git` FILE holding the `gitdir:` pointer steer_primary_worktree
# parses, so no real git is needed). Prints "<primary> <worktree>".
wt_pair() {
	_p="${WORK}/$1"
	_w="${_p}/.claude/worktrees/feat-x"
	mkdir -p "${_p}/.git/worktrees/feat-x" "${_w}"
	printf '' >"${_p}/.git/HEAD"
	printf '[env]\n_.source = "scripts/worktree-env.sh"\n' >"${_p}/mise.toml"
	printf '[env]\n_.source = "scripts/worktree-env.sh"\n' >"${_w}/mise.toml"
	printf 'gitdir: %s/.git/worktrees/feat-x\n' "${_p}" >"${_w}/.git"
	printf '%s %s' "${_p}" "${_w}"
}
