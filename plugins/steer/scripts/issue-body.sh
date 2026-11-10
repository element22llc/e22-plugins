#!/usr/bin/env sh
# steer helper - the gh arm of /steer:tracker-sync update-state: a guarded,
# byte-preserving read-modify-write of one issue body (ISSUE-SCHEMA.md ->
# Update protocol). Exists so no agent improvises the rewrite in shell: a
# failed transform once wrote empty bodies to 13 issues (#905).
#
# USAGE
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/issue-body.sh" [--repo owner/repo] [--dry-run] marker-set <n> <key> <value>
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/issue-body.sh" [--repo owner/repo] [--dry-run] managed-replace <n> <block-file>
#   sh "${CLAUDE_PLUGIN_ROOT}/scripts/issue-body.sh" --in <body-file> <op> - <args>
#   marker-set sets or adds one `<!-- steer:<key>=<value> -->`; managed-replace
#   swaps the contents between the managed markers for <block-file>. --dry-run
#   prints the candidate and writes nothing; --in transforms a local body (the
#   MCP arm) and prints the candidate.
#
# EXIT  0 written or already current | 2 usage | 3 refused (fail closed) |
#       4 concurrent-edit conflict | 5 gh failed
#
# Bodies only ever travel through files: `$(...)` would strip trailing newlines.
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh + awk, no jq.

set -u

die() { # <rc> <message>
	printf 'issue-body: %s\n' "$2" >&2
	exit "$1"
}

REPO=""
DRY=0
IN=""
while [ $# -gt 0 ]; do
	case "$1" in
	--repo | --in)
		[ $# -ge 2 ] || die 2 "$1 needs a value"
		if [ "$1" = --repo ]; then REPO="$2"; else IN="$2" DRY=1; fi
		shift 2
		;;
	--dry-run) DRY=1 && shift ;;
	*) break ;;
	esac
done
[ $# -ge 2 ] || die 2 "usage: issue-body.sh [--repo R] [--dry-run|--in FILE] marker-set|managed-replace <n> ..."
OP="$1"
N="$2"
shift 2
case "${OP}" in
marker-set)
	[ $# -eq 2 ] || die 2 "marker-set <n> <key> <value>"
	KEY="$1"
	VALUE="$2"
	printf '%s' "${KEY}" | grep -Eq '^[a-z][a-z0-9-]*$' || die 2 "key must be kebab-case: ${KEY}"
	case "${VALUE}" in
	'' | *'-->'* | *'
'*) die 2 "value must be one line, non-empty, without -->" ;;
	esac
	;;
managed-replace)
	[ $# -eq 1 ] || die 2 "managed-replace <n> <block-file>"
	BLOCK="$1"
	[ -f "${BLOCK}" ] || die 2 "no such block file: ${BLOCK}"
	;;
*) die 2 "unknown op: ${OP}" ;;
esac
[ -n "${IN}" ] || printf '%s' "${N}" | grep -Eq '^[0-9]+$' || die 2 "issue number must be numeric: ${N}"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/steer-issue-body.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

fetch() { # <out>
	if [ -n "${IN}" ]; then
		cp "${IN}" "$1" || die 2 "cannot read ${IN}"
	else
		# --template, not --jq: jq appends a newline the body may not have.
		gh issue view "${N}" ${REPO:+--repo "${REPO}"} --json body --template '{{.body}}' >"$1" ||
			die 5 "gh issue view ${N} failed"
	fi
}

# Exactly one start/end pair in order for managed-replace; at most one for
# marker-set. Anything else is a schema conflict for a human.
check_blocks() { # <body> <min-pairs>
	awk -v min="$2" '
		{
			t = $0; s += gsub(/<!-- steer:managed:start -->/, "", t)
			t = $0; e += gsub(/<!-- steer:managed:end -->/, "", t)
			if (e > s) bad = 1
		}
		END { exit (bad || s != e || s < min || s > 1) }
	' "$1"
}

# The guard: everything outside the managed block and the steer key=value
# markers must survive byte for byte. The block collapses to one sentinel line
# so losing or duplicating it still differs.
strip() { # <body> -> stdout
	awk '
		index($0, "<!-- steer:managed:start -->") { inb = 1; print "\001managed"; next }
		inb { if (index($0, "<!-- steer:managed:end -->")) inb = 0; next }
		{
			s = $0; out = ""; hit = 0
			while ((p = index(s, "<!-- steer:")) > 0) {
				rest = substr(s, p); q = index(rest, "-->")
				if (!q) break
				inner = substr(rest, 12, q - 12)
				out = out substr(s, 1, p - 1)
				if (inner ~ /^[a-z][a-z0-9-]*=/) hit = 1; else out = out substr(rest, 1, q + 2)
				s = substr(rest, q + 3)
			}
			out = out s
			if (hit && out ~ /^[ \t\r]*$/) next
			print out
		}
	' "$1"
	# The final byte decides whether the last line ends in a newline.
	[ -n "$(tail -c 1 "$1")" ] && printf '\001no-eol\n'
}

