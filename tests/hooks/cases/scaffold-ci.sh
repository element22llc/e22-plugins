#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ci-iac: a mise shim satisfies `command -v tofu` with no root pin, then errors
# when run - the gate must skip on a tofu that does not resolve, not fail (#657).
CI="${WORK}/ciiac"
mkdir -p "${CI}/scripts" "${CI}/bin"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lib.sh" "${PLUGIN}/templates/scaffold/scripts/ci-iac.sh" "${CI}/scripts/"
(cd "${CI}" && git init -q && : >main.tf && git add main.tf)
printf '#!/bin/sh
echo "mise ERROR No version is set for shim: tofu" >&2
exit 1
' >"${CI}/bin/tofu"
chmod +x "${CI}/bin/tofu"
out="$(cd "${CI}" && PATH="${CI}/bin:${PATH}" sh scripts/ci-iac.sh 2>&1)"
assert_eq "ci-iac: unpinned tofu shim skips" "$?" "0"
case "${out}" in *"Skipping the root format check"*) ok ;; *) bad "ci-iac: unpinned shim takes the skip branch (got '${out}')" ;; esac
printf '#!/bin/sh
echo "tofu $*"
' >"${CI}/bin/tofu"
out="$(cd "${CI}" && PATH="${CI}/bin:${PATH}" sh scripts/ci-iac.sh 2>&1)"
case "${out}" in *"tofu fmt -check"*) ok ;; *) bad "ci-iac: resolvable tofu runs fmt (got '${out}')" ;; esac

# ci-iac: one yamllint config is enough to run yamllint.
AN="${WORK}/ciiac-ansible"
mkdir -p "${AN}/scripts" "${AN}/bin"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lib.sh" "${PLUGIN}/templates/scaffold/scripts/ci-iac.sh" "${AN}/scripts/"
(cd "${AN}" && git init -q && : >ansible.cfg)
printf '#!/bin/sh
echo "uvx $*"
' >"${AN}/bin/uvx"
chmod +x "${AN}/bin/uvx"
out="$(cd "${AN}" && PATH="${AN}/bin:${PATH}" sh scripts/ci-iac.sh 2>&1)"
case "${out}" in *"uvx yamllint"*) bad "ci-iac: no yamllint config skips yamllint (got '${out}')" ;; *"uvx ansible-lint"*) ok ;; *) bad "ci-iac: ansible-lint runs (got '${out}')" ;; esac
: >"${AN}/.yamllint.yml"
out="$(cd "${AN}" && PATH="${AN}/bin:${PATH}" sh scripts/ci-iac.sh 2>&1)"
case "${out}" in *"uvx yamllint"*) ok ;; *) bad "ci-iac: a lone .yamllint.yml runs yamllint (got '${out}')" ;; esac

