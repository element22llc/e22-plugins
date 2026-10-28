# shellcheck shell=sh
# Repo-local helper - typographic-character detection for rule 85 ("ASCII
# everywhere"), used by scripts/check-ascii.sh, this repo's committed-state gate.
# It lived under plugins/steer/hooks/lib/ while a write-time hook shared the
# table; that tier retired (the rule stands, reviewers catch strays), so the
# table moved here with the only caller that remains. It ships nothing.
#
# The set is exactly rule 85's, enumerated: dashes, curly quotes, ellipsis,
# bullets and middle dots, arrows, non-breaking and thin spaces, section and math
# signs, box drawing, check/cross/warning marks and emoji. Accented Latin
# letters, guillemets and CJK are deliberately absent: they are legitimate
# content, and flagging them would break non-English copy.
#
# There is no comment-stripping step. An earlier version scanned only value
# positions, on the theory that prose was exempt; rule 85 no longer exempts it,
# so the scan is raw and a typographic character is reported wherever it sits.
#
# POSIX sh; source this file.

# _steer_typo_hit <bytes> <codepoint-hex> <label> - append <label> once when
# either the raw bytes or the \uXXXX text spelling is present. A block entry
# (box drawing, emoji) passes a lead-byte prefix and an empty codepoint, which
# skips the escape spelling. Reads/writes the caller's _tn_in / _tn_u / _tn_bs /
# _tn_out.
#
# The escape spelling is matched against a haystack whose backslashes have been
# folded to a sentinel, because a backslash inside a `case` pattern keeps its
# escaping meaning even when the pattern comes from a quoted variable - so a
# literal backslash-u pattern silently matches the bare hex instead. Folding
# sidesteps that without a grep subprocess per character on the write path.
_steer_typo_hit() {
	case "${_tn_out}" in *"$3"*) return ;; esac
	case "${_tn_in}" in *"$1"*)
		_tn_out="${_tn_out}${_tn_out:+; }$3"
		return
		;;
	esac
	[ -n "$2" ] || return 0
	case "${_tn_u}" in *"${_tn_bs}u$2"*) _tn_out="${_tn_out}${_tn_out:+; }$3" ;; esac
}

