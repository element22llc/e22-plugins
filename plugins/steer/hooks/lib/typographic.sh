# shellcheck shell=sh
# steer hook helper - typographic-character detection for rule 85 ("ASCII in
# code and values"), shared by check-ascii-writes.sh and the fixture suite that
# proves the bundled templates are clean in value positions.
#
# Three pieces: map a path to its comment syntax, strip comments, name the
# offending characters in what is left. They are separate so the template sweep
# can run the same stripper the hook runs - if the stripping heuristics were
# duplicated, the templates could pass a sweep the live gate would still deny.
#
# The character set is exactly rule 85's - dashes, curly quotes, ellipsis,
# arrows, non-breaking and thin spaces, bullet - and nothing else. Accented
# Latin letters, guillemets, CJK and emoji are deliberately absent: they are
# legitimate content, and flagging them would break non-English copy.
#
# POSIX sh; source this file.

# steer_comment_style <path> - the comment syntax to strip before scanning, or
# nothing when the file type has none we can parse (in which case the caller
# skips the file rather than scanning it raw).
#
#   hash   #  to end of line
#   slash  // to end of line, plus /* */ blocks
#   tf     both of the above (Terraform/HCL accept either)
#   jsonc  line-leading // only - a JSON string value routinely carries "//"
#          inside a URL, and stripping there would blind the scan to the rest
#          of the line
#   dash   -- to end of line
steer_comment_style() {
	case "${1##*/}" in
	Dockerfile | Dockerfile.* | Containerfile | Makefile | makefile | GNUmakefile)
		printf 'hash'
		return
		;;
	esac
	case "$1" in
	*.py | *.sh | *.bash | *.zsh | *.rb | *.pl | *.toml | *.yaml | *.yml | \
		*.ini | *.cfg | *.conf | *.properties | *.mk | *.ex | *.exs | \
		*.env | *.env.*) printf 'hash' ;;
	*.tf | *.tfvars | *.hcl) printf 'tf' ;;
	*.json) printf 'jsonc' ;;
	*.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs | *.go | *.rs | *.java | *.kt | \
		*.kts | *.swift | *.c | *.h | *.cc | *.cpp | *.hpp | *.cs | *.scala | \
		*.dart | *.php | *.vue | *.svelte) printf 'slash' ;;
	*.sql | *.lua) printf 'dash' ;;
	*) : ;;
	esac
}

# steer_strip_comments <style> - stdin with comment text removed, so only value
# positions remain. Every heuristic over-strips on purpose: dropping too much
# only costs a missed character (the always-on rule still applies), while
# dropping too little produces a false deny, which is what gets a gate disabled.
steer_strip_comments() {
	LC_ALL=C awk -v style="$1" '
		# Keep the "//" when it follows ":" so a URL survives; the scan must still
		# see the rest of "https://example.com <em dash> label".
		function line_slash(s,   i, c, out) {
			out = ""
			while (1) {
				i = index(s, "//")
				if (i == 0) return out s
				c = (i > 1) ? substr(s, i - 1, 1) : ""
				if (c != ":") return out substr(s, 1, i - 1)
				out = out substr(s, 1, i + 1)
				s = substr(s, i + 2)
			}
		}
		function block(s,   i, j, out) {
			out = ""
			while (1) {
				if (inblock) {
					j = index(s, "*/")
					if (j == 0) return out
					s = substr(s, j + 2)
					inblock = 0
				}
				i = index(s, "/*")
				if (i == 0) return out s
				out = out substr(s, 1, i - 1)
				s = substr(s, i + 2)
				inblock = 1
			}
		}
		BEGIN { inblock = 0 }
		{
			line = $0
			if (style == "slash" || style == "tf" || style == "jsonc") line = block(line)
			if (style == "hash" || style == "tf") sub(/#.*/, "", line)
			if (style == "slash" || style == "tf") line = line_slash(line)
			if (style == "jsonc" && line ~ /^[ \t]*\/\//) line = ""
			if (style == "dash") sub(/--.*/, "", line)
			# A continuation line of a doc block the state machine did not catch
			# (an Edit payload can start mid-block).
			if ((style == "slash" || style == "tf") && line ~ /^[ \t]*\*/) line = ""
			print line
		}
	'
}

# _steer_typo_hit <bytes> <codepoint-hex> <label> - append <label> once when
# either the raw bytes or the \uXXXX text spelling is present. Reads/writes the
# caller's _tn_in / _tn_u / _tn_bs / _tn_out.
#
# The escape spelling is matched against a haystack whose backslashes have been
# folded to a sentinel, because a backslash inside a `case` pattern keeps its
# escaping meaning even when the pattern comes from a quoted variable - so a
# literal backslash-u pattern silently matches the bare hex instead. Folding
# sidesteps that without a grep subprocess per character on the write path.
_steer_typo_hit() {
	case "${_tn_in}" in *"$1"*)
		_tn_out="${_tn_out}${_tn_out:+; }$3"
		return
		;;
	esac
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
	_steer_typo_hit "$(printf '%b' '\0342\0200\0230')" '2018' "left single quote U+2018 -> '"
	_steer_typo_hit "$(printf '%b' '\0342\0200\0231')" '2019' "right single quote U+2019 -> '"
	_steer_typo_hit "$(printf '%b' '\0342\0200\0234')" '201c' 'left double quote U+201C -> "'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0235')" '201d' 'right double quote U+201D -> "'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0246')" '2026' 'ellipsis U+2026 -> ...'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0242')" '2022' 'bullet U+2022 -> *'
	_steer_typo_hit "$(printf '%b' '\0302\0240')" '00a0' 'non-breaking space U+00A0 -> space'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0257')" '202f' 'narrow no-break space U+202F -> space'
	_steer_typo_hit "$(printf '%b' '\0342\0200\0211')" '2009' 'thin space U+2009 -> space'
	_steer_typo_hit "$(printf '%b' '\0342\0206\0222')" '2192' 'right arrow U+2192 -> ->'
	_steer_typo_hit "$(printf '%b' '\0342\0206\0220')" '2190' 'left arrow U+2190 -> <-'
	_steer_typo_hit "$(printf '%b' '\0342\0206\0224')" '2194' 'left-right arrow U+2194 -> <->'
	_steer_typo_hit "$(printf '%b' '\0342\0207\0222')" '21d2' 'double right arrow U+21D2 -> =>'

	printf '%s' "${_tn_out}"
}

# steer_typographic_scan <path> - convenience wrapper over the three pieces:
# prints the offenders in <path>'s value positions, nothing when clean or when
# the file type has no known comment syntax.
steer_typographic_scan() {
	_ts_style="$(steer_comment_style "$1")"
	[ -n "${_ts_style}" ] || return 0
	steer_strip_comments "${_ts_style}" <"$1" | steer_typographic_names
}
