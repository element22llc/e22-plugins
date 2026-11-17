#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# format-on-write.sh (PostToolUse) - formats the just-written file with the
# repo's OWN formatter, only when its config is present at the root. Stubbed
# biome/ruff binaries record their argv so the cases assert exactly what ran;
# PATH is pinned to stubs + /usr/bin:/bin so a real formatter never interferes.
# ---------------------------------------------------------------------------
STUBS="${WORK}/stubs"
STUB_LOG="${WORK}/stub.log"
mkdir -p "${STUBS}"
for _fmt in biome ruff; do
	printf '#!/bin/sh\nprintf "%%s %%s\\n" "$0" "$*" >>"${STUB_LOG:?}"\n' >"${STUBS}/${_fmt}"
	chmod +x "${STUBS}/${_fmt}"
done
FMT_ENV="PATH=${STUBS}:/usr/bin:/bin STUB_LOG=${STUB_LOG}"

# (a) biome-configured repo: a ts write runs `biome format --write <file>`,
#     hook stays silent with rc 0.
RF1="$(new_repo repoFmtBiome)"
printf '{}\n' >"${RF1}/biome.json"
mkdir -p "${RF1}/src"
printf 'x' >"${RF1}/src/app.ts"
: >"${STUB_LOG}"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF1}" sF1 src/app.ts 'x')")"
assert_empty "format: biome repo write silent" "${out}"
grep -q "biome format --write ${RF1}/src/app.ts" "${STUB_LOG}" && ok ||
	bad "format: biome invoked on written file (log: $(cat "${STUB_LOG}"))"

# (b) ruff via pyproject.toml: a py write runs `ruff format <file>`.
RF2="$(new_repo repoFmtRuff)"
printf '[project]\n' >"${RF2}/pyproject.toml"
mkdir -p "${RF2}/src"
printf 'x = 1\n' >"${RF2}/src/mod.py"
: >"${STUB_LOG}"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF2}" sF2 src/mod.py 'x = 1')")"
assert_empty "format: ruff repo write silent" "${out}"
grep -q "ruff format ${RF2}/src/mod.py" "${STUB_LOG}" && ok ||
	bad "format: ruff invoked on written file (log: $(cat "${STUB_LOG}"))"

# (c) no formatter config at the root -> opt-in missing -> formatter NOT run.
RF3="$(new_repo repoFmtNoCfg)"
mkdir -p "${RF3}/src"
printf 'x' >"${RF3}/src/app.ts"
: >"${STUB_LOG}"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF3}" sF3 src/app.ts 'x')")"
assert_empty "format: unconfigured repo silent" "${out}"
[ -s "${STUB_LOG}" ] && bad "format: no config must not invoke a formatter (log: $(cat "${STUB_LOG}"))" || ok

# (d) unknown extension (docs) -> never formatted, even with config present.
: >"${STUB_LOG}"
printf '# hi\n' >"${RF1}/README.md"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF1}" sF4 README.md '# hi')")"
assert_empty "format: docs write silent" "${out}"
[ -s "${STUB_LOG}" ] && bad "format: md must not be formatted (log: $(cat "${STUB_LOG}"))" || ok

# (e) formatter binary absent from PATH -> silent no-op, never an install.
out="$(ENV="PATH=/usr/bin:/bin" run_hook format-on-write.sh "$(json_write "${RF1}" sF5 src/app.ts 'x')")"
assert_empty "format: missing binary silent no-op" "${out}"

# (f) target file does not exist (defensive) -> silent, formatter not run.
: >"${STUB_LOG}"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF1}" sF6 src/ghost.ts 'x')")"
assert_empty "format: missing file silent" "${out}"
[ -s "${STUB_LOG}" ] && bad "format: missing file must not invoke a formatter" || ok

# (g) the plugin's own source repo is exempt (pre-commit owns formatting there).
RF4="$(new_repo repoFmtPlugin)"
mkdir -p "${RF4}/.claude-plugin" "${RF4}/src"
printf '{}\n' >"${RF4}/biome.json"
printf 'x' >"${RF4}/src/app.ts"
: >"${STUB_LOG}"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF4}" sF7 src/app.ts 'x')")"
assert_empty "format: plugin source repo exempt" "${out}"
[ -s "${STUB_LOG}" ] && bad "format: plugin repo must not be formatted" || ok

# (h) absolute file_path resolves without the cwd prefix.
: >"${STUB_LOG}"
out="$(ENV="${FMT_ENV}" run_hook format-on-write.sh "$(json_write "${RF1}" sF8 "${RF1}/src/app.ts" 'x')")"
assert_empty "format: absolute path silent" "${out}"
grep -q "biome format --write ${RF1}/src/app.ts" "${STUB_LOG}" && ok ||
	bad "format: absolute path formatted (log: $(cat "${STUB_LOG}"))"
unset ENV

finish