# steer_typographic_names - stdin scanned for the rule-85 set; prints one entry
# per DISTINCT offender, "<name> U+XXXX -> <ascii>", so the deny message tells
# the model what to substitute instead of leaving it to guess. Empty when clean.
steer_typographic_names() {
	_tn_in="$(cat)"
	[ -n "${_tn_in}" ] || return 0
	# The \uXXXX text spelling is matched too: a host that serializes hook input
	# with ensure_ascii sends the escape rather than the raw bytes, and the
	# unescaper does not decode it. Lowercased so the upper- and lower-case hex
	# spellings both hit.
	_tn_bs="$(printf '%b' '\001')"
	_tn_u="$(printf '%s' "${_tn_in}" | tr 'ABCDEF' 'abcdef' | tr '\\' "${_tn_bs}")"
	_tn_out=""

	_steer_typo_hit "$(printf '%b' '\0342\0200\0224')" '2014' 'em dash U+2014 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0223')" '2013' 'en dash U+2013 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0220')" '2010' 'hyphen U+2010 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0221')" '2011' 'non-breaking hyphen U+2011 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0222')" '2012' 'figure dash U+2012 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0225')" '2015' 'horizontal bar U+2015 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0230')" '2018' 'left single quote U+2018 -> straight single quote'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0231')" '2019' 'right single quote U+2019 -> straight single quote'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0234')" '201c' 'left double quote U+201C -> straight double quote'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0235')" '201d' 'right double quote U+201D -> straight double quote'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0246')" '2026' 'ellipsis U+2026 -> ...'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0242')" '2022' 'bullet U+2022 -> *'
	_steer_typo_hit "$(printf '%b' '\0302\0240')" '00a0' 'non-breaking space U+00A0 -> space'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0257')" '202f' 'narrow no-break space U+202F -> space'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0211')" '2009' 'thin space U+2009 -> space'
	_steer_typo_hit "$(printf '%b' '\0342\0206\0222')" '2192' 'right arrow U+2192 -> ->'
	_steer_typo_hit "$(printf '%b' '\0342\0206\0220')" '2190' 'left arrow U+2190 -> <-'
	_steer_typo_hit "$(printf '%b' '\0342\0206\0224')" '2194' 'left-right arrow U+2194 -> <->'
	_steer_typo_hit "$(printf '%b' '\0342\0207\0222')" '21d2' 'double right arrow U+21D2 -> =>'
	_steer_typo_hit "$(printf '%b' '\0342\0207\0224')" '21d4' 'left-right double arrow U+21D4 -> <=>'
	_steer_typo_hit "$(printf '%b' '\0302\0267')" '00b7' 'middle dot U+00B7 -> , or /'
	_steer_typo_hit "$(printf '%b' '\0302\0247')" '00a7' 'section sign U+00A7 -> "section N", or -> before a heading'
	_steer_typo_hit "$(printf '%b' '\0303\0227')" '00d7' 'multiplication sign U+00D7 -> x'
	_steer_typo_hit "$(printf '%b' '\0303\0267')" '00f7' 'division sign U+00F7 -> /'
	_steer_typo_hit "$(printf '%b' '\0342\0210\0222')" '2212' 'minus sign U+2212 -> -'
	_steer_typo_hit "$(printf '%b' '\0342\0211\0245')" '2265' 'greater-than or equal U+2265 -> >='
	_steer_typo_hit "$(printf '%b' '\0342\0211\0244')" '2264' 'less-than or equal U+2264 -> <='
	_steer_typo_hit "$(printf '%b' '\0342\0211\0240')" '2260' 'not equal U+2260 -> !='
	_steer_typo_hit "$(printf '%b' '\0342\0211\0210')" '2248' 'almost equal U+2248 -> ~'
	_steer_typo_hit "$(printf '%b' '\0342\0211\0241')" '2261' 'identical to U+2261 -> =='
	_steer_typo_hit "$(printf '%b' '\0342\0210\0210')" '2208' 'element of U+2208 -> in'
	_steer_typo_hit "$(printf '%b' '\0342\0212\0206')" '2286' 'subset of or equal U+2286 -> subset of'
	_steer_typo_hit "$(printf '%b' '\0342\0204\0271')" '2139' 'information sign U+2139 -> drop it, or Note:'
	_steer_typo_hit "$(printf '%b' '\0342\0232\0240')" '26a0' 'warning sign U+26A0 -> drop it, or Warning:'
	_steer_typo_hit "$(printf '%b' '\0342\0234\0205')" '2705' 'check mark U+2705 -> yes'
	_steer_typo_hit "$(printf '%b' '\0342\0234\0223')" '2713' 'check mark U+2713 -> yes'
	_steer_typo_hit "$(printf '%b' '\0342\0234\0227')" '2717' 'ballot x U+2717 -> no'
	_steer_typo_hit "$(printf '%b' '\0342\0235\0214')" '274c' 'cross mark U+274C -> no'
	_steer_typo_hit "$(printf '%b' '\0342\0235\0223')" '2753' 'question mark ornament U+2753 -> ?'
	_steer_typo_hit "$(printf '%b' '\0357\0270\0217')" 'fe0f' 'variation selector U+FE0F -> delete it'
	_steer_typo_hit "$(printf '%b' '\0342\0224')" '' 'box drawing U+2500-257F -> |-- `-- |'
	_steer_typo_hit "$(printf '%b' '\0342\0225')" '' 'box drawing U+2500-257F -> |-- `-- |'
	_steer_typo_hit "$(printf '%b' '\0360\0237')" '' 'emoji U+1F000-1FFFF -> a word'

	printf '%s' "${_tn_out}"
}

# steer_typographic_scan <path> - the offenders in <path>, nothing when clean.
steer_typographic_scan() {
	steer_typographic_names <"$1"
}
