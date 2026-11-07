#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# check-comment-density.sh (PostToolUse) - flags a just-written source/config
# file by comment ratio: one advisory additionalContext from a fifth of its
# non-blank lines up, once per file per session. Reads the file from disk; never
# fails the tool call and never returns a decision.
# ---------------------------------------------------------------------------
RCD="$(new_repo repoCommentDensity)"
mkdir -p "${RCD}/src"
gen_lines() { # <count> <printf-format>  -> <count> lines, %s = index
	_i=0
	while [ "${_i}" -lt "$1" ]; do
		# shellcheck disable=SC2059  # the format string is the point
		printf -- "$2\n" "${_i}"
		_i=$((_i + 1))
	done
}
# (a) 16 comment + 8 code lines -> notice carrying the ratio, on PostToolUse.
{
	gen_lines 16 '// step %s'
	gen_lines 8 'const v%s = %s;'
} >"${RCD}/src/dense.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD1 src/dense.ts 'x')")"
assert_ctx "comment-density: dense ts write advises" "${out}"
assert_has "comment-density: notice carries the ratio" "${out}" '66% comment lines (16 of 24'
assert_rc "comment-density: advisory exits 0" "$(last_rc)" 0
# (b) even a file far past the threshold gets ONE notice per session - the block
# tier that used to re-fire above a third retired with the runtime style tiers.
assert_no_block "comment-density: never returns a decision" "${out}"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD1 src/dense.ts 'x')")"
assert_empty "comment-density: repeat write on a very dense file is silent" "${out}"
# (c) a new session re-flags the same file.
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD2 src/dense.ts 'x')")"
assert_ctx "comment-density: new session re-flags" "${out}"
# (d) exactly a third: one tier now, so this is the same advisory as any other
# file over the floor - it was the block/advisory boundary.
{
	gen_lines 8 '// note %s'
	gen_lines 16 'const w%s = %s;'
} >"${RCD}/src/third.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD3 src/third.ts 'x')")"
assert_ctx "comment-density: one third exactly is advisory" "${out}"
assert_no_block "comment-density: one third exactly does not block" "${out}"
# ...and the advisory tier stays once-per-file-per-session.
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD3 src/third.ts 'x')")"
assert_empty "comment-density: advisory repeat silent" "${out}"
# (d2) below the 20% advisory floor -> silent.
{
	gen_lines 4 '// note %s'
	gen_lines 26 'const y%s = %s;'
} >"${RCD}/src/sparse.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD12 src/sparse.ts 'x')")"
assert_empty "comment-density: under the advisory floor silent" "${out}"
# (e) block-comment bodies (`/*`, ` *`) count as comment lines.
{
	printf '/**\n'
	gen_lines 14 ' * line %s'
	printf ' */\n'
	gen_lines 6 'let b%s = %s;'
} >"${RCD}/src/block.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD4 src/block.ts 'x')")"
assert_ctx "comment-density: block comment counted" "${out}"
# (f) under 20 non-blank lines is exempt, even when all comments.
gen_lines 19 '# only %s' >"${RCD}/src/short.py"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD5 src/short.py 'x')")"
assert_empty "comment-density: short file exempt" "${out}"
# (g) hash style: a `#` inside a string is not a comment.
gen_lines 24 'tag%s = "# not a comment"' >"${RCD}/src/strings.py"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD6 src/strings.py 'x')")"
assert_empty "comment-density: hash inside string not counted" "${out}"
{
	gen_lines 14 '# note %s'
	gen_lines 7 'x%s = %s'
} >"${RCD}/src/dense.py"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD6 src/dense.py 'x')")"
assert_has "comment-density: python leading hash counted" "${out}" '(14 of 21'
# (h) config counts too: a mise.toml essay is flagged like source.
{
	gen_lines 20 '# rationale %s'
	printf '[tools]\n'
	gen_lines 5 'tool%s = "latest"'
} >"${RCD}/mise.toml"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD7 mise.toml 'x')")"
assert_ctx "comment-density: toml config flagged" "${out}"
# (i) prose is out of scope even when every line starts with `#`.
gen_lines 30 '# heading %s' >"${RCD}/NOTES.md"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD8 NOTES.md 'x')")"
assert_empty "comment-density: markdown skipped" "${out}"
# (i2) dependabot.yml is exempt: its per-stack blocks are commented code by design.
mkdir -p "${RCD}/.github"
cp "${RCD}/mise.toml" "${RCD}/.github/dependabot.yml"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD8 .github/dependabot.yml 'x')")"
assert_empty "comment-density: dependabot.yml exempt" "${out}"
# (j) the plugin's own source repo is exempt.
RCDP="$(new_repo repoCommentDensityPlugin)"
mkdir -p "${RCDP}/.claude-plugin" "${RCDP}/hooks"
cp "${RCD}/src/dense.py" "${RCDP}/hooks/x.py"
out="$(run_hook check-comment-density.sh "$(json_write "${RCDP}" sCD9 hooks/x.py 'x')")"
assert_empty "comment-density: plugin repo exempt" "${out}"
# (k) target missing on disk (a failed write) -> silent.
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD10 src/nope.ts 'x')")"
assert_empty "comment-density: missing file silent" "${out}"
# (l) hooks.json registers it under PostToolUse with the sh prefix.
tr -d '\\' <"${HOOKS}/hooks.json" | grep -q 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/check-comment-density.sh"' && ok ||
	bad "hooks.json: check-comment-density.sh must be registered with the sh prefix"
