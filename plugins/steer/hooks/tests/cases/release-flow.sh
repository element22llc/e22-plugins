#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# The release flow's scaffold scripts: ci-promotion.sh (the prod gate and the back-port
# selection), release-target.sh (the non-prod hold), ci-changelog.sh's QA-fix paths and
# backport.sh, over a real history with merge commits on prod.
S="${PLUGIN}/templates/scaffold/scripts"
R="${WORK}/repo"
mkdir -p "${R}/scripts" "${R}/src" "${R}/.changes"
cp "${S}/ci-lib.sh" "${S}/ci-promotion.sh" "${S}/ci-changelog.sh" "${S}/release-target.sh" "${S}/backport.sh" "${R}/scripts/"
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
QA1="$(sha HEAD)"
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
promo hotfix/12-crash "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a hotfix branch passes" "${rc}" "0"
(cd "${R}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=main STEER_CI_HEAD_REF=feat/x sh scripts/ci-promotion.sh >/dev/null 2>&1)
assert_eq "ci-promotion: a PR into main is not its business" "$?" "0"

# The next release lacks the earlier QA fix until main gets its cherry-pick -x.
promo release/v1.1.0 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a release missing an earlier QA fix fails" "${rc}" "1"
out="$(cd "${R}" && sh scripts/ci-promotion.sh --list-missing main "${P1}")"
assert_eq "ci-promotion --list-missing: names the QA fix only" "${out}" "${QA1}"
g switch -q main
g cherry-pick -x "${QA1}" >/dev/null
g switch -q -C release/v1.1.0 main
promo release/v1.1.0 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: the back-ported QA fix satisfies it" "${rc}" "0"
promo release/abc1234 "$(sha HEAD)" "${P1}"
assert_eq "ci-promotion: a no-version snapshot name passes" "${rc}" "0"

# A hotfix during QA must reach the open release; a copy of it on prod is covered by main's back-port.
g switch -q -c hotfix/7-crash prod
commit src/app.ts hotfix7
H7="$(sha HEAD)"
g switch -q prod
g merge -q --no-ff --no-edit hotfix/7-crash
P2="$(sha prod)"
promo release/v1.1.0 "$(sha release/v1.1.0)" "${P2}"
assert_eq "ci-promotion: a release missing a hotfix fails" "${rc}" "1"
g switch -q release/v1.1.0
g cherry-pick -x "${H7}" >/dev/null 2>&1 || { g checkout -q --theirs src/app.ts && g add -A && GIT_EDITOR=true g cherry-pick --continue >/dev/null; }
promo release/v1.1.0 "$(sha HEAD)" "${P2}"
assert_eq "ci-promotion: the hotfix cherry-picked onto the release passes" "${rc}" "0"
g switch -q prod
g merge -q --no-ff --no-edit release/v1.1.0 -X theirs
P3="$(sha prod)"
g switch -q main
g cherry-pick -x "${H7}" >/dev/null 2>&1 || { g checkout -q --theirs src/app.ts && g add -A && GIT_EDITOR=true g cherry-pick --continue >/dev/null; }
commit src/app.ts feat3
promo release/v1.2.0 "$(sha main)" "${P3}"
assert_eq "ci-promotion: a release copy of a hotfix is covered by main's back-port" "${rc}" "0"

# release-target.sh: the held environment follows the one open release branch, failing closed.
mkdir -p "${WORK}/bin" "${R}/policy"
printf "policy/\n" >>"${R}/.git/info/exclude"
printf '#!/bin/sh\n[ -n "${GH_FAIL:-}" ] && exit 1\nprintf "%%s" "${GH_HEADS:-}"\n' >"${WORK}/bin/gh"
chmod +x "${WORK}/bin/gh"
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

# ci-changelog: a QA fix into a release branch, and a pure back-port, need no fragment.
g switch -q -C probe main~1
commit src/x.ts shipping
(cd "${R}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=release/v1.2.0 sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a QA fix into release/* needs no fragment" "$?" "0"
g update-ref refs/remotes/origin/prod "${P3}"
BEFORE_QA="$(sha main~3)"
g switch -q -C bp "${BEFORE_QA}"
g cherry-pick -x "${QA1}" >/dev/null
(cd "${R}" && STEER_CI_BASE="${BEFORE_QA}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a back-port of a prod QA fix needs no fragment" "$?" "0"
commit src/y.ts extra
(cd "${R}" && STEER_CI_BASE="${BEFORE_QA}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a back-port plus an unrelated commit still needs one" "$?" "1"
g switch -q -C forged "${BEFORE_QA}"
printf 'z\n' >>"${R}/src/z.ts"
g add -A && g commit -qm "forged

(cherry picked from commit 0123456789abcdef0123456789abcdef01234567)"
(cd "${R}" && STEER_CI_BASE="${BEFORE_QA}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a trailer naming no prod commit is no back-port" "$?" "1"

# backport.sh: pushes backport/* for main and the open release, then comments the links.
O="${WORK}/origin.git"
git init -q --bare "${O}"
g remote add origin "${O}"
g push -q origin main prod release/v1.1.0
g switch -q -c hotfix/9-leak prod
commit src/leak.ts hotfix9
g switch -q prod
g merge -q --no-ff --no-edit hotfix/9-leak
g push -q origin prod
g fetch -q origin
printf '#!/bin/sh\ncase "$1 $2" in\n"pr list") printf "release/v1.1.0" ;;\n"pr comment") cat "$5" >"%s" ;;\nesac\n' "${WORK}/comment" >"${WORK}/bin/gh"
(cd "${R}" && PATH="${WORK}/bin:${PATH}" PR=9 HEAD_REF=hotfix/9-leak MERGE_SHA="$(sha prod)" REPO=o/r DEFAULT_BRANCH=main GH_TOKEN=x \
	sh scripts/backport.sh >/dev/null 2>&1)
assert_eq "backport: exits clean" "$?" "0"
git -C "${O}" rev-parse --verify --quiet refs/heads/backport/9-to-main >/dev/null && ok || bad "backport: pushed backport/9-to-main"
git -C "${O}" rev-parse --verify --quiet refs/heads/backport/9-to-release-v1.1.0 >/dev/null && ok || bad "backport: pushed the open release's back-port"
git -C "${O}" log -1 --format=%B backport/9-to-main | grep -q 'cherry picked from commit' && ok || bad "backport: cherry-picks with -x"
assert_has "backport: comments a link to open the PR" "$(cat "${WORK}/comment" 2>/dev/null)" "compare/main...backport/9-to-main"

finish
