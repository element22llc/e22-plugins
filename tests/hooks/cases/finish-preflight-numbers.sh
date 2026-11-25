#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# scripts/finish-preflight.sh `numbers` - ADR and migration numbers the branch
# adds, against the default branch and open PRs. A local bare repo stands in
# for GitHub; a stub `gh` serves the open-PR file list from a file.
FP="${PLUGIN}/scripts/finish-preflight.sh"
T="$(printf '\t')"
GHS="${WORK}/gh"
mkdir -p "${WORK}/bin" "${GHS}"
cat >"${WORK}/bin/gh" <<'EOF'
#!/usr/bin/env sh
# Stub gh: `pr list --head H` (the base check) prints $GHS/open-<H, / as _>;
# any other `pr list` (the numbers check) logs its argv to $GHS/calls and
# prints $GHS/prs. The real --jq never runs: the files hold its output.
[ -f "${GHS}/fail" ] && exit 1
[ "$1 $2" = "pr list" ] || exit 1
h=""
for a in "$@"; do
	[ "${prev:-}" = --head ] && h="$(printf '%s' "${a}" | tr / _)"
	prev="${a}"
done
if [ -n "${h}" ]; then
	cat "${GHS}/open-${h}" 2>/dev/null
else
	printf '%s\n' "$*" >>"${GHS}/calls"
	cat "${GHS}/prs" 2>/dev/null
fi
exit 0
EOF
chmod +x "${WORK}/bin/gh"
export GHS
PATH="${WORK}/bin:${PATH}"
export PATH
[ "$(command -v gh)" = "${WORK}/bin/gh" ] || {
	bad "finish-preflight-numbers: stub gh is not first on PATH"
	finish
}
command -v git >/dev/null 2>&1 || finish

git init -q --bare "${WORK}/np-origin.git"
git -C "${WORK}/np-origin.git" symbolic-ref HEAD refs/heads/main
R="$(git_repo npRepo main)"
git -C "${R}" remote add origin "${WORK}/np-origin.git"
add() { # <repo> <path> - commit a new file at path
	mkdir -p "$1/$(dirname -- "$2")"
	printf 'x\n' >"$1/$2"
	git -C "$1" add -- "$2" && git -C "$1" commit -q -m "add $2"
}
add "${R}" spec/decisions/0001-init.md
add "${R}" drizzle/0000_init.sql
add "${R}" drizzle/meta/0000_snapshot.json
add "${R}" app/migrations/0001_initial.py
git -C "${R}" push -q origin main
O="${WORK}/npOther"
git clone -q "${WORK}/np-origin.git" "${O}" 2>/dev/null
git -C "${O}" config user.email t@e.com
git -C "${O}" config user.name t
fp() { out="$(cd "${R}" && sh "${FP}" "$@" 2>/dev/null)" && rc=0 || rc=$?; }
state() { printf '%s|%s|%s|%s' "$(git -C "${R}" rev-parse HEAD)" "$(git -C "${R}" symbolic-ref -q HEAD)" \
	"$(git -C "${R}" for-each-ref --format='%(refname) %(objectname)' refs/heads)" "$(git -C "${R}" status --porcelain)"; }
cut_branch() { # <name> - a new branch off the freshly fetched main
	git -C "${R}" fetch -q origin
	git -C "${R}" switch -q -c "$1" origin/main
}
: >"${GHS}/prs"

cut_branch issue/1-none
add "${R}" f.txt
fp numbers
assert_rc "numbers: no numbered file added exits 0" "${rc}" 0
assert_eq "numbers: no numbered file added -> silent" "${out}" ""
fp
assert_eq "numbers: a full run on such a branch prints only base lines" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}"

cut_branch issue/2-adr
add "${R}" spec/decisions/0002-mine.md
add "${O}" spec/decisions/0002-theirs.md
git -C "${O}" push -q origin main
printf 'count\t1\nfile\t21\tfeat/x\tfalse\tspec/decisions/0002-theirs.md\n' >"${GHS}/prs"
before="$(state)"
fp numbers
assert_rc "numbers: a collision is a finding, not a failure" "${rc}" 0
assert_eq "numbers: ADR number taken on the default branch, a PR adding the same file not repeated" "${out}" \
	"numbers${T}taken${T}spec/decisions/0002-mine.md${T}origin/main${T}spec/decisions/0002-theirs.md"
