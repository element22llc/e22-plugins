#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- rule 85 (ASCII everywhere) - the character table and the template sweep ---
# The write-time hook that used to deny a typographic character retired with the
# ASCII hook tier: the rule stands and reviewers catch strays. Two guards remain,
# and they are the ones that protect a CONSUMER repo rather than a session.

# (a) THE REGRESSION THAT MATTERS: every bundled template must be clean, or
# /steer:init and /steer:adopt would write files that break rule 85 in the
# consumer repo the moment they land. Markdown is included: prose is in scope.
. "${PLUGIN}/../../scripts/typographic.sh"
ASCII_DIRTY="$(find "${PLUGIN}/templates" -type f -print 2>/dev/null |
	while IFS= read -r f; do
		[ -n "$(steer_typographic_scan "${f}")" ] && printf ' %s' "${f#"${PLUGIN}/"}"
	done)"
[ -z "${ASCII_DIRTY}" ] && ok ||
	bad "bundled templates carry typographic characters:${ASCII_DIRTY}"

# (b) scripts/check-ascii.sh carries a SECOND copy of the character set: a bulk
# grep pattern used as a fast first pass over every tracked file, with the naming
# table above run only on the files it flags. If the two ever disagree the gate
# silently skips a file it should have reported, so assert every character the
# table knows is matched by that pattern - and that no accented or guillemet
# character is.
ASCII_PAT="$(sed -n 's/^PATTERN="$(printf \(.*\))"$/\1/p' "${PLUGIN}/../../scripts/check-ascii.sh")"
if [ -z "${ASCII_PAT}" ]; then
	bad "check-ascii.sh: could not extract the bulk PATTERN for the parity check"
else
	ASCII_PAT="$(eval "printf ${ASCII_PAT}")"
	ASCII_PARITY=""
	for _oct in '\0342\0200\0224' '\0342\0200\0223' '\0342\0200\0220' '\0342\0200\0221' \
		'\0342\0200\0222' '\0342\0200\0225' '\0342\0200\0230' '\0342\0200\0231' \
		'\0342\0200\0234' '\0342\0200\0235' '\0342\0200\0246' '\0342\0200\0242' \
		'\0302\0240' '\0342\0200\0257' '\0342\0200\0211' '\0342\0206\0222' \
		'\0342\0206\0220' '\0342\0206\0224' '\0342\0207\0222' '\0342\0207\0224' \
		'\0302\0267' '\0302\0247' '\0303\0227' '\0303\0267' '\0342\0210\0222' \
		'\0342\0211\0245' '\0342\0211\0244' '\0342\0211\0240' '\0342\0211\0210' \
		'\0342\0211\0241' '\0342\0210\0210' '\0342\0212\0206' '\0342\0204\0271' \
		'\0342\0232\0240' '\0342\0234\0205' '\0342\0234\0223' '\0342\0234\0227' \
		'\0342\0235\0214' '\0342\0235\0223' '\0357\0270\0217' '\0342\0224\0234' \
		'\0342\0225\0277' '\0360\0237\0224\0264'; do
		printf 'a %b b\n' "${_oct}" | LC_ALL=C grep -qIE -- "${ASCII_PAT}" ||
			ASCII_PARITY="${ASCII_PARITY} ${_oct}"
	done
	[ -z "${ASCII_PARITY}" ] && ok ||
		bad "check-ascii.sh bulk pattern misses characters the naming table knows:${ASCII_PARITY}"
	# Accented Latin, Greek and guillemets must never match - non-English copy is out of scope.
	ASCII_FP=""
	for _oct in '\0303\0251' '\0303\0240' '\0302\0253' '\0302\0273' '\0303\0266' '\0316\0224'; do
		printf 'a %b b\n' "${_oct}" | LC_ALL=C grep -qIE -- "${ASCII_PAT}" &&
			ASCII_FP="${ASCII_FP} ${_oct}"
	done
	[ -z "${ASCII_FP}" ] && ok ||
		bad "check-ascii.sh bulk pattern matches non-English characters:${ASCII_FP}"
fi

finish
