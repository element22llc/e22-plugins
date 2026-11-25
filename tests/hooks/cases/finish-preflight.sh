#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# scripts/finish-preflight.sh - the /steer:work finish pre-flight. A local bare
# repo stands in for GitHub and a stub `gh` serves PR lists and base-change
# history from files, so every path runs offline.
FP="${PLUGIN}/scripts/finish-preflight.sh"
T="$(printf '\t')"
GHS="${WORK}/gh"
mkdir -p "${WORK}/bin" "${GHS}"
cat >"${WORK}/bin/gh" <<'EOF'
#!/usr/bin/env sh
# Stub gh: `pr list --head H --state S` prints $GHS/<S>-<H, / as _>;
# `api graphql ... -F n=N` prints $GHS/history-N; missing files print nothing.
[ -f "${GHS}/fail" ] && exit 1
case "$1 $2" in
"api graphql")
	[ -f "${GHS}/fail-history" ] && exit 1
	for a in "$@"; do case "${a}" in n=*) n="${a#n=}" ;; esac; done
	cat "${GHS}/history-${n}" 2>/dev/null
	;;
"pr list")
	while [ $# -gt 0 ]; do
		case "$1" in
		--head) h="$(printf '%s' "$2" | tr / _)" ;;
		--state) s="$2" ;;
		esac
		shift
	done
	cat "${GHS}/${s}-${h}" 2>/dev/null
	;;
*) exit 1 ;;
esac
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
assert_eq "finish-preflight: behind and clean -> merge the fetched default branch in" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}
base${T}merge${T}origin/main"

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
base${T}conflict${T}f.txt
base${T}merge${T}origin/main"
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
assert_eq "finish-preflight: --base checks a dependent branch against its parent, up to date" "${out}" \
	"base${T}against${T}origin/feat/parent
base${T}clean${T}"
printf '3 feat/parent\n' >"${GHS}/open-issue_3-stacked"
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
git -C "${O}" switch -q main
commit "${O}" p.txt p2
SQ="$(git -C "${O}" rev-parse HEAD)"
git -C "${O}" push -q origin main :feat/parent
printf 'MERGED 12 main %s\nCLOSED 9 main -\n' "${SQ}" >"${GHS}/all-feat_parent"
merged="base${T}parent-merged${T}feat/parent #12
base${T}against${T}origin/main
base${T}clean${T}
base${T}merge${T}origin/pull/12/head
base${T}merge-ours${T}origin/pull/12/squash"
before="$(state)"
fp
assert_eq "finish-preflight: squash-merged parent -> its last head, then the squash recorded" "${out}" "${merged}"
assert_eq "finish-preflight: a multi-step prediction leaves HEAD, branches, index and tree untouched" "$(state)" "${before}"
git -C "${R}" merge-tree --write-tree HEAD origin/main >/dev/null 2>&1
assert_rc "finish-preflight: (control) merging the default branch alone would conflict" "$?" 1

printf '3 main\n' >"${GHS}/open-issue_3-stacked"
fp
assert_eq "finish-preflight: no base history -> the default branch alone" "${out}" \
	"base${T}against${T}origin/main
base${T}conflict${T}p.txt
base${T}merge${T}origin/main"
printf 'feat/parent main\n' >"${GHS}/history-3"
fp
assert_eq "finish-preflight: a parent hidden by GitHub's retarget is found in the PR's history" "${out}" "${merged}"
printf 'feat/parent batch/fixes\n' >"${GHS}/history-3"
fp
assert_has "finish-preflight: a retarget to another base is not this PR's hidden parent" "${out}" \
	"^base${T}conflict${T}p.txt$"
printf 'feat/parent main\n' >"${GHS}/history-3"
: >"${GHS}/fail-history"
fp
assert_has "finish-preflight: base history unavailable -> unchecked" "${out}" \
	"^base${T}unchecked${T}base history of PR #3: gh unavailable"
rm -f "${GHS}/fail-history"
printf 'MERGED 12 batch/fixes %s\n' "${SQ}" >"${GHS}/all-feat_parent"
fp
assert_eq "finish-preflight: a hidden parent merged elsewhere is left alone, unchecked" "${out}" \
	"base${T}unchecked${T}parent feat/parent merged into batch/fixes, not main: left alone
base${T}against${T}origin/main
base${T}conflict${T}p.txt
base${T}merge${T}origin/main"
printf 'CLOSED 7 main -\n' >"${GHS}/all-feat_parent"
fp
assert_eq "finish-preflight: a hidden parent that closed unmerged is not reported" "${out}" \
	"base${T}against${T}origin/main
base${T}conflict${T}p.txt
base${T}merge${T}origin/main"
printf '3 feat/parent\n' >"${GHS}/open-issue_3-stacked"

printf 'MERGED 12 batch/fixes %s\n' "${SQ}" >"${GHS}/all-feat_parent"
fp
assert_has "finish-preflight: a parent merged into another branch is replaced by that branch" "${out}" \
	"^base${T}against${T}origin/batch/fixes$"
assert_has "finish-preflight: ... and a squash not found there is unchecked" "${out}" \
	"^base${T}unchecked${T}merge commit of feat/parent #12 not found on origin/batch/fixes$"
printf 'MERGED 13 main %s\n' "${SQ}" >"${GHS}/all-feat_parent"
fp
assert_eq "finish-preflight: merged parent head unreachable -> unchecked" "${out}" \
	"base${T}parent-merged${T}feat/parent #13
