#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# scripts/pr-assets.sh - the /steer:work qa image host. A local bare repo stands
# in for GitHub: the push lands on refs/steer-assets/<key>, never on a branch.
PA="${PLUGIN}/scripts/pr-assets.sh"
U=https://github.com/acme/app
if command -v git >/dev/null 2>&1; then
	PA_R="$(git_repo paRepo main)"
	git init -q --bare "${WORK}/pa-origin.git"
	git -C "${PA_R}" remote add origin "${WORK}/pa-origin.git"
	printf 'before' >"${WORK}/login-before.png"
	printf 'after' >"${WORK}/login-after.png"
	pa() { out="$(cd "${PA_R}" && sh "${PA}" "$@" 2>/dev/null)" && rc=0 || rc=$?; }

	pa "${U}/" issue/7-login "${WORK}/login-before.png" "${WORK}/login-after.png"
	assert_rc "pr-assets: first push" "${rc}" 0
	tip="$(git -C "${WORK}/pa-origin.git" rev-parse refs/steer-assets/issue/7-login)"
	assert_eq "pr-assets: one line per file, blob?raw URL pinned to the pushed SHA" "${out}" \
		"$(printf 'login-before.png\t%s/blob/%s/login-before.png?raw=true\nlogin-after.png\t%s/blob/%s/login-after.png?raw=true' "${U}" "${tip}" "${U}" "${tip}")"
	assert_eq "pr-assets: file content in the commit" \
		"$(git -C "${WORK}/pa-origin.git" show "${tip}:login-after.png")" after
	assert_eq "pr-assets: orphan commit, no branch touched" \
		"$(git -C "${WORK}/pa-origin.git" for-each-ref --format='%(refname)' refs/heads)" ""

	pa "${U}" issue/7-login "${WORK}/login-after.png"
	assert_rc "pr-assets: re-run on the same key" "${rc}" 0
	assert_eq "pr-assets: re-run fast-forwards, earlier URLs stay reachable" \
		"$(git -C "${WORK}/pa-origin.git" rev-parse "refs/steer-assets/issue/7-login^")" "${tip}"

	pa "${U}" issue/7-login "${WORK}/missing.png"
	assert_rc "pr-assets: missing file refused" "${rc}" 2
	pa git@github.com:acme/app.git issue/7-login "${WORK}/login-after.png"
	assert_rc "pr-assets: non-https repo URL refused" "${rc}" 2
	pa "${U}" 'bad..key' "${WORK}/login-after.png"
	assert_rc "pr-assets: invalid ref name refused" "${rc}" 2
	pa "${U}" issue/7-login "${WORK}/login-after.png" "${WORK}/login-after.png"
	assert_rc "pr-assets: duplicate file name refused" "${rc}" 2
	pa --remote nope "${U}" issue/7-login "${WORK}/login-after.png"
	assert_rc "pr-assets: unreachable remote is a git failure" "${rc}" 5
fi

finish
