#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# The release flow's scaffold scripts: ci-promotion.sh (the prod gate), release-target.sh (the
# non-prod hold), ci-changelog.sh's QA-fix and merge-back paths, and merge-back.sh, over a real
# history with merge commits on prod.
S="${PLUGIN}/templates/scaffold/scripts"
R="${WORK}/repo"
mkdir -p "${R}/scripts" "${R}/src" "${R}/.changes"
cp "${S}/ci-lib.sh" "${S}/ci-promotion.sh" "${S}/ci-changelog.sh" "${S}/release-target.sh" "${S}/merge-back.sh" "${R}/scripts/"
g() { git -C "${R}" -c user.name=t -c user.email=t@t "$@"; }
commit() { # <file> <msg>
	printf '%s\n' "$2" >>"${R}/$1"
	g add -A && g commit -qm "$2"
}
sha() { g rev-parse "$1"; }
promo() { # <head-ref> <head-sha> <prod-sha> -> rc
	(cd "${R}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=prod STEER_CI_HEAD_REF="$1" \
		STEER_CI_HEAD_SHA="$2" STEER_CI_BASE_SHA="$3" sh scripts/ci-promotion.sh >/dev/null 2>&1)
	rc=$?
}

g init -q -b main
: >"${R}/.changie.yaml"
commit src/app.ts base
g branch prod
commit src/app.ts feat1
commit .changes/v1.0.0.md cut1
g switch -q -c release/v1.0.0
commit src/qa.ts qafix1
promo release/v1.0.0 "$(sha HEAD)" "$(sha prod)"
assert_eq "ci-promotion: the first release, cut from main, passes" "${rc}" "0"
g switch -q prod
g merge -q --no-ff --no-edit release/v1.0.0
P1="$(sha prod)"
g switch -q main
commit src/app.ts feat2
g switch -q -c release/v1.1.0

# Head refs: only release/* and hotfix/* reach prod.
promo feat/x "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a feature branch into prod fails" "${rc}" "1"
promo release/v1 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a malformed release name fails" "${rc}" "1"
g update-ref refs/remotes/origin/main main
promo hotfix/12-crash "$(sha prod)" "${P1}"
assert_eq "ci-promotion: a hotfix cut from prod passes" "${rc}" "0"
promo hotfix/13-wrong-base "$(sha main)" "${P1}"
assert_eq "ci-promotion: a hotfix cut from main fails" "${rc}" "1"
(cd "${R}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=main STEER_CI_HEAD_REF=feat/x sh scripts/ci-promotion.sh >/dev/null 2>&1)
assert_eq "ci-promotion: a PR into main is not its business" "$?" "0"

# The next release needs prod merged back into main first, by a merge commit.
promo release/v1.1.0 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a release without the last merge-back fails" "${rc}" "1"
g switch -q -c squashed main
g merge -q --squash prod >/dev/null 2>&1 && g commit -qm "merge-back (squash)"
promo release/v1.1.0 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a squashed merge-back is caught" "${rc}" "1"
BEFORE_MB="$(sha main)"
g switch -q main
g merge -q --no-ff --no-edit prod
g switch -q -C release/v1.1.0 main
promo release/v1.1.0 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: the merged-back release passes" "${rc}" "0"
promo release/abc1234 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a no-version snapshot name passes" "${rc}" "0"

# ci-changelog: a QA fix into a release branch, and a merge-back, need no fragment.
(cd "${R}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=release/v1.1.0 STEER_CI_BASE_SHA="$(sha main~1)" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a QA fix into release/* needs no fragment" "$?" "0"
g update-ref refs/remotes/origin/prod "${P1}"
g switch -q -C mb "${BEFORE_MB}"
g merge -q --no-ff --no-edit prod
(cd "${R}" && STEER_CI_BASE="${BEFORE_MB}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a merge-back of prod needs no fragment" "$?" "0"
commit src/y.ts extra
(cd "${R}" && STEER_CI_BASE="${BEFORE_MB}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a merge-back plus a commit of its own needs one" "$?" "1"
g switch -q -C plain "${BEFORE_MB}"
commit src/z.ts shipping
(cd "${R}" && STEER_CI_BASE="${BEFORE_MB}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: the same change into main still needs one" "$?" "1"

# A hotfix during QA: the bot pushes a merge-back branch per target at prod's tip.
g switch -q -c hotfix/7-crash prod
commit src/hot.ts hotfix7
g switch -q prod
g merge -q --no-ff --no-edit hotfix/7-crash
P2="$(sha prod)"
O="${WORK}/origin.git"
git init -q --bare "${O}"
g remote add origin "${O}"
g push -q origin main prod release/v1.1.0
mkdir -p "${WORK}/bin"
printf '#!/bin/sh\ncase "$1 $2" in\n"pr list") printf "release/v1.1.0" ;;\n"pr comment") cat "$5" >"%s" ;;\nesac\n' "${WORK}/comment" >"${WORK}/bin/gh"
chmod +x "${WORK}/bin/gh"
merge_back() { # <pr> <head-ref> <merge-sha>
	(cd "${R}" && PATH="${WORK}/bin:${PATH}" PR="$1" HEAD_REF="$2" MERGE_SHA="$3" REPO=o/r DEFAULT_BRANCH=main GH_TOKEN=x \
		sh scripts/merge-back.sh >/dev/null 2>&1)
	rc=$?
}
merge_back 7 hotfix/7-crash "${P2}"
assert_eq "merge-back: exits clean" "${rc}" "0"
assert_eq "merge-back: pushes merge-back/7-to-main at prod's tip" "$(git -C "${O}" rev-parse --verify --quiet refs/heads/merge-back/7-to-main)" "${P2}"
assert_eq "merge-back: pushes the open release's at prod's tip" "$(git -C "${O}" rev-parse --verify --quiet refs/heads/merge-back/7-to-release-v1.1.0)" "${P2}"
assert_has "merge-back: comments a link to open the PR" "$(cat "${WORK}/comment" 2>/dev/null)" "compare/main...merge-back/7-to-main"
assert_has "merge-back: asks for a merge commit" "$(cat "${WORK}/comment" 2>/dev/null)" "Create a merge commit"
merge_back 7 hotfix/7-crash "${P2}"
assert_has "merge-back: a re-run reuses the pushed branch" "$(cat "${WORK}/comment" 2>/dev/null)" "already exists from an earlier run"
merge_back 5 release/v1.0.0 "${P1}"
assert_has "merge-back: a target that contains prod is skipped" "$(cat "${WORK}/comment" 2>/dev/null)" "already contains"

promo release/v1.1.0 "$(sha release/v1.1.0)" "${P2}"
assert_eq "ci-promotion: a release missing a hotfix fails" "${rc}" "1"
g switch -q release/v1.1.0
g merge -q --no-ff --no-edit "${P2}"
promo release/v1.1.0 "$(sha HEAD)" "${P2}"
assert_eq "ci-promotion: the hotfix merged back into the release passes" "${rc}" "0"

# release-target.sh: the held environment follows the one open release branch, failing closed.
mkdir -p "${R}/policy"
printf "policy/\n" >>"${R}/.git/info/exclude"
printf '#!/bin/sh\n[ -n "${GH_FAIL:-}" ] && exit 1\nprintf "%%s" "${GH_HEADS:-}"\n' >"${WORK}/bin/gh"
target() { (cd "${R}" && PATH="${WORK}/bin:${PATH}" STEER_DEFAULT_BRANCH=main GH_HEADS="$1" GH_FAIL="${2:-}" sh scripts/release-target.sh 2>/dev/null); }
printf 'release_hold: none\n' >"${R}/policy/delivery.yml"
assert_eq "release-target: hold off runs the default branch" "$(target release/v1.1.0)" "main"
printf 'release_hold: non-prod # held while a release is open\n' >"${R}/policy/delivery.yml"
assert_eq "release-target: no open release runs the default branch" "$(target 'hotfix/7-crash')" "main"
assert_eq "release-target: an open release runs its branch" "$(target 'release/v1.1.0
hotfix/7-crash')" "release/v1.1.0"
target 'release/v1.1.0
release/v1.2.0' >/dev/null
assert_eq "release-target: two open releases fail closed" "$?" "1"
target '' fail >/dev/null
assert_eq "release-target: gh failing fails closed" "$?" "1"

finish
