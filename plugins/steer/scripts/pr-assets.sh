#!/usr/bin/env sh
# steer helper - host PR images (the `/steer:work qa` before/after screenshots)
# on a hidden ref, refs/steer-assets/<key>, and print a URL per file that renders
# in a PR body for signed-in reviewers of a private repo (spike: issue #1006).
# github.com URLs render there; raw.githubusercontent and repo-relative paths do
# not. The SHA pin keeps URLs already posted working after a re-run. A
# non-branch ref is never fetched by a default clone and never enters the
# default branch's history.
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/pr-assets.sh" [--remote <name>] <repo-url> <key> <file>...
#   <repo-url> is the repo's web URL, https://<host>/<owner>/<repo> (`gh repo
#   view --json url`, or the PR URL's prefix) - never derived from the remote,
#   whose URL may be an SSH host alias. <key> is the work branch name. Prints
#   `<file-name><TAB><url>` per file. A re-run on the same key commits on top of
#   the last one, so URLs already posted keep resolving.
#   Prune: git push <remote> --delete refs/steer-assets/<key>
#
# EXIT  0 pushed | 2 usage | 5 git failed
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq.

set -u

die() { # <rc> <message>
	printf 'pr-assets: %s\n' "$2" >&2
	exit "$1"
}

REMOTE=origin
if [ "${1:-}" = --remote ]; then
	[ $# -ge 2 ] || die 2 "--remote needs a value"
	REMOTE="$2"
	shift 2
fi
case "${REMOTE}" in -*) die 2 "not a remote name: ${REMOTE}" ;; esac
git remote get-url -- "${REMOTE}" >/dev/null 2>&1 || die 2 "no remote named ${REMOTE}"
[ $# -ge 3 ] || die 2 "usage: pr-assets.sh [--remote <name>] <repo-url> <key> <file>..."
BASE="${1%/}"
BASE="${BASE%.git}"
case "${BASE}" in
https://*/*/*/* | *[!A-Za-z0-9._/:-]*) die 2 "repo URL must be exactly https://<host>/<owner>/<repo>: $1" ;;
https://?*/?*/?*) ;;
*) die 2 "repo URL must be exactly https://<host>/<owner>/<repo>: $1" ;;
esac
KEY="$2"
shift 2
REF="refs/steer-assets/${KEY}"
git check-ref-format "${REF}" || die 2 "not a valid ref name: ${REF}"

names=""
for f in "$@"; do
	[ -f "${f}" ] && [ ! -L "${f}" ] || die 2 "not a regular file: ${f}"
	n="$(basename -- "${f}")"
	case "${n}" in *[!A-Za-z0-9._-]*) die 2 "file name must be [A-Za-z0-9._-]: ${n}" ;; esac
	case "${n}" in *.png | *.jpg | *.jpeg | *.gif | *.webp) ;; *) die 2 "images only (png, jpg, gif, webp): ${n}" ;; esac
	case "$(head -c 4 "${f}" | od -An -tx1 | tr -d ' \n')" in
	89504e47 | ffd8ff* | 47494638 | 52494646) ;;
	*) die 2 "not image content: ${n}" ;;
	esac
	case " ${names} " in *" ${n} "*) die 2 "duplicate file name: ${n}" ;; esac
	names="${names} ${n}"
done

TMP="$(mktemp "${TMPDIR:-/tmp}/pr-assets.XXXXXX")" || die 5 "mktemp failed"
trap 'rm -f "${TMP}"' EXIT
for f in "$@"; do
	blob="$(git hash-object -w -- "${f}")" || die 5 "hash-object failed: ${f}"
	printf '100644 blob %s\t%s\n' "${blob}" "$(basename -- "${f}")" >>"${TMP}"
done
tree="$(git mktree <"${TMP}")" || die 5 "mktree failed"

tip="$(git ls-remote "${REMOTE}" "${REF}")" || die 5 "ls-remote ${REMOTE} failed"
tip="$(printf '%s\n' "${tip}" | awk -v r="${REF}" '$2 == r { print $1 }')"
if [ -n "${tip}" ]; then
	git fetch -q "${REMOTE}" "${REF}" || die 5 "fetch ${REF} failed"
	commit="$(git commit-tree "${tree}" -p "${tip}" -m "steer: PR assets for ${KEY}")"
else
	commit="$(git commit-tree "${tree}" -m "steer: PR assets for ${KEY}")"
fi
[ -n "${commit}" ] || die 5 "commit-tree failed"
git push -q "${REMOTE}" "${commit}:${REF}" || die 5 "push to ${REF} failed"

for f in "$@"; do
	n="$(basename -- "${f}")"
	printf '%s\t%s/blob/%s/%s?raw=true\n' "${n}" "${BASE}" "${commit}" "${n}"
done