build() { # <orig> <cand>
	[ -s "$1" ] || die 3 "refused: the read returned an empty body (indistinguishable from a failed read)"
	if [ "${OP}" = managed-replace ]; then
		check_blocks "$1" 1 || die 3 "refused: body needs exactly one well-formed steer:managed block"
		[ -s "${BLOCK}" ] || die 3 "refused: empty managed block"
		grep -q '<!-- steer:managed:' "${BLOCK}" && die 3 "refused: block file carries managed markers"
		BF="${BLOCK}" awk '
			function emit(s) { if (started) printf "\n"; printf "%s", s; started = 1 }
			index($0, "<!-- steer:managed:start -->") {
				emit($0)
				while ((getline l < ENVIRON["BF"]) > 0) emit(l)
				skip = 1; next
			}
			index($0, "<!-- steer:managed:end -->") { skip = 0 }
			!skip { emit($0) }
			END { if (EOL == "1") printf "\n" }
		' EOL="$(eol "$1")" "$1" >"$2"
	else
		check_blocks "$1" 0 || die 3 "refused: malformed or duplicate steer:managed block"
		K="${KEY}" V="${VALUE}" awk '
			function emit(s) { if (started) printf "\n"; printf "%s", s; started = 1 }
			BEGIN { needle = "<!-- steer:" ENVIRON["K"] "=" }
			index($0, "<!-- steer:managed:start -->") { inb = 1 }
			NR == FNR {
				if (!inb) { t = $0; while ((p = index(t, needle)) > 0) { hits++; hitline = FNR; t = substr(t, p + 1) } }
				line = $0; sub(/\r$/, "", line)
				if (!inb && !seenblock && line ~ /^<!-- steer:[a-z][a-z0-9-]*=.* -->$/) anchor = FNR
				if (index($0, "<!-- steer:managed:end -->")) { inb = 0; seenblock = 1 }
				next
			}
			FNR == 1 && hits > 1 { exit 3 }
			FNR == 1 && !hits && !anchor { cr = ($0 ~ /\r$/) ? "\r" : ""; emit(needle ENVIRON["V"] " -->" cr) }
			FNR == hitline {
				p = index($0, needle); rest = substr($0, p + length(needle)); q = index(rest, "-->")
				if (!q) exit 3
				emit(substr($0, 1, p - 1) needle ENVIRON["V"] " " substr(rest, q)); next
			}
			{ emit($0) }
			FNR == anchor && !hits { cr = ($0 ~ /\r$/) ? "\r" : ""; emit(needle ENVIRON["V"] " -->" cr) }
			END { if (hits <= 1 && EOL == "1") printf "\n" }
		' EOL="$(eol "$1")" "$1" "$1" >"$2" || die 3 "refused: duplicate or unterminated steer:${KEY} marker"
	fi
	[ -s "$2" ] || die 3 "refused: empty candidate body"
	strip "$1" >"${TMP}/a"
	strip "$2" >"${TMP}/b"
	cmp -s "${TMP}/a" "${TMP}/b" || die 3 "refused: candidate changes bytes outside the managed block and markers"
}

eol() { [ -z "$(tail -c 1 "$1")" ] && printf 1 || printf 0; }

fetch "${TMP}/orig"
build "${TMP}/orig" "${TMP}/cand"
if [ "${DRY}" = 1 ]; then
	cat "${TMP}/cand"
	exit 0
fi
fetch "${TMP}/again"
if ! cmp -s "${TMP}/orig" "${TMP}/again"; then
	mv "${TMP}/again" "${TMP}/orig"
	build "${TMP}/orig" "${TMP}/cand"
	fetch "${TMP}/again"
	cmp -s "${TMP}/orig" "${TMP}/again" || die 4 "conflict: issue #${N} changed twice during the update; not written"
fi
cmp -s "${TMP}/orig" "${TMP}/cand" && exit 0
gh issue edit "${N}" ${REPO:+--repo "${REPO}"} --body-file "${TMP}/cand" >/dev/null || die 5 "gh issue edit ${N} failed"
