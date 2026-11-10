#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# issue-body.sh is the gh arm of tracker-sync update-state: a guarded,
# byte-preserving read-modify-write of an issue body. A stub `gh` serves the
# body from a file so every write path runs offline.
IB="${PLUGIN}/scripts/issue-body.sh"
GHS="${WORK}/gh"
mkdir -p "${WORK}/bin" "${GHS}"
cat >"${WORK}/bin/gh" <<'EOF'
#!/usr/bin/env sh
# Stub gh: `issue view` prints $GHS/body, `issue edit --body-file F` copies F
# over it. $GHS/race appends a line to the body on every view after the first.
[ "$1" = issue ] || exit 1
case "$2" in
view)
	n=$(($(cat "${GHS}/views" 2>/dev/null || echo 0) + 1))
	printf '%s' "${n}" >"${GHS}/views"
	[ -f "${GHS}/fail" ] && exit 1
	[ -f "${GHS}/race" ] && [ "${n}" -gt 1 ] && printf 'edit %s\n' "${n}" >>"${GHS}/body"
	cat "${GHS}/body"
	;;
edit)
	while [ $# -gt 0 ]; do
		[ "$1" = --body-file ] && cp "$2" "${GHS}/body" && : >"${GHS}/edited"
		shift
	done
	;;
*) exit 1 ;;
esac
EOF
chmod +x "${WORK}/bin/gh"
export GHS
PATH="${WORK}/bin:${PATH}"
export PATH
# Never let a case reach the real gh and a real issue.
[ "$(command -v gh)" = "${WORK}/bin/gh" ] || {
	bad "issue-body: stub gh is not first on PATH"
	finish
	exit
}

seed() { # <body-printf-format> -> fresh stub state
	rm -f "${GHS}/views" "${GHS}/race" "${GHS}/fail" "${GHS}/edited"
	# shellcheck disable=SC2059 # the format is the fixture
	printf "$1" >"${GHS}/body"
	cp "${GHS}/body" "${WORK}/orig"
}
ib() { # <args...> -> sets rc; stderr to $WORK/err
	sh "${IB}" "$@" >"${WORK}/out" 2>"${WORK}/err"
	rc=$?
}
edited() { [ -f "${GHS}/edited" ] && printf yes || printf no; }
unchanged() { cmp -s "${GHS}/body" "${WORK}/orig" && ok || bad "$1 (body changed)"; }
expect() { # <label> <file> <sed-expr> -> <file> equals the seeded body edited by sed, byte for byte
	sed "$3" "${WORK}/orig" >"${WORK}/want"
	cmp -s "$2" "${WORK}/want" && ok || bad "$1 ($(diff "${WORK}/want" "$2" | head -5))"
}

BODY='<!-- steer:schema=2 -->\n<!-- steer:kind=bug -->\n<!-- steer:state=inbox -->\n<!-- steer:source=agent -->\n\nHuman text  with  spacing\n<!-- steer:managed:start -->\n## Problem\nold\n<!-- steer:managed:end -->\n\n## Team notes\nkeep $HOME and \\\\n literal\n'

seed "${BODY}"
ib marker-set 7 source implementation
assert_rc "marker-set: writes" "${rc}" 0
expect "marker-set: only the marker changed" "${GHS}/body" 's/source=agent/source=implementation/'

seed "${BODY}"
ib marker-set 7 state inbox
assert_rc "marker-set: same value is a no-op" "${rc}" 0
assert_eq "marker-set: no-op never writes" "$(edited)" no

seed "${BODY}"
ib marker-set 7 claimed-by claude-code
assert_rc "marker-set: absent key is added" "${rc}" 0
assert_eq "marker-set: added after the last top marker" "$(sed -n 5p "${GHS}/body")" '<!-- steer:claimed-by=claude-code -->'
assert_eq "marker-set: rest of the body intact" "$(sed 5d "${GHS}/body" | cksum)" "$(cksum <"${WORK}/orig")"

