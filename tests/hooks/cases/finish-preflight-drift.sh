#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# scripts/finish-preflight.sh `drift` - the drift boxes the diff implies vs the
# boxes ticked in the PR body. A local bare repo stands in for GitHub; bodies
# are built from the shipped PR template so a renamed box fails here.
FP="${PLUGIN}/scripts/finish-preflight.sh"
TPL="${PLUGIN}/templates/github/pull_request_template.md"
T="$(printf '\t')"
mkdir -p "${WORK}/bin"
printf '#!/usr/bin/env sh\nexit 1\n' >"${WORK}/bin/gh"
chmod +x "${WORK}/bin/gh"
PATH="${WORK}/bin:${PATH}"
export PATH
command -v git >/dev/null 2>&1 || finish

for l in "Contract drift" "Operational" "Local setup / deployment changed" \
	"App docs invalidated" "Architecture/stack drift"; do
	grep -Fq -- "- [ ] **${l}**" "${TPL}" && ok || bad "finish-preflight-drift: the template has no '${l}' box"
done

git init -q --bare "${WORK}/fd-origin.git"
git -C "${WORK}/fd-origin.git" symbolic-ref HEAD refs/heads/main
R="$(git_repo fdRepo main)"
git -C "${R}" remote add origin "${WORK}/fd-origin.git"
put() { # <repo> <path> <content> - write and commit
	mkdir -p "$(dirname -- "$1/$2")"
	printf '%s\n' "$3" >"$1/$2"
	git -C "$1" add "$2" && git -C "$1" commit -q -m "$2"
}
put "${R}" spec/features/a/contract.md v1
put "${R}" spec/app/usage.md v1
git -C "${R}" push -q origin main
O="${WORK}/fdOther"
git clone -q "${WORK}/fd-origin.git" "${O}" 2>/dev/null
git -C "${O}" config user.email t@e.com
git -C "${O}" config user.name t

B="${WORK}/body.md"
tick() { # <label> - stdin body -> stdout with that box ticked
	awk -v l="**$1**" 'index($0, "- [ ] " l) == 1 { sub(/\[ \]/, "[x]") } { print }'
}
fp() { out="$(cd "${R}" && sh "${FP}" "$@" 2>/dev/null)" && rc=0 || rc=$?; }
state() { printf '%s|%s|%s' "$(git -C "${R}" rev-parse HEAD)" "$(git -C "${R}" symbolic-ref -q HEAD)" \
	"$(git -C "${R}" status --porcelain)"; }

git -C "${R}" switch -q -c issue/1-ops main
put "${R}" .github/workflows/ci.yml ci
put "${R}" g.txt plain
cp "${TPL}" "${B}"
before="$(state)"
fp --body "${B}" drift
assert_rc "finish-preflight-drift: a finding exits 0" "${rc}" 0
assert_eq "finish-preflight-drift: a touched path class with its box unticked is reported" "${out}" \
	"drift${T}unticked${T}Operational${T}.github/workflows/ci.yml${T}1"
assert_eq "finish-preflight-drift: HEAD, index and tree untouched" "$(state)" "${before}"
tick Operational <"${TPL}" >"${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: ticked and touched -> clean" "${out}" "drift${T}clean${T}"
tick Operational <"${TPL}" | tick "Architecture/stack drift" | tick "Security-sensitive" >"${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: a ticked box no path implies -> confirm; a non-derivable box is never reported" \
	"${out}" "drift${T}confirm${T}Architecture/stack drift"

git -C "${R}" switch -q -c issue/2-all main
put "${R}" spec/features/a/contract.md v2
put "${R}" spec/features/b/contract.md new
put "${R}" apps/web/Dockerfile from
put "${R}" infra/main.tf tf
put "${R}" compose.override.yaml c
put "${R}" .env.example e
put "${R}" spec/app/usage.md v2
put "${R}" docs/ARCHITECTURE.md a
cp "${TPL}" "${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: every derivable class, in template order; an added contract is not drift" "${out}" \
	"drift${T}unticked${T}Contract drift${T}spec/features/a/contract.md${T}1