assert_eq "numbers: HEAD, branches, index and tree untouched" "$(state)" "${before}"
assert_eq "numbers: the open-PR query is the one the helper documents" "$(sed -n '$p' "${GHS}/calls")" \
	"pr list --state open --limit 200 --json number,headRefName,isCrossRepository,changedFiles,files --jq \"count\\t\\(length)\", (.[] | . as \$p | (if .changedFiles > (.files | length) then \"partial\\t\\(.number)\\t\\(.headRefName)\\t\\(.isCrossRepository)\" else empty end), (.files[] | \"file\\t\\(\$p.number)\\t\\(\$p.headRefName)\\t\\(\$p.isCrossRepository)\\t\\(.path)\"))"
fp
assert_eq "numbers: a full run prints the base lines, then the numbers lines" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}
base${T}merge${T}origin/main
numbers${T}taken${T}spec/decisions/0002-mine.md${T}origin/main${T}spec/decisions/0002-theirs.md"
fp --base feat/elsewhere numbers
assert_eq "numbers: --base does not move the check off the default branch" "${out}" \
	"numbers${T}taken${T}spec/decisions/0002-mine.md${T}origin/main${T}spec/decisions/0002-theirs.md"
: >"${GHS}/fail"
fp numbers
assert_eq "numbers: gh unavailable -> default-branch collisions still reported" "${out}" \
	"numbers${T}unchecked${T}open PRs: gh unavailable
numbers${T}taken${T}spec/decisions/0002-mine.md${T}origin/main${T}spec/decisions/0002-theirs.md"
rm -f "${GHS}/fail"

cut_branch issue/3-pr
add "${R}" spec/decisions/0003-mine.md
printf '%s\n' "count${T}3" \
	"file${T}7${T}feat/other${T}false${T}spec/decisions/0003-other.md" \
	"file${T}9${T}issue/3-pr${T}false${T}spec/decisions/0003-mine.md" \
	"file${T}9${T}issue/3-pr${T}false${T}spec/decisions/0003-own-twin.md" \
	"file${T}11${T}issue/3-pr${T}true${T}spec/decisions/03-fork.md" >"${GHS}/prs"
fp numbers
assert_eq "numbers: ADR number taken by open PRs, own PR skipped, a fork's same-named branch not" "${out}" \
	"numbers${T}taken${T}spec/decisions/0003-mine.md${T}#7${T}spec/decisions/0003-other.md
numbers${T}taken${T}spec/decisions/0003-mine.md${T}#11${T}spec/decisions/03-fork.md"

git -C "${R}" switch -q -c issue/4-untracked origin/main
printf '%s\n' "count${T}1" "file${T}7${T}feat/other${T}false${T}spec/decisions/0003-other.md" >"${GHS}/prs"
printf 'x\n' >"${R}/spec/decisions/0003-new.md"
fp numbers
assert_eq "numbers: an uncommitted new ADR is checked (the /steer:spec adr path)" "${out}" \
	"numbers${T}taken${T}spec/decisions/0003-new.md${T}#7${T}spec/decisions/0003-other.md"
mv "${R}/spec/decisions/0003-new.md" "${R}/spec/decisions/0004-new.md"
fp numbers
assert_eq "numbers: the next number up is clean" "${out}" "numbers${T}clean${T}"
rm -f "${R}/spec/decisions/0004-new.md"

printf '%s\n' "count${T}200" "partial${T}30${T}feat/big${T}false" \
	"file${T}30${T}feat/big${T}false${T}README.md" >"${GHS}/prs"
mkdir -p "${R}/openspec/steer/decisions"
printf 'x\n' >"${R}/openspec/steer/decisions/0002-os.md"
fp numbers
assert_eq "numbers: openspec ADRs share the sequence; truncated PR lists are unchecked" "${out}" \
	"numbers${T}unchecked${T}open PRs: more than 200, the rest not read