# (m) file-level opt-out with a reason silences the notice; a bare marker does not.
{
	printf '// steer:allow-comments every line documents a protocol quirk\n'
	gen_lines 16 '// step %s'
	gen_lines 8 'const z%s = %s;'
} >"${RCD}/src/waived.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD13 src/waived.ts 'x')")"
assert_empty "comment-density: allow-comments with a reason silences" "${out}"
{
	printf '// steer:allow-comments\n'
	gen_lines 16 '// step %s'
	gen_lines 8 'const z%s = %s;'
} >"${RCD}/src/bare.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD14 src/bare.ts 'x')")"
assert_ctx "comment-density: bare allow-comments does not silence" "${out}"
# The marker itself is a steer: directive, so it must not count toward the ratio:
# 16 of 25 non-blank lines, not 17.
assert_has "comment-density: marker line not counted" "${out}" '(16 of 25'
# SQL and Lua take the marker in a `--` comment, the only syntax they have.
{
	printf -- '-- steer:allow-comments every line documents a migration constraint\n'
	gen_lines 16 '-- step %s'
	gen_lines 8 'SELECT %s;'
} >"${RCD}/src/waived.sql"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD17 src/waived.sql 'x')")"
assert_empty "comment-density: -- allow-comments with a reason silences" "${out}"
{
	printf -- '-- steer:allow-comments\n'
	gen_lines 16 '-- step %s'
	gen_lines 8 'SELECT %s;'
} >"${RCD}/src/bare.sql"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD18 src/bare.sql 'x')")"
assert_ctx "comment-density: bare -- allow-comments does not silence" "${out}"
assert_has "comment-density: -- marker line not counted" "${out}" '(16 of 25'
# (n) the notice is once per file per session, whatever the file does next: a
# trimmed file has nothing more to say, and a regressed one was already told.
{
	gen_lines 16 '// step %s'
	gen_lines 8 'const r%s = %s;'
} >"${RCD}/src/recover.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD15 src/recover.ts 'x')")"
assert_ctx "comment-density: recover case is flagged once" "${out}"
{
	gen_lines 6 '// why %s'
	gen_lines 18 'const r%s = %s;'
} >"${RCD}/src/recover.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD15 src/recover.ts 'x')")"
assert_empty "comment-density: trimmed file is silent" "${out}"
{
	gen_lines 16 '// step %s'
	gen_lines 8 'const r%s = %s;'
} >"${RCD}/src/recover.ts"
out="$(run_hook check-comment-density.sh "$(json_write "${RCD}" sCD15 src/recover.ts 'x')")"
assert_empty "comment-density: regression stays silent in the same session" "${out}"

finish