seed '<!-- steer:kind=bug -->\r\n<!-- steer:state=inbox -->\r\nWeb text\r\n'
ib marker-set 7 state exploring
assert_rc "crlf: writes" "${rc}" 0
assert_eq "crlf: carriage returns kept" "$(od -c "${GHS}/body" | grep -o '\\r' | wc -l | tr -d ' ')" 3
grep -q 'state=exploring -->' "${GHS}/body" && ok || bad "crlf: value replaced"
ib marker-set 7 pull-request 12
assert_eq "crlf: inserted marker gets the anchor's line ending" "$(sed -n 3p "${GHS}/body" | od -c | grep -c '\\r')" 1

seed "${BODY}"
printf '## Problem\nnew text\n' >"${WORK}/block"
ib managed-replace 7 "${WORK}/block"
assert_rc "managed-replace: writes" "${rc}" 0
expect "managed-replace: only the block changed" "${GHS}/body" 's/^old$/new text/'

seed '<!-- steer:state=inbox -->\ntext'
ib marker-set 7 state exploring
assert_eq "no trailing newline: kept that way" "$(tail -c 1 "${GHS}/body")" t

# Fail closed: each refusal exits 3 and leaves the body untouched.
seed "${BODY}"
: >"${WORK}/empty"
ib managed-replace 7 "${WORK}/empty"
assert_rc "refuse: empty block" "${rc}" 3
unchanged "refuse: empty block"

seed '<!-- steer:kind=bug -->\n<!-- steer:managed:start -->\na\n<!-- steer:managed:end -->\n<!-- steer:managed:start -->\nb\n<!-- steer:managed:end -->\n'
ib managed-replace 7 "${WORK}/block"
assert_rc "refuse: duplicate managed block" "${rc}" 3
unchanged "refuse: duplicate managed block"
ib marker-set 7 kind task
assert_rc "refuse: marker-set on a duplicate block" "${rc}" 3

seed '<!-- steer:kind=bug -->\n<!-- steer:managed:end -->\nx\n<!-- steer:managed:start -->\n'
ib managed-replace 7 "${WORK}/block"
assert_rc "refuse: end before start" "${rc}" 3

seed '<!-- steer:kind=bug -->\nno block\n'
ib managed-replace 7 "${WORK}/block"
assert_rc "refuse: no managed block" "${rc}" 3

seed '<!-- steer:kind=bug -->\n<!-- steer:kind=task -->\n'
ib marker-set 7 kind feature
assert_rc "refuse: duplicate marker key" "${rc}" 3
unchanged "refuse: duplicate marker key"

seed ''
ib marker-set 7 kind bug
assert_rc "refuse: an empty read" "${rc}" 3
assert_eq "refuse: an empty read never writes" "$(edited)" no

seed "${BODY}"
ib marker-set 7 kind 'a -->b'
assert_rc "usage: value that would close the comment" "${rc}" 2
ib marker-set 7 'Bad Key' x
assert_rc "usage: malformed key" "${rc}" 2
ib frobnicate 7
assert_rc "usage: unknown op" "${rc}" 2
unchanged "usage: nothing written"

# Concurrency: a body that changes between every read is a conflict.
seed "${BODY}"
: >"${GHS}/race"
ib marker-set 7 state exploring
assert_rc "conflict: changes again on the second attempt" "${rc}" 4
assert_eq "conflict: never writes" "$(edited)" no

seed "${BODY}"
: >"${GHS}/fail"
ib marker-set 7 state exploring
assert_rc "gh failure: reported, not written" "${rc}" 5

# --dry-run and --in never write; --in reads a local file for the MCP arm.
seed "${BODY}"
ib --dry-run marker-set 7 state exploring
assert_rc "dry-run: ok" "${rc}" 0
assert_eq "dry-run: never writes" "$(edited)" no
grep -q 'state=exploring' "${WORK}/out" && ok || bad "dry-run: candidate on stdout"
ib --in "${WORK}/orig" marker-set - state exploring
assert_rc "--in: ok" "${rc}" 0
expect "--in: candidate on stdout byte-exact" "${WORK}/out" 's/state=inbox/state=exploring/'

finish
