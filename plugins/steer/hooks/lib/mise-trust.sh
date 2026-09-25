# shellcheck shell=sh
# steer helper - read mise's trust state for ONE directory, shared by
# hooks/check-worktree-trust.sh and scripts/scan-worktrees.sh so the two can never
# disagree about whether a worktree is trusted.
#
# steer_trust_state <dir> - 'trusted' / 'untrusted' / '' (no config there).
# `mise trust --show` lists the directory of every config on the path, ancestors
# included, so the line must be matched on the EXACT directory.
#
# It ABBREVIATES the home directory to `~`, while the dir we are given is absolute
# (steer_repo_root ends in `pwd -P`). Matching only the absolute form never fires
# for a repo under home - which is where worktrees normally live - so the caller
# read '', treated it as "no mise config here", and exited silently: trust was
# never inherited.
#
# mise resolves that home from $HOME when it is set, falling back to the OS home
# when it is not, and it substitutes $HOME LITERALLY - so a trailing slash yields
# `~Documents/...` with no separator. Build both forms it could print (from $HOME as
# given, and from $HOME with trailing slashes trimmed) and compare for EQUALITY
# against either, or against the absolute path.
#
# Equality, never a suffix. Ancestors are listed too, and matching them loosely is
# how an earlier attempt let an ancestor's state stand in for this directory's -
# which at the PRIMARY call site (it branches on `!= trusted`) skipped the
# "no mise config at all, ask the user" notice and CREATED trust, the one thing
# this hook must never do. An ancestor's path can never equal ours, so equality
# closes that by construction rather than by another heuristic.
#
# If $HOME is unset, no abbreviated form is built, nothing matches, and the caller
# gets '' - the hook stays silent and changes nothing. That is the pre-fix
# behaviour and it is the safe direction to fail in.
steer_abbrev_home() { # <dir> <home> - the `~` form mise would print, else <dir>
	[ -n "$2" ] || {
		printf '%s' "$1"
		return 0
	}
	case "$1" in
	"$2") printf '~' ;;
	"$2"/*) printf '~%s' "${1#"$2"}" ;;
	"$2"*) printf '~%s' "${1#"$2"}" ;;
	*) printf '%s' "$1" ;;
	esac
}

steer_trust_state() {
	_home="${HOME:-}"
	_trim="${_home}"
	while :; do
		case "${_trim}" in
		?*/) _trim="${_trim%/}" ;;
		*) break ;;
		esac
	done
	_abbrev="$(steer_abbrev_home "$1" "${_home}")"
	_abbrev2="$(steer_abbrev_home "$1" "${_trim}")"
	mise trust --show -C "$1" 2>/dev/null | while IFS= read -r _line; do
		case "${_line}" in
		"$1: trusted" | "${_abbrev}: trusted" | "${_abbrev2}: trusted")
			printf 'trusted'
			break
			;;
		"$1: untrusted" | "${_abbrev}: untrusted" | "${_abbrev2}: untrusted")
			printf 'untrusted'
			break
			;;
		esac
	done
}
