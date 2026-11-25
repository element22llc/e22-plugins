#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# scripts/finish-preflight.sh - the /steer:work finish pre-flight. A local bare
# repo stands in for GitHub and a stub `gh` serves PR lists from files, so every
# path runs offline.
FP="${PLUGIN}/scripts/finish-preflight.sh"
T="$(printf '\t')"
GHS="${WORK}/gh"
mkdir -p "${WORK}/bin" "${GHS}"
cat >"${WORK}/bin/gh" <<'EOF'
#!/usr/bin/env sh
# Stub gh: `pr list --head H --state S` prints $GHS/<S>-<H, / as _>, or nothing.
[ -f "${GHS}/fail" ] && exit 1
[ "$1 $2" = "pr list" ] || exit 1
while [ $# -gt 0 ]; do
	case "$1" in
	--head) h="$(printf '%s' "$2" | tr / _)" ;;
	--state) s="$2" ;;
	esac
	shift
done
cat "${GHS}/${s}-${h}" 2>/dev/null
exit 0
EOF
chmod +x "${WORK}/bin/gh"
export GHS
PATH="${WORK}/bin:${PATH}"
export PATH
[ "$(command -v gh)" = "${WORK}/bin/gh" ] || {
	bad "finish-preflight: stub gh is not first on PATH"
	finish
}
command -v git >/dev/null 2>&1 || finish

git init -q --bare "${WORK}/fp-origin.git"
git -C "${WORK}/fp-origin.git" symbolic-ref HEAD refs/heads/main
R="$(git_repo fpRepo main)"
git -C "${R}" remote add origin "${WORK}/fp-origin.git"
commit() { # <repo> <file> <content>
	printf '%s\n' "$3" >"$1/$2"
	git -C "$1" add "$2" && git -C "$1" commit -q -m "$2=$3"
}
commit "${R}" f.txt base
git -C "${R}" push -q origin main
O="${WORK}/fpOther"
git clone -q "${WORK}/fp-origin.git" "${O}" 2>/dev/null
git -C "${O}" config user.email t@e.com
git -C "${O}" config user.name t
fp() { out="$(cd "${R}" && sh "${FP}" "$@" 2>/dev/null)" && rc=0 || rc=$?; }
state() { printf '%s|%s|%s|%s' "$(git -C "${R}" rev-parse HEAD)" "$(git -C "${R}" symbolic-ref -q HEAD)" \
	"$(git -C "${R}" for-each-ref --format='%(refname) %(objectname)' refs/heads)" "$(git -C "${R}" status --porcelain)"; }

git -C "${R}" switch -q -c issue/1-clean main
commit "${R}" g.txt feat
commit "${O}" h.txt main-moved
git -C "${O}" push -q origin main
fp
assert_rc "finish-preflight: clean run exits 0" "${rc}" 0
assert_eq "finish-preflight: clean against the fetched default branch" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}"

git -C "${R}" switch -q -c issue/2-conflict main
commit "${R}" f.txt feat
commit "${R}" "a b.txt" feat
commit "${O}" f.txt main
commit "${O}" "a b.txt" main
git -C "${O}" push -q origin main
before="$(state)"
fp base
assert_rc "finish-preflight: a conflict is a finding, not a failure" "${rc}" 0
assert_eq "finish-preflight: every conflicting path reported" "${out}" \
	"base${T}against${T}origin/main
base${T}conflict${T}a b.txt
base${T}conflict${T}f.txt"
assert_eq "finish-preflight: HEAD, branches, index and tree untouched" "$(state)" "${before}"
assert_eq "finish-preflight: the base was freshly fetched" \
	"$(git -C "${R}" rev-parse origin/main)" "$(git -C "${O}" rev-parse main)"

git -C "${O}" fetch -q origin
git -C "${O}" switch -q -c feat/parent origin/main
commit "${O}" p.txt p1
git -C "${O}" push -q origin feat/parent main:refs/heads/batch/fixes main:refs/heads/develop
git -C "${R}" fetch -q origin
git -C "${R}" switch -q -c issue/3-stacked origin/feat/parent
commit "${R}" s.txt child
printf 'OPEN 5 %s main\n' "$(git -C "${O}" rev-parse HEAD)" >"${GHS}/all-feat_parent"
fp --base feat/parent
assert_eq "finish-preflight: --base checks a dependent branch against its parent" "${out}" \
	"base${T}against${T}origin/feat/parent
base${T}clean${T}"
printf 'feat/parent\n' >"${GHS}/open-issue_3-stacked"
fp
assert_eq "finish-preflight: an open PR's base is the stack parent" "${out}" \
	"base${T}against${T}origin/feat/parent
base${T}clean${T}"

printf 'CLOSED 7 %s main\n' "$(git -C "${O}" rev-parse HEAD)" >"${GHS}/all-feat_parent"
fp --base feat/parent
assert_eq "finish-preflight: closed parent reported, still checked against it" "${out}" \
	"base${T}parent-closed${T}feat/parent #7
base${T}against${T}origin/feat/parent
base${T}clean${T}"