base${T}against${T}origin/main
base${T}unchecked${T}last head of merged parent feat/parent not fetched"

git -C "${O}" fetch -q origin
git -C "${O}" switch -q -c feat/q origin/main
commit "${O}" q.txt q1
git -C "${O}" push -q origin feat/q HEAD:refs/pull/21/head
git -C "${R}" fetch -q origin
git -C "${R}" switch -q -c issue/7-q origin/feat/q
commit "${R}" q.txt q1-child
git -C "${O}" switch -q main
commit "${O}" w.txt other-work
commit "${O}" q.txt q1
QSQ="$(git -C "${O}" rev-parse HEAD)"
commit "${O}" z.txt later
git -C "${O}" push -q origin main :feat/q
printf 'MERGED 21 main %s\n' "${QSQ}" >"${GHS}/all-feat_q"
printf '7 main\n' >"${GHS}/open-issue_7-q"
printf 'feat/q main\n' >"${GHS}/history-7"
fp
assert_eq "finish-preflight: a child editing its squash-merged parent's lines merges cleanly" "${out}" \
	"base${T}parent-merged${T}feat/q #21
base${T}against${T}origin/main
base${T}clean${T}
base${T}merge${T}origin/pull/21/pre-squash
base${T}merge-ours${T}origin/pull/21/squash
base${T}merge${T}origin/main"
git -C "${R}" merge-tree --write-tree HEAD origin/main >/dev/null 2>&1
assert_rc "finish-preflight: (control) merging the default branch alone would conflict" "$?" 1
commit "${O}" y.txt after-preflight
git -C "${O}" push -q origin main
git -C "${R}" fetch -q origin
git -C "${R}" switch -q -c probe/merge-in
git -C "${R}" merge -q --no-edit origin/pull/21/pre-squash >/dev/null 2>&1 &&
	git -C "${R}" merge -q --no-edit -s ours origin/pull/21/squash >/dev/null 2>&1 &&
	git -C "${R}" merge -q --no-edit origin/main >/dev/null 2>&1
assert_rc "finish-preflight: the printed merges apply cleanly, no history rewrite" "$?" 0
assert_eq "finish-preflight: ... keeping the child's edit and all base work, even after a later fetch" \
	"$(cat "${R}/q.txt") $(cat "${R}/z.txt") $(cat "${R}/y.txt")" "q1-child later after-preflight"
printf '7 main\n' >"${GHS}/open-probe_merge-in"
fp
assert_eq "finish-preflight: a merged hidden parent goes quiet once absorbed" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}"
git -C "${R}" switch -q issue/7-q
git -C "${O}" switch -q feat/q
commit "${O}" q.txt q2
git -C "${O}" push -q origin +HEAD:refs/pull/21/head
fp
assert_eq "finish-preflight: a conflict with the parent's last head stops at that merge" "${out}" \
	"base${T}parent-merged${T}feat/q #21
base${T}against${T}origin/main
base${T}conflict${T}q.txt
base${T}merge${T}origin/pull/21/head"
git -C "${R}" switch -q probe/merge-in
fp
assert_eq "finish-preflight: a branch already holding the squash skips the parent's head" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}"
git -C "${O}" switch -q main

git -C "${O}" switch -q -c feat/r origin/main
commit "${O}" r.txt a
commit "${O}" r2.txt b
git -C "${O}" push -q origin feat/r HEAD:refs/pull/31/head
git -C "${R}" fetch -q origin
git -C "${R}" switch -q -c issue/8-r origin/feat/r
commit "${R}" r.txt a-child
git -C "${O}" switch -q main
commit "${O}" x2.txt meanwhile
git -C "${O}" cherry-pick feat/r~1 feat/r >/dev/null
git -C "${O}" push -q origin main
printf 'MERGED 31 main %s\n' "$(git -C "${O}" rev-parse HEAD)" >"${GHS}/all-feat_r"
fp --base feat/r
assert_eq "finish-preflight: a rebase-merged parent is unchecked, never guessed" "${out}" \
	"base${T}parent-merged${T}feat/r #31
base${T}against${T}origin/main
base${T}unchecked${T}feat/r #31 was rebase-merged: bring the base in by hand"
git -C "${R}" switch -q issue/3-stacked

printf 'MERGED 40 main -\n' >"${GHS}/all-develop"
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
base${T}clean${T}
base${T}merge${T}origin/main"
git -C "${R}" switch -q --detach issue/1-clean
fp
assert_eq "finish-preflight: detached HEAD, no PR lookup" "${out}" \
	"base${T}against${T}origin/main
base${T}clean${T}
base${T}merge${T}origin/main"
git -C "${O}" push -q origin main:refs/heads/prod
fp --base prod
assert_eq "finish-preflight: --base prod is checked, never looked up as a parent" "${out}" \
	"base${T}against${T}origin/prod
base${T}clean${T}
base${T}merge${T}origin/prod"
rm -f "${GHS}/fail"

git -C "${O}" fetch -q origin
git -C "${O}" switch -q -c batch/x origin/main
commit "${O}" x.txt batch
git -C "${O}" push -q origin batch/x
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
printf 'MERGED 50 main %s\n' "$(git -C "${O}" rev-parse origin/batch/x)" >"${GHS}/all-batch_x"
fp --base batch/x
assert_eq "finish-preflight: a merged batch base -> only its new base is merged, from the sibling's own merge base" "${out}" \
	"base${T}parent-merged${T}batch/x #50
base${T}against${T}origin/main
base${T}clean${T}
base${T}merge${T}origin/main"

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