drift${T}unticked${T}Operational${T}apps/web/Dockerfile${T}2
drift${T}unticked${T}Local setup / deployment changed${T}.env.example${T}2
drift${T}unticked${T}App docs invalidated${T}spec/app/usage.md${T}1
drift${T}unticked${T}Architecture/stack drift${T}docs/ARCHITECTURE.md${T}1"
for l in "Contract drift" "Operational" "Local setup / deployment changed" \
	"App docs invalidated" "Architecture/stack drift"; do
	tick "${l}" <"${B}" >"${B}.t" && mv "${B}.t" "${B}"
done
sed 's/\[x\]/[X]/; s/$/\r/' "${B}" >"${B}.t" && mv "${B}.t" "${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: CRLF body, [x] and [X] ticks -> clean" "${out}" "drift${T}clean${T}"
grep -Fv -e "**Local setup" -e "**App docs" "${TPL}" | tick "Contract drift" | tick Operational |
	tick "Architecture/stack drift" >"${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: an implied box missing from the body -> unchecked" "${out}" \
	"drift${T}unchecked${T}Local setup / deployment changed: no such box in the PR body
drift${T}unchecked${T}App docs invalidated: no such box in the PR body"

git -C "${R}" switch -q -c issue/3-behind main
put "${R}" h.txt plain
put "${O}" .github/workflows/new.yml ci
git -C "${O}" push -q origin main
cp "${TPL}" "${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: a path the base gained after the branch point is not this branch's" "${out}" \
	"drift${T}clean${T}"

git -C "${O}" pull -q origin main
git -C "${O}" switch -q -c feat/parent
put "${O}" .github/workflows/parent.yml ci
git -C "${O}" push -q origin feat/parent
git -C "${R}" fetch -q origin
git -C "${R}" switch -q -c issue/4-child origin/feat/parent
put "${R}" mise.toml m
fp --base feat/parent --body "${B}" drift
assert_eq "finish-preflight-drift: --base diffs against the stack parent" "${out}" \
	"drift${T}unticked${T}Local setup / deployment changed${T}mise.toml${T}1"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: without --base, against the default branch" "${out}" \
	"drift${T}unticked${T}Operational${T}.github/workflows/parent.yml${T}1
drift${T}unticked${T}Local setup / deployment changed${T}mise.toml${T}1"
fp --base gone/parent --body "${B}" drift
assert_eq "finish-preflight-drift: a base that cannot be fetched -> unchecked" "${out}" \
	"drift${T}unchecked${T}fetch of origin/gone/parent failed"

fp drift
assert_eq "finish-preflight-drift: no --body -> nothing to compare, silent" "${out}" ""
fp --body "${B}" base
case "${out}" in *"drift${T}"*) bad "finish-preflight-drift: base alone printed a drift line" ;; *) ok ;; esac
fp --body "${B}"
assert_has "finish-preflight-drift: no check named runs drift too" "${out}" "^drift${T}unticked${T}"
printf 'Fixes the thing.\n' >"${B}"
fp --body "${B}" drift
assert_eq "finish-preflight-drift: a body with no drift checklist -> unchecked" "${out}" \
	"drift${T}unchecked${T}no drift checklist in the PR body"
fp --body "${WORK}/missing.md" drift
assert_rc "finish-preflight-drift: unreadable body exits 0" "${rc}" 0
assert_eq "finish-preflight-drift: unreadable body -> unchecked" "${out}" \
	"drift${T}unchecked${T}PR body not readable: ${WORK}/missing.md"
cp "${TPL}" "${B}"
fp --remote nope --body "${B}" drift
assert_eq "finish-preflight-drift: no remote -> unchecked" "${out}" "drift${T}unchecked${T}no remote named nope"
git -C "${R}" remote add gone "${WORK}/no-such.git"
fp --remote gone --body "${B}" drift
assert_rc "finish-preflight-drift: unreachable remote exits 0" "${rc}" 0
assert_eq "finish-preflight-drift: unreachable remote -> unchecked" "${out}" \
	"drift${T}unchecked${T}gone unreachable or has no default branch"
fp --body
assert_rc "finish-preflight-drift: --body needs a value" "${rc}" 2

finish