commit "${O}" p.txt p2
git -C "${O}" push -q origin HEAD:refs/pull/12/head
P2="$(git -C "${O}" rev-parse HEAD)"
git -C "${O}" switch -q main
commit "${O}" p.txt p2
git -C "${O}" push -q origin main :feat/parent
printf 'MERGED 12 %s main\nCLOSED 9 %s main\n' "${P2}" "${P2}" >"${GHS}/all-feat_parent"
fp
assert_has "finish-preflight: merged parent reported with its head" "${out}" \
	"^base${T}parent-merged${T}feat/parent #12 ${P2}$"
assert_has "finish-preflight: a merged parent is replaced by the default branch" "${out}" \
	"^base${T}against${T}origin/main$"
assert_has "finish-preflight: merged from the fork point, no squash-merge false conflict" "${out}" \
	"^base${T}clean${T}$"
git -C "${R}" merge-tree --write-tree HEAD origin/main >/dev/null 2>&1
assert_rc "finish-preflight: (control) a naive merge-tree would conflict" "$?" 1
printf 'MERGED 12 %s batch/fixes\n' "${P2}" >"${GHS}/all-feat_parent"
fp
assert_has "finish-preflight: a parent merged into another branch is replaced by that branch" "${out}" \
	"^base${T}against${T}origin/batch/fixes$"
printf 'MERGED 13 %s main\n' 0123456789012345678901234567890123456789 >"${GHS}/all-feat_parent"
fp
assert_eq "finish-preflight: merged parent head unreachable -> unchecked" "${out}" \
	"base${T}parent-merged${T}feat/parent #13 0123456789012345678901234567890123456789
base${T}unchecked${T}head 0123456789012345678901234567890123456789 of merged parent feat/parent not fetched"

printf 'MERGED 40 %s main\n' "${P2}" >"${GHS}/all-develop"
fp --base develop
assert_eq "finish-preflight: a long-lived base is never a stack parent" "${out}" \
	"base${T}against${T}origin/develop
base${T}clean${T}"

fp --base batch/fixes
assert_eq "finish-preflight: a base with no PR is checked, nothing else reported" "${out}" \
	"base${T}against${T}origin/batch/fixes
base${T}clean${T}"

: >"${GHS}/fail"
fp --base batch/fixes
assert_eq "finish-preflight: gh failing on the parent lookup -> unchecked, merge-tree still runs" "${out}" \
	"base${T}unchecked${T}PR state of parent batch/fixes: gh unavailable
base${T}against${T}origin/batch/fixes
base${T}clean${T}"
fp
assert_has "finish-preflight: gh failing on the PR base lookup -> unchecked" "${out}" \
	"^base${T}unchecked${T}PR base of issue/3-stacked: gh unavailable"
assert_has "finish-preflight: ... and still checks the default branch" "${out}" "^base${T}against${T}origin/main$"
git -C "${R}" switch -q main
fp
assert_eq "finish-preflight: on the default branch, no PR lookup" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}"
git -C "${R}" switch -q --detach issue/1-clean
fp
assert_eq "finish-preflight: detached HEAD, no PR lookup" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}"
git -C "${O}" push -q origin main:refs/heads/prod
fp --base prod
assert_eq "finish-preflight: --base prod is checked, never looked up as a parent" "${out}" \
	"base${T}against${T}origin/prod
base${T}clean${T}"
rm -f "${GHS}/fail"

git -C "${O}" fetch -q origin
git -C "${O}" switch -q -c batch/x origin/main
commit "${O}" x.txt batch
git -C "${O}" push -q origin batch/x
BX="$(git -C "${O}" rev-parse HEAD)"
git -C "${O}" switch -q main
git -C "${O}" pull -q --no-rebase origin main
commit "${O}" m.txt m1
git -C "${O}" push -q origin main
git -C "${R}" fetch -q origin
git -C "${R}" switch -q -c issue/5-sibling origin/main
commit "${R}" c.txt sibling
commit "${O}" m.txt m2
commit "${O}" x.txt batch
git -C "${O}" push -q origin main
printf 'MERGED 50 %s main\n' "${BX}" >"${GHS}/all-batch_x"
fp --base batch/x
assert_eq "finish-preflight: a merged batch base is replaced, from the sibling's own merge base" "${out}" \
	"base${T}parent-merged${T}batch/x #50 ${BX}
base${T}against${T}origin/main
base${T}clean${T}"

fp --remote nope
assert_eq "finish-preflight: no remote -> unchecked" "${out}" "base${T}unchecked${T}no remote named nope"
git -C "${R}" remote add gone "${WORK}/no-such.git"
fp --remote gone
assert_rc "finish-preflight: unreachable remote exits 0" "${rc}" 0
assert_eq "finish-preflight: unreachable remote -> unchecked" "${out}" \
	"base${T}unchecked${T}gone unreachable or has no default branch"

fp nope
assert_rc "finish-preflight: unknown check refused" "${rc}" 2
fp --base
assert_rc "finish-preflight: --base needs a value" "${rc}" 2
fp --remote --upload-pack=x
assert_rc "finish-preflight: option-shaped remote refused" "${rc}" 2
mkdir -p "${WORK}/notgit"
out="$(cd "${WORK}/notgit" && GIT_CEILING_DIRECTORIES="${WORK}" sh "${FP}" 2>/dev/null)" && rc=0 || rc=$?
assert_rc "finish-preflight: outside a work tree" "${rc}" 3

finish
