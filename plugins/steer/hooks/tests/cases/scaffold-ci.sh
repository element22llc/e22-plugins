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
# Back-port: the hotfix PR into prod cut its own patch, so prod -> main adds none either.
(cd "${CC}" && STEER_CI_EVENT=pull_request STEER_CI_BASE_REF=main STEER_CI_HEAD_REF=prod STEER_CI_BASE_SHA="${base_sha}" sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: a prod back-port PR needs no new fragment" "$?" "0"
# A force-push leaves `before` unreachable: fail open, never exit 128.
(cd "${CC}" && STEER_CI_EVENT=push STEER_CI_BEFORE=1111111111111111111111111111111111111111 sh scripts/ci-changelog.sh >/dev/null 2>&1)
assert_eq "ci-changelog: an unreachable push base fails open" "$?" "0"

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
