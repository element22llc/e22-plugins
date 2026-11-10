#!/usr/bin/env sh
# steer - a change that ships must bring a changelog fragment.
# Rationale: /steer:reference conventions -> "Changelog".
# Deliberately delivery-mode-blind: in solo-trunk there is no PR, so this is the
# only thing between a trunk push and an unrecorded shipped change.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# SCRIPTDIR keeps this resolvable no matter the cwd shellcheck is invoked from -
# a consumer repo lints these from its root and has no .shellcheckrc to lean on.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"

# Paths that ship nothing. Matched against each changed path with `case`.
is_exempt() {
	case "$1" in
	spec/* | docs/* | .github/* | .claude/* | .vscode/* | .changes/*) return 0 ;;
	tests/* | test/* | */tests/* | */test/*) return 0 ;;
	__tests__/* | */__tests__/* | __snapshots__/* | */__snapshots__/*) return 0 ;;
	# Colocated tests. Extensions are listed, not `*.spec.*`, so a shipping
	# `openapi.spec.yaml` still needs its entry.
	*.test.[cm][jt]s | *.test.[jt]s | *.test.[jt]sx) return 0 ;;
	*.spec.[cm][jt]s | *.spec.[jt]s | *.spec.[jt]sx) return 0 ;;
	test_*.py | */test_*.py | *_test.py | conftest.py | */conftest.py) return 0 ;;
	# Prose ships no behaviour, wherever it lives. A docs change that IS worth an
	# entry can still have one - this only says it is never *required*.
	*.md) return 0 ;;
	esac
	return 1
}

# A property of the tree, not the diff, so it runs before the base fail-open:
# changie loads only *.yaml, and drops anything else at merge without a word (#707).
strays="$(find .changes/unreleased -type f ! -name '*.yaml' ! -name '.gitkeep' 2>/dev/null | sort | tr '\n' ' ')"
if [ -n "${strays}" ]; then
	steer_ci_error "Changelog fragment changie cannot read - it loads only *.yaml from .changes/unreleased/, so these would be dropped silently at merge. Recreate each with \`mise run changelog:new\`: ${strays}"
	exit 1
fi

# Promotion carries changes already gated on their way into main, and the cut
# before it consumed their fragments - there is nothing left to add.
if [ "${STEER_CI_EVENT:-}" = pull_request ] && [ "${STEER_CI_BASE_REF:-}" = prod ]; then
	printf 'ci:changelog - promotion to prod; fragments were checked on main.\n'
	exit 0
fi

# A QA fix into a release branch repairs work this release's entries already describe.
case "${STEER_CI_BASE_REF:-}" in
release/*)
	[ "${STEER_CI_EVENT:-}" = pull_request ] && {
		printf 'ci:changelog - QA fix into %s; the release entries cover it.\n' "${STEER_CI_BASE_REF}"
		exit 0
	}
	;;
esac

# A Dependabot bump adds no fragment and cannot take one: dependabot-auto-merge
# refuses a commit that is not Dependabot's, so requiring one would block every bump.
# Same guard as that job: author and pusher both Dependabot.
if [ "${STEER_CI_PR_AUTHOR:-}" = 'dependabot[bot]' ] && [ "${STEER_CI_ACTOR:-}" = 'dependabot[bot]' ]; then
	printf 'ci:changelog - Dependabot dependency bump; no fragment required.\n'
	exit 0
fi

if ! base="$(steer_ci_base)"; then
	steer_ci_notice 'No base ref to diff against - skipping the changelog gate (fail-open).'
	exit 0
fi

if [ ! -f .changie.yaml ]; then
	steer_ci_notice 'No .changie.yaml - repo has no changelog yet. Run /steer:setup sync to install it.'
	exit 0
fi

# A diff that adds a released version file carries a cut that consumed its
# fragments: the back-port of a hotfix that was cut on prod.
cut="$(git -c core.quotePath=false diff --diff-filter=A --name-only "${base}...HEAD" -- ':(glob).changes/*.md' 2>/dev/null ||
	git -c core.quotePath=false diff --diff-filter=A --name-only "${base}" HEAD -- ':(glob).changes/*.md')"
if [ -n "${cut}" ]; then
	printf 'ci:changelog - carries a release cut (%s); its fragments were consumed.\n' "$(printf '%s' "${cut}" | tr '\n' ' ')"
	exit 0
fi

# A back-port of a release's QA fixes: every commit is a `cherry-pick -x` of a commit prod
# ships, and those fixes carry no fragment. The trailer must name a real prod commit.
if git rev-parse --verify --quiet origin/prod >/dev/null 2>&1; then
	commits="$(git rev-list --no-merges "${base}..HEAD" 2>/dev/null || true)"
	backport="${commits:+yes}"
	for c in ${commits}; do
		src="$(git log -1 --format=%B "${c}" | sed -n 's/.*(cherry picked from commit \([0-9a-f]\{40\}\)).*/\1/p' | head -n 1)"
		if [ -z "${src}" ] || ! git merge-base --is-ancestor "${src}" origin/prod 2>/dev/null; then
			backport=''
			break
		fi
	done
	if [ -n "${backport}" ]; then
		printf 'ci:changelog - back-port of commits prod ships; their release covers them.\n'
		exit 0
	fi
fi

changed="$(git -c core.quotePath=false diff --name-only "${base}...HEAD" 2>/dev/null || git -c core.quotePath=false diff --name-only "${base}" HEAD)"

shipping=''
while IFS= read -r path; do
	[ -n "${path}" ] || continue
	is_exempt "${path}" || shipping="${shipping}${path}
"
done <<EOF
${changed}
EOF

if [ -z "${shipping}" ]; then
	printf 'ci:changelog - no shipping paths changed; no fragment required.\n'
	exit 0
fi

added="$(git -c core.quotePath=false diff --diff-filter=A --name-only "${base}...HEAD" -- '.changes/unreleased/*.yaml' 2>/dev/null ||
	git -c core.quotePath=false diff --diff-filter=A --name-only "${base}" HEAD -- '.changes/unreleased/*.yaml')"

if [ -n "${added}" ]; then
	printf 'ci:changelog - fragment present.\n'
	exit 0
fi

steer_ci_error "Shipping code changed but no changelog fragment was added under .changes/unreleased/. Run \`mise run changelog:new\`. Changed:$(printf '%s' "${shipping}" | cut -c1-300)"
exit 1