numbers${T}unchecked${T}#30: more than 100 files, the rest not read
numbers${T}taken${T}openspec/steer/decisions/0002-os.md${T}origin/main${T}spec/decisions/0002-theirs.md"
rm -rf "${R}/openspec"

cut_branch issue/5-migrations
add "${R}" drizzle/0001_add.sql
add "${R}" drizzle/meta/0001_snapshot.json
add "${R}" app/migrations/0008_y.py
add "${R}" "db/migrations/0004_add col.sql"
add "${R}" app/migrations/0001_squashed_0003_z.py
add "${O}" drizzle/1_main.sql
add "${O}" db/migrations/0004_x.sql
git -C "${O}" push -q origin main
printf '%s\n' "count${T}2" \
	"file${T}40${T}feat/m${T}false${T}app/migrations/08_z.py" \
	"file${T}40${T}feat/m${T}false${T}other/migrations/0008_q.py" \
	"file${T}41${T}feat/n${T}false${T}drizzle/meta/0001_snapshot.json" >"${GHS}/prs"
fp numbers
assert_eq "numbers: Drizzle and Django numbers, leading zeros, a space, per-directory sequences" "${out}" \
	"numbers${T}taken${T}app/migrations/0008_y.py${T}#40${T}app/migrations/08_z.py
numbers${T}taken${T}db/migrations/0004_add col.sql${T}origin/main${T}db/migrations/0004_x.sql
numbers${T}taken${T}drizzle/0001_add.sql${T}origin/main${T}drizzle/1_main.sql"

cut_branch issue/6-pair
add "${R}" drizzle/0005_x.up.sql
add "${R}" drizzle/0005_x.down.sql
printf '%s\n' "count${T}1" "file${T}50${T}feat/parent${T}false${T}drizzle/0005_x.up.sql" \
	"file${T}50${T}feat/parent${T}false${T}drizzle/0005_x.down.sql" >"${GHS}/prs"
fp numbers
assert_eq "numbers: a pair the branch adds itself (inherited from a parent PR) is no collision" "${out}" \
	"numbers${T}clean${T}"

: >"${GHS}/prs"
cut_branch issue/7-rename
git -C "${R}" mv spec/decisions/0001-init.md spec/decisions/0001-start.md
git -C "${R}" commit -q -m "rename slug"
fp numbers
assert_eq "numbers: a slug-only rename keeps its number" "${out}" "numbers${T}clean${T}"
git -C "${R}" mv spec/decisions/0001-start.md spec/decisions/0002-moved.md
git -C "${R}" commit -q -m "renumber"
fp numbers
assert_eq "numbers: a rename onto a number the default branch uses is reported" "${out}" \
	"numbers${T}taken${T}spec/decisions/0002-moved.md${T}origin/main${T}spec/decisions/0002-theirs.md"

fp --remote nope numbers
assert_rc "numbers: no remote exits 0" "${rc}" 0
assert_eq "numbers: no remote -> unchecked" "${out}" "numbers${T}unchecked${T}no remote named nope"
git -C "${R}" remote add off "${WORK}/no-such.git"
git -C "${R}" update-ref refs/remotes/off/main origin/main
git -C "${R}" symbolic-ref refs/remotes/off/HEAD refs/remotes/off/main
fp --remote off numbers
assert_eq "numbers: offline with a new numbered file -> unchecked" "${out}" \
	"numbers${T}unchecked${T}fetch of off/main failed"
git -C "${R}" switch -q issue/1-none
fp --remote off numbers
assert_eq "numbers: offline with nothing numbered added -> silent" "${out}" ""

git -C "${R}" switch -q --orphan issue/8-orphan
add "${R}" spec/decisions/0009-alone.md
fp numbers
assert_eq "numbers: no merge base with the default branch -> unchecked" "${out}" \
	"numbers${T}unchecked${T}no merge base with origin/main"

finish