# ci-changelog: colocated tests ship nothing, so a test-only PR needs no fragment (#661).
CC="${WORK}/cichangelog"
mkdir -p "${CC}/scripts" "${CC}/src"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lib.sh" "${PLUGIN}/templates/scaffold/scripts/ci-changelog.sh" "${CC}/scripts/"
(cd "${CC}" && git init -q && : >.changie.yaml && git add . && git -c user.name=t -c user.email=t@t commit -qm base)
ci_changelog() { # <path>... -> rc of the gate on a commit adding those paths
	(cd "${CC}" && git checkout -q -B probe "$(git rev-list --max-parents=0 HEAD)" &&
		for p in "$@"; do mkdir -p "$(dirname "$p")" && : >"$p"; done &&
		git add -A && git -c user.name=t -c user.email=t@t commit -qm probe)
	(cd "${CC}" && STEER_CI_BASE=probe~1 sh scripts/ci-changelog.sh >/dev/null 2>&1)
	rc=$?
}
ci_changelog src/foo.test.ts src/foo.test.tsx src/bar.spec.ts src/x.int.test.mjs src/__tests__/a.ts src/test_a.py
assert_eq "ci-changelog: colocated tests need no fragment" "${rc}" "0"
ci_changelog src/foo.ts src/foo.test.ts
assert_eq "ci-changelog: source beside its test still needs one" "${rc}" "1"
ci_changelog api/openapi.spec.yaml
assert_eq "ci-changelog: a non-test *.spec.* file still needs one" "${rc}" "1"
# changie loads only *.yaml: anything else is dropped at merge, so it never counts (#707).
ci_changelog src/foo.ts .changes/unreleased/fixed-a.yaml
assert_eq "ci-changelog: a .yaml fragment satisfies it" "${rc}" "0"
# A hotfix merge-back carries the patch cut made on prod, which consumed its fragment.
ci_changelog src/foo.ts .changes/v1.2.1.md
assert_eq "ci-changelog: a merged-back release cut needs no new fragment" "${rc}" "0"
ci_changelog src/foo.ts .changes/unreleased/fixed-a.md
assert_eq "ci-changelog: a .md 'fragment' fails" "${rc}" "1"
ci_changelog src/foo.ts .changes/unreleased/fixed-a.yaml .changes/unreleased/fixed-b.yml
assert_eq "ci-changelog: a stray .yml beside a real fragment fails" "${rc}" "1"
(cd "${CC}" && STEER_CI_BASE=nope sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a stray fails even with no base" "$?" "1"
# PR base resolves locally, with no reachable origin: merge-ref parent, then base SHA (#707).
(cd "${CC}" && git checkout -q -B pr "$(git rev-list --max-parents=0 HEAD)" && mkdir -p src && : >src/pr.ts &&
	git add -A && git -c user.name=t -c user.email=t@t commit -qm pr &&
	git checkout -q -B merge "$(git rev-list --max-parents=0 HEAD)" &&
	git -c user.name=t -c user.email=t@t merge -q --no-ff --no-edit pr)
head_sha="$(cd "${CC}" && git rev-parse pr)"
base_sha="$(cd "${CC}" && git rev-list --max-parents=0 HEAD)"
(cd "${CC}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=main STEER_CI_HEAD_SHA="${head_sha}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: PR base from the merge ref's first parent" "$?" "1"
(cd "${CC}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=main STEER_CI_HEAD_SHA=deadbeef STEER_CI_BASE_SHA="${base_sha}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: wrong head SHA falls through to the base SHA" "$?" "1"
(cd "${CC}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=main sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: nothing resolvable still fails open" "$?" "0"
# Promotion: the cut already consumed the fragments, so main -> prod adds none.
(cd "${CC}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=prod STEER_CI_BASE_SHA="${base_sha}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a promotion PR to prod needs no new fragment" "$?" "0"
# A force-push leaves `before` unreachable: fail open, never exit 128.
(cd "${CC}" && STEER_CI_EVENT=push STEER_CI_BEFORE=1111111111111111111111111111111111111111 sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: an unreachable push base fails open" "$?" "0"

# ci-changelog: git quotes non-ASCII paths unless told not to, which broke the
# exempt-path match; a Dependabot PR is exempt (auto-merge refuses a human commit).
ci_changelog "spec/sources/$(printf 'r\303\251sum\303\251').pdf" "docs/$(printf '\303\251t\303\251').md"
assert_eq "ci-changelog: exempt paths with accented names need no fragment" "${rc}" "0"
ci_changelog package.json
assert_eq "ci-changelog: a dependency bump by a human still needs one" "${rc}" "1"
(cd "${CC}" && STEER_CI_BASE=probe~1 STEER_CI_PR_AUTHOR='dependabot[bot]' STEER_CI_ACTOR='dependabot[bot]' sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a Dependabot PR needs no fragment" "$?" "0"
(cd "${CC}" && STEER_CI_BASE=probe~1 STEER_CI_PR_AUTHOR='dependabot[bot]' STEER_CI_ACTOR=someone sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a human push onto a Dependabot PR still needs one" "$?" "1"

# ci-coverage: per-package lcov paths reach diff-cover rebased onto the package.
CV="${WORK}/cicoverage"
mkdir -p "${CV}/scripts" "${CV}/bin" "${CV}/apps/web/coverage" "${CV}/coverage"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lib.sh" "${PLUGIN}/templates/scaffold/scripts/ci-coverage.sh" "${CV}/scripts/"
(cd "${CV}" && git init -q && : >a && git add a && git -c user.name=t -c user.email=t@t commit -qm base)
printf 'SF:src/a.ts\nDA:1,0\nend_of_record\nSF:./src/b.ts\nend_of_record\nSF:apps/web/src/c.ts\nend_of_record\nSF:/abs/d.ts\nend_of_record\n' >"${CV}/apps/web/coverage/lcov.info"
printf 'SF:lib/root.ts\nend_of_record\n' >"${CV}/coverage/lcov.info"
printf '#!/bin/sh\nfor a in "$@"; do case "$a" in *.info) grep "^SF:" "$a" ;; esac; done\n' >"${CV}/bin/uvx"
chmod +x "${CV}/bin/uvx"
out="$(cd "${CV}" && PATH="${CV}/bin:${PATH}" STEER_CI_BASE=HEAD sh scripts/ci-coverage.sh 2>&1)"
assert_eq "ci-coverage: package lcov paths rebased, root and absolute ones kept" \
	"$(printf '%s' "${out}" | grep '^SF:' | sort | tr '\n' ' ')" \
	"SF:/abs/d.ts SF:apps/web/src/a.ts SF:apps/web/src/b.ts SF:apps/web/src/c.ts SF:lib/root.ts "

# changelog:new: argv reaches changie verbatim, no shell in between (#671).
if command -v node >/dev/null 2>&1; then
	CN="${WORK}/changelognew"
	mkdir -p "${CN}/bin"
	printf '#!/bin/sh\nfor a in "$@"; do printf "[%%s]" "$a"; done\n' >"${CN}/bin/changie"
	chmod +x "${CN}/bin/changie"
	out="$(PATH="${CN}/bin:${PATH}" KIND=Fixed SLUG=a-b BODY="it's \"q\" & <x> | y" node "${PLUGIN}/templates/scaffold/scripts/changelog-new.mjs" 2>&1)"
	assert_eq "changelog:new: argv passed verbatim" "${out}" "[new][-k][Fixed][-m][Slug=a-b][-b][it's \"q\" & <x> | y]"
	out="$(env -u KIND -u SLUG BODY=x node "${PLUGIN}/templates/scaffold/scripts/changelog-new.mjs" 2>&1)"
	assert_eq "changelog:new: missing vars exit 1" "$?" "1"
	case "${out}" in *"pass --kind"*"pass --slug"*) ok ;; *) bad "changelog:new: one hint per missing var (got '${out}')" ;; esac
	# --kind/--slug/--body reach the script as mise's usage_* vars and win over the env fallback.
	out="$(PATH="${CN}/bin:${PATH}" KIND=Added usage_kind=Fixed usage_slug=c-d usage_body=z node "${PLUGIN}/templates/scaffold/scripts/changelog-new.mjs" 2>&1)"
	assert_eq "changelog:new: usage flags passed through" "${out}" "[new][-k][Fixed][-m][Slug=c-d][-b][z]"
fi

finish

# steer_ci_actions_lock: CI verifies provenance online, a laptop checks coverage offline
# when the extension is installed, and a repo without workflows never calls gh.
AL="${WORK}/cilock"
mkdir -p "${AL}/scripts" "${AL}/bin"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lib.sh" "${AL}/scripts/"
printf '#!/bin/sh
echo "$*" >>"${AL_LOG}"
case "$*" in
"actions-lock --help") [ -n "${AL_HAS_EXT:-}" ] ;;
"extension install"*) exit 0 ;;
"actions-lock --verify"*) exit "${AL_RC:-0}" ;;
*) exit 9 ;;
esac
' >"${AL}/bin/gh"
chmod +x "${AL}/bin/gh"
AL_LOG="${AL}/gh.log"
AL_VER="$(sed -n 's/^STEER_ACTIONS_LOCK_VERSION=//p' "${AL}/scripts/ci-lib.sh")"
export AL_LOG
actions_lock() { # [VAR=value...] -> rc, out, calls
	: >"${AL_LOG}"
	out="$(cd "${AL}" && env PATH="${AL}/bin:${PATH}" "$@" sh -c '. scripts/ci-lib.sh; steer_ci_actions_lock' 2>&1)"
	rc=$?
	calls="$(tr '\n' '|' <"${AL_LOG}")"
}
actions_lock STEER_CI_ACTIONS_LOCK=verify
assert_eq "actions-lock: no workflows passes" "${rc}" "0"
assert_eq "actions-lock: no workflows never calls gh" "${calls}" ""
mkdir -p "${AL}/.github/workflows" && : >"${AL}/.github/workflows/ci.yml"
actions_lock STEER_CI_ACTIONS_LOCK=verify
assert_eq "actions-lock: CI passes on a current lock" "${rc}" "0"
assert_eq "actions-lock: CI installs the pinned extension, then verifies online" "${calls}" "actions-lock --help|extension install github/gh-actions-lock --pin ${AL_VER}|actions-lock --verify|"
actions_lock STEER_CI_ACTIONS_LOCK=verify AL_HAS_EXT=1 AL_RC=1
assert_eq "actions-lock: a stale lock fails CI" "${rc}" "1"
case "${out}" in *"Run 'gh actions-lock'"*) ok ;; *) bad "actions-lock: failure says how to fix it (got '${out}')" ;; esac
actions_lock AL_HAS_EXT=1
assert_eq "actions-lock: locally an installed extension checks offline" "${calls}" "actions-lock --help|actions-lock --verify-local|"
actions_lock
assert_eq "actions-lock: locally without the extension passes" "${rc}" "0"
case "${out}" in *"CI alone checks the actions lockfile"*) ok ;; *) bad "actions-lock: missing extension is a notice (got '${out}')" ;; esac
