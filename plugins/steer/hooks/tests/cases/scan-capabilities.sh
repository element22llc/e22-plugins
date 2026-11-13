#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/scan-capabilities.sh - read-only capability detector (not a hook)
# ---------------------------------------------------------------------------
CAPSCAN="${PLUGIN}/scripts/scan-capabilities.sh"
CAPS_MD="${PLUGIN}/templates/reference/CAPABILITIES.md"
capscan() { run_sh "${CAPSCAN}" "$1" "${PLUGIN}"; }
capstatus() { printf '%s\n' "$1" | awk -F '\t' -v id="$2" '$1==id {print $2}'; }
capfiles() { printf '%s\n' "$1" | awk -F '\t' -v id="$2" '$1==id {print $3}'; }

# Empty repo: capability-critical files absent; stack fingerprint emitted.
CR0="${WORK}/cap0"
mkdir -p "${CR0}"
capscan "${CR0}"
assert_eq "cap: empty repo plugin-enabled absent" "$(capstatus "${out}" plugin-enabled-local)" "absent"
assert_eq "cap: empty repo in-ci absent" "$(capstatus "${out}" in-ci-plugin-loading)" "absent"
assert_eq "cap: empty repo stack=none" "$(capstatus "${out}" stack)" "none"
assert_eq "cap: empty repo review-calibration absent" "$(capstatus "${out}" review-calibration)" "absent"
cp "${PLUGIN}/templates/scaffold/REVIEW.md" "${CR0}/REVIEW.md"
capscan "${CR0}"
assert_eq "cap: REVIEW.md -> review-calibration present-wired" \
	"$(capstatus "${out}" review-calibration)" "present-wired"
rm "${CR0}/REVIEW.md"

# settings.json wiring: true -> wired, false -> disabled, present-no-steer -> mis-wired.
CR1="${WORK}/cap1"
mkdir -p "${CR1}/.claude"
printf '{"enabledPlugins":{"steer@e22-plugins":true}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: steer true -> present-wired" "$(capstatus "${out}" plugin-enabled-local)" "present-wired"
printf '{"enabledPlugins":{"steer@e22-plugins":false}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: steer false -> disabled (respected)" "$(capstatus "${out}" plugin-enabled-local)" "disabled"
printf '{"enabledPlugins":{}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: settings present, no steer -> mis-wired" "$(capstatus "${out}" plugin-enabled-local)" "mis-wired"

# claude.yml: plugin_marketplaces marker required (a stock template is mis-wired).
CR2="${WORK}/cap2"
mkdir -p "${CR2}/.github/workflows"
printf 'jobs:\n  claude:\n    steps: []\n' >"${CR2}/.github/workflows/claude.yml"
capscan "${CR2}"
assert_eq "cap: stock claude.yml -> mis-wired" "$(capstatus "${out}" in-ci-plugin-loading)" "mis-wired"
printf 'with:\n  plugin_marketplaces: e22-plugins\n' >>"${CR2}/.github/workflows/claude.yml"
capscan "${CR2}"
assert_eq "cap: claude.yml with marketplace -> present-wired" "$(capstatus "${out}" in-ci-plugin-loading)" "present-wired"

# question-gate: n/a without a spine; wired only with the step, the task, the
# stage script, and a byte-identical parser copy.
CRQ="${WORK}/capq"
mkdir -p "${CRQ}/.github/workflows" "${CRQ}/scripts" "${CRQ}/spec"
capscan "${CRQ}"
assert_eq "cap: question-gate n/a without a spine" "$(capstatus "${out}" question-gate)" "n/a"
printf '7.0.0\n' >"${CRQ}/spec/.version"
printf 'jobs: {}\n' >"${CRQ}/.github/workflows/ci.yml"
capscan "${CRQ}"
assert_eq "cap: question-gate absent on an older repo" "$(capstatus "${out}" question-gate)" "absent"
printf '      - run: mise run ci:spec\n' >>"${CRQ}/.github/workflows/ci.yml"
printf '[tasks."ci:spec"]\nrun = "sh scripts/ci-spec.sh"\n' >"${CRQ}/mise.toml"
cp "${PLUGIN}/templates/scaffold/scripts/ci-spec.sh" "${CRQ}/scripts/"
printf '# stale copy\n' >"${CRQ}/scripts/spec-questions.sh"
capscan "${CRQ}"
assert_eq "cap: question-gate mis-wired on a drifted parser" "$(capstatus "${out}" question-gate)" "mis-wired"
cp "${PLUGIN}/hooks/lib/questions.sh" "${CRQ}/scripts/spec-questions.sh"
capscan "${CRQ}"
assert_eq "cap: question-gate present-wired" "$(capstatus "${out}" question-gate)" "present-wired"

# dependency-automation: wired by ci.yml's job; the retired standalone workflow is mis-wired.
CRD="${WORK}/capDep"
mkdir -p "${CRD}/.github/workflows"
capscan "${CRD}"
assert_eq "cap: dependency-automation absent" "$(capstatus "${out}" dependency-automation)" "absent"
printf 'version: 2\n' >"${CRD}/.github/dependabot.yml"
cp "${PLUGIN}/templates/github/workflows/ci.yml" "${CRD}/.github/workflows/ci.yml"
capscan "${CRD}"
assert_eq "cap: dependency-automation present-wired" "$(capstatus "${out}" dependency-automation)" "present-wired"
printf 'on: pull_request\n' >"${CRD}/.github/workflows/dependabot-auto-merge.yml"
capscan "${CRD}"
assert_eq "cap: retired auto-merge workflow -> mis-wired" "$(capstatus "${out}" dependency-automation)" "mis-wired"
rm "${CRD}/.github/workflows/dependabot-auto-merge.yml"

# A workflow_call caller must grant the auto-merge job's write scopes: GitHub
# refuses to start the caller run otherwise, even when the job's `if` skips it.
printf 'permissions:\n  contents: read\njobs:\n  ci:\n    uses: "./.github/workflows/ci.yml"\n' \
	>"${CRD}/.github/workflows/main-check.yaml"
capscan "${CRD}"
assert_eq "cap: read-only workflow_call caller -> mis-wired" "$(capstatus "${out}" dependency-automation)" "mis-wired"
assert_has "cap: short caller named" "$(capfiles "${out}" dependency-automation)" ".github/workflows/main-check.yaml"
printf 'jobs:\n  ci:\n    uses: ./.github/workflows/ci.yml\n' >"${CRD}/.github/workflows/main-check.yaml"
capscan "${CRD}"
assert_eq "cap: caller with no permissions -> mis-wired" "$(capstatus "${out}" dependency-automation)" "mis-wired"
printf '# contents: write, pull-requests: write\npermissions:\n  contents: write\njobs:\n  ci:\n    uses: ./.github/workflows/ci.yml\n' \
	>"${CRD}/.github/workflows/main-check.yaml"
capscan "${CRD}"
assert_eq "cap: caller granting one scope (other in a comment) -> mis-wired" \
	"$(capstatus "${out}" dependency-automation)" "mis-wired"
printf 'jobs:\n  ci:\n    permissions:\n      contents: "write"\n      pull-requests: write\n    uses: ./.github/workflows/ci.yml\n' \
	>"${CRD}/.github/workflows/main-check.yaml"
capscan "${CRD}"
assert_eq "cap: caller granting the scopes -> present-wired" "$(capstatus "${out}" dependency-automation)" "present-wired"
printf 'permissions: write-all\njobs:\n  ci:\n    uses: ./.github/workflows/ci.yml\n' >"${CRD}/.github/workflows/main-check.yaml"
capscan "${CRD}"
assert_eq "cap: write-all caller -> present-wired" "$(capstatus "${out}" dependency-automation)" "present-wired"
printf 'jobs:\n  ci:\n    # uses: ./.github/workflows/ci.yml\n    runs-on: x\n' >"${CRD}/.github/workflows/main-check.yaml"
capscan "${CRD}"
assert_eq "cap: commented-out caller ignored" "$(capstatus "${out}" dependency-automation)" "present-wired"

# Splicing the job into a repo without it breaks a read-only caller too.
CRA="${WORK}/capDepAbsent"
mkdir -p "${CRA}/.github/workflows"
printf 'on: workflow_call\njobs: {}\n' >"${CRA}/.github/workflows/ci.yml"
printf 'permissions: read-all\njobs:\n  ci:\n    uses: ./.github/workflows/ci.yml\n' >"${CRA}/.github/workflows/nightly.yml"
capscan "${CRA}"
assert_eq "cap: absent job, caller present -> absent" "$(capstatus "${out}" dependency-automation)" "absent"
assert_has "cap: absent still names the short caller" "$(capfiles "${out}" dependency-automation)" ".github/workflows/nightly.yml"

# agent-surface-current: the retired-surface check keys on steer's OWN artifacts.
# The migration that retires .github/prompts/ deliberately leaves a team-authored
# prompt file - and the directory around it - in place, so testing the directory
# wedged such a repo at mis-wired with a verbatim-recopy repair that deletes nothing.
CRP="${WORK}/capPrompts"
mkdir -p "${CRP}/.github" "${CRP}/.agents"
cp "${PLUGIN}/templates/github/copilot-instructions.md" "${CRP}/.github/"
cp -R "${PLUGIN}/templates/github/agents" "${CRP}/.github/agents"
cp -R "${PLUGIN}/templates/github/instructions" "${CRP}/.github/instructions"
cp -R "${PLUGIN}/templates/agents/skills" "${CRP}/.agents/skills"
capscan "${CRP}"
assert_eq "cap: AGENTS.md pointer missing -> mis-wired" \
	"$(capstatus "${out}" agent-surface-current)" "mis-wired"
{
	printf '# Team notes\n\nOurs.\n\n'
	cat "${PLUGIN}/templates/agents/agents-pointer.md"
	printf '\nMore of ours.\n'
} >"${CRP}/AGENTS.md"
capscan "${CRP}"
assert_eq "cap: agent surface byte-identical, team AGENTS.md content kept -> present-wired" \
	"$(capstatus "${out}" agent-surface-current)" "present-wired"
mkdir -p "${CRP}/.github/prompts"
printf 'ours\n' >"${CRP}/.github/prompts/our-own.prompt.md"
capscan "${CRP}"
assert_eq "cap: team-authored prompt file is NOT drift" \
	"$(capstatus "${out}" agent-surface-current)" "present-wired"
printf 'retired\n' >"${CRP}/.github/prompts/steer-work.prompt.md"
capscan "${CRP}"
assert_eq "cap: lingering steer-*.prompt.md IS drift" \
	"$(capstatus "${out}" agent-surface-current)" "mis-wired"
rm "${CRP}/.github/prompts/steer-work.prompt.md"
sed 's/Before starting work/Before you start/' "${PLUGIN}/templates/agents/agents-pointer.md" >"${CRP}/AGENTS.md"
capscan "${CRP}"
assert_eq "cap: stale AGENTS.md pointer block IS drift" \
	"$(capstatus "${out}" agent-surface-current)" "mis-wired"

# agents-md-imported: Claude Code reads AGENTS.md only when no CLAUDE.md exists,
# so team content there needs a bare `@AGENTS.md` line in CLAUDE.md.
CRA="${WORK}/capAgentsMd"
mkdir -p "${CRA}"
printf '# Product\n' >"${CRA}/CLAUDE.md"
capscan "${CRA}"
assert_eq "cap: no AGENTS.md -> agents-md n/a" "$(capstatus "${out}" agents-md-imported)" "n/a"
{
	printf '\n'
	cat "${PLUGIN}/templates/agents/agents-pointer.md"
	printf '\n'
} >"${CRA}/AGENTS.md"
capscan "${CRA}"
assert_eq "cap: block-only AGENTS.md -> agents-md n/a" "$(capstatus "${out}" agents-md-imported)" "n/a"
printf '# Team rules\n\nUse tabs.\n' >>"${CRA}/AGENTS.md"
capscan "${CRA}"
assert_eq "cap: team AGENTS.md not imported -> mis-wired" "$(capstatus "${out}" agents-md-imported)" "mis-wired"
printf 'See `@AGENTS.md` for team rules.\n' >>"${CRA}/CLAUDE.md"
capscan "${CRA}"
assert_eq "cap: backticked @AGENTS.md is not an import -> mis-wired" \
	"$(capstatus "${out}" agents-md-imported)" "mis-wired"
printf '<!-- steer:agents-md -->\n@AGENTS.md\n' >>"${CRA}/CLAUDE.md"
capscan "${CRA}"
assert_eq "cap: bare @AGENTS.md line -> present-wired" "$(capstatus "${out}" agents-md-imported)" "present-wired"
rm "${CRA}/CLAUDE.md"
capscan "${CRA}"
assert_eq "cap: no CLAUDE.md, AGENTS.md read natively -> n/a" "$(capstatus "${out}" agents-md-imported)" "n/a"

# version-pin-enforcement: policy + byte-identical scripts -> wired; drift -> mis-wired.
CR3="${WORK}/cap3"
mkdir -p "${CR3}/policy" "${CR3}/scripts"
printf 'minimum_supported:\n' >"${CR3}/policy/versions.yml"
cp "${PLUGIN}/scripts/scan-version-pins.sh" "${CR3}/scripts/scan-version-pins.sh"
cp "${PLUGIN}/hooks/lib/version-policy.sh" "${CR3}/scripts/version-policy.sh"
capscan "${CR3}"
assert_eq "cap: verbatim scripts -> present-wired" "$(capstatus "${out}" version-pin-enforcement)" "present-wired"
printf '# local edit\n' >>"${CR3}/scripts/scan-version-pins.sh"
capscan "${CR3}"
assert_eq "cap: drifted verbatim script -> mis-wired" "$(capstatus "${out}" version-pin-enforcement)" "mis-wired"
rm -f "${CR3}/policy/versions.yml"
capscan "${CR3}"
assert_eq "cap: missing policy -> absent" "$(capstatus "${out}" version-pin-enforcement)" "absent"

# node-tooling conditionality: Python-only n/a; Node without biome absent; with biome wired.
CR4="${WORK}/cap4"
mkdir -p "${CR4}"
printf '[project]\n' >"${CR4}/pyproject.toml"
capscan "${CR4}"
assert_eq "cap: python stack -> node-tooling n/a" "$(capstatus "${out}" node-tooling)" "n/a"
assert_eq "cap: python fingerprint" "$(capstatus "${out}" stack)" "python"
rm -f "${CR4}/pyproject.toml"
printf '{}\n' >"${CR4}/package.json"
capscan "${CR4}"
assert_eq "cap: node without biome -> absent" "$(capstatus "${out}" node-tooling)" "absent"
printf '{}\n' >"${CR4}/biome.json"
capscan "${CR4}"
assert_eq "cap: node with biome -> present-wired" "$(capstatus "${out}" node-tooling)" "present-wired"

# github-issue-forms: gated on the tracker system in spec/tracker.md.
CR5="${WORK}/cap5"
mkdir -p "${CR5}/spec"
printf 'system: jira\n' >"${CR5}/spec/tracker.md"
capscan "${CR5}"
assert_eq "cap: non-github tracker -> issue-forms n/a" "$(capstatus "${out}" github-issue-forms)" "n/a"
printf 'system: github\n' >"${CR5}/spec/tracker.md"
capscan "${CR5}"
assert_eq "cap: github tracker, no forms -> absent" "$(capstatus "${out}" github-issue-forms)" "absent"
mkdir -p "${CR5}/.github/ISSUE_TEMPLATE"
printf 'blank_issues_enabled: false\n' >"${CR5}/.github/ISSUE_TEMPLATE/config.yml"
capscan "${CR5}"
assert_eq "cap: github tracker with forms -> present-wired" "$(capstatus "${out}" github-issue-forms)" "present-wired"

# github-issue-permissions: gated on the tracker system; wired when the gh-issue
# allow-list is present in .claude/settings.json (write verb is the marker).
CR5b="${WORK}/cap5b"
mkdir -p "${CR5b}/spec"
printf 'system: jira\n' >"${CR5b}/spec/tracker.md"
capscan "${CR5b}"
assert_eq "cap: non-github tracker -> issue-perms n/a" "$(capstatus "${out}" github-issue-permissions)" "n/a"
printf 'system: github\n' >"${CR5b}/spec/tracker.md"
capscan "${CR5b}"
assert_eq "cap: github tracker, no settings -> absent" "$(capstatus "${out}" github-issue-permissions)" "absent"
mkdir -p "${CR5b}/.claude"
printf '{"permissions":{"allow":["Bash(gh issue list:*)","Bash(gh issue view:*)"]}}\n' >"${CR5b}/.claude/settings.json"
capscan "${CR5b}"
assert_eq "cap: read-only-era settings -> mis-wired" "$(capstatus "${out}" github-issue-permissions)" "mis-wired"
printf '{"permissions":{"allow":["Bash(gh issue create:*)","Bash(gh issue view:*)"]}}\n' >"${CR5b}/.claude/settings.json"
capscan "${CR5b}"
assert_eq "cap: settings with gh issue create -> present-wired" "$(capstatus "${out}" github-issue-permissions)" "present-wired"

# toolchain-pin: mise.toml without lock is mis-wired; both -> wired.
CR6="${WORK}/cap6"
mkdir -p "${CR6}"
printf '[tools]\n' >"${CR6}/mise.toml"
capscan "${CR6}"
assert_eq "cap: mise.toml without lock -> mis-wired" "$(capstatus "${out}" toolchain-pin)" "mis-wired"
printf '\n' >"${CR6}/mise.lock"
capscan "${CR6}"
assert_eq "cap: mise.toml + lock -> present-wired" "$(capstatus "${out}" toolchain-pin)" "present-wired"

# worktree-port-isolation: n/a without a runtime; with a runtime, deriver +
# mise [env]._.source -> wired; deriver present but mise unwired -> mis-wired.
CR7="${WORK}/cap7"
mkdir -p "${CR7}/scripts"
capscan "${CR7}"
assert_eq "cap: no runtime -> worktree isolation n/a" "$(capstatus "${out}" worktree-port-isolation)" "n/a"
printf '{}\n' >"${CR7}/package.json"
capscan "${CR7}"
assert_eq "cap: node stack, no deriver -> absent" "$(capstatus "${out}" worktree-port-isolation)" "absent"
printf 'export X=1\n' >"${CR7}/scripts/worktree-env.sh"
printf '[tools]\n' >"${CR7}/mise.toml"
capscan "${CR7}"
assert_eq "cap: deriver present, mise unwired -> mis-wired" "$(capstatus "${out}" worktree-port-isolation)" "mis-wired"
printf '[env]\n_.source = "scripts/worktree-env.sh"\n' >>"${CR7}/mise.toml"
capscan "${CR7}"
assert_eq "cap: deriver + mise sources it -> present-wired" "$(capstatus "${out}" worktree-port-isolation)" "present-wired"

# delivery-mode-declared: no CLAUDE.md -> absent; present without the marker ->
# mis-wired (implicit fail-open pr-flow); marker present -> wired.
CR8="${WORK}/cap8"
mkdir -p "${CR8}"
capscan "${CR8}"
assert_eq "cap: no CLAUDE.md -> delivery-mode absent" "$(capstatus "${out}" delivery-mode-declared)" "absent"
printf '# Product\n\nsome prose\n' >"${CR8}/CLAUDE.md"
capscan "${CR8}"
assert_eq "cap: CLAUDE.md without marker -> mis-wired" "$(capstatus "${out}" delivery-mode-declared)" "mis-wired"
printf '<!-- steer:delivery-mode=solo-trunk -->\n' >>"${CR8}/CLAUDE.md"
capscan "${CR8}"
assert_eq "cap: CLAUDE.md with marker -> present-wired" "$(capstatus "${out}" delivery-mode-declared)" "present-wired"

# app-knowledge-docs: the app guide is instantiated from a spec template, so
# additive reconciliation can never create it - the capability is its backfill
# path. Absent when spec/app/README.md is missing; present-wired once it exists.
CR9="${WORK}/cap9"
mkdir -p "${CR9}"
capscan "${CR9}"
assert_eq "cap: no app guide -> app-knowledge-docs absent" "$(capstatus "${out}" app-knowledge-docs)" "absent"
mkdir -p "${CR9}/spec/app"
printf '# App guide\n' >"${CR9}/spec/app/README.md"
capscan "${CR9}"
assert_eq "cap: app guide present -> present-wired" "$(capstatus "${out}" app-knowledge-docs)" "present-wired"

# The release flow: n/a off prod-branch-pr, wired from the scaffold, release_hold: none respected.
CRR="${WORK}/caprel"
mkdir -p "${CRR}/scripts" "${CRR}/policy" "${CRR}/.github/workflows"
capscan "${CRR}"
assert_eq "cap: no release flow -> promotion-gate absent" "$(capstatus "${out}" promotion-gate)" "absent"
assert_eq "cap: no release flow -> release-merge-back absent" "$(capstatus "${out}" release-merge-back)" "absent"
assert_eq "cap: no release flow -> release-hold absent" "$(capstatus "${out}" release-hold)" "absent"
for f in ci-promotion.sh merge-back.sh release-target.sh; do cp "${PLUGIN}/templates/scaffold/scripts/${f}" "${CRR}/scripts/"; done
cp "${PLUGIN}/templates/scaffold/policy/delivery.yml" "${CRR}/policy/"
cp "${PLUGIN}/templates/scaffold/mise.toml" "${CRR}/"
cp "${PLUGIN}/templates/github/workflows/ci.yml" "${PLUGIN}/templates/github/workflows/merge-back.yml" "${CRR}/.github/workflows/"
capscan "${CRR}"
assert_eq "cap: scaffold -> promotion-gate present-wired" "$(capstatus "${out}" promotion-gate)" "present-wired"
assert_eq "cap: scaffold -> release-merge-back present-wired" "$(capstatus "${out}" release-merge-back)" "present-wired"
assert_eq "cap: scaffold -> release-hold present-wired" "$(capstatus "${out}" release-hold)" "present-wired"
sed 's/^release_hold:.*/release_hold: none/' "${PLUGIN}/templates/scaffold/policy/delivery.yml" >"${CRR}/policy/delivery.yml"
capscan "${CRR}"
assert_eq "cap: release_hold none -> disabled" "$(capstatus "${out}" release-hold)" "disabled"
sed 's/^production_gate:.*/production_gate: manual/' "${PLUGIN}/templates/scaffold/policy/delivery.yml" >"${CRR}/policy/delivery.yml"
capscan "${CRR}"
assert_eq "cap: manual gate -> promotion-gate still wired" "$(capstatus "${out}" promotion-gate)" "present-wired"
assert_eq "cap: manual gate -> release-merge-back n/a" "$(capstatus "${out}" release-merge-back)" "n/a"
assert_eq "cap: manual gate -> release-hold n/a" "$(capstatus "${out}" release-hold)" "n/a"
# The core ci.yml calls the script on every gate, so a missing one is a red ci check, not n/a.
rm "${CRR}/scripts/ci-promotion.sh"
capscan "${CRR}"
assert_eq "cap: manual gate, script missing -> promotion-gate mis-wired" "$(capstatus "${out}" promotion-gate)" "mis-wired"
mkdir -p "${CRR}/spec" && : >"${CRR}/spec/workspace.yml"
capscan "${CRR}"
assert_eq "cap: workspace -> promotion-gate n/a" "$(capstatus "${out}" promotion-gate)" "n/a"

# Idempotency: repairing a mis-wired settings.json makes the re-scan present-wired.
printf '{"enabledPlugins":{"steer@e22-plugins":true}}\n' >"${CR1}/.claude/settings.json"
capscan "${CR1}"
assert_eq "cap: repaired settings -> present-wired on re-scan" "$(capstatus "${out}" plugin-enabled-local)" "present-wired"

# Every capability id the detector emits is documented in CAPABILITIES.md.
# `stack` and `profile` are informational fingerprints, not capabilities - exempt.
capscan "${CR0}"
printf '%s\n' "${out}" | awk -F '\t' '$1!="stack" && $1!="profile"{print $1}' | while IFS= read -r _id; do
	grep -q "### ${_id} " "${CAPS_MD}" || printf 'UNDOC %s\n' "${_id}"
done >"${WORK}/cap-undoc"
assert_empty "cap: all emitted ids documented in CAPABILITIES.md" "$(cat "${WORK}/cap-undoc")"

# ...and the reverse direction: every capability documented in CAPABILITIES.md has
# a detector. Only the emit->doc half was ever asserted, so a documented-but-
# undetected capability was invisible to /steer:sync: RECONCILE.md drives the
# capability walk entirely from this scanner's output, so an id it never emits
# never reaches the status table and is never proposed or repaired. The trailing
# space in the grep keeps the `### <capability-id>` authoring stub out of the set.
grep -oE '^### [a-z][a-z-]+ ' "${CAPS_MD}" | sed 's/^### //; s/ $//' | while IFS= read -r _id; do
	printf '%s\n' "${out}" | cut -f1 | grep -qx "${_id}" || printf 'UNDETECTED %s\n' "${_id}"
done >"${WORK}/cap-undetected"
assert_empty "cap: all documented ids have a detector" "$(cat "${WORK}/cap-undetected")"

# Exit-code contract: gaps on stdout (exit 0); usage -> 2; unreadable root -> 3.
sh "${CAPSCAN}" "${CR0}" "${PLUGIN}" >/dev/null 2>&1
assert_rc "cap: gaps run exits 0" "$?" 0
sh "${CAPSCAN}" a b c >/dev/null 2>&1
assert_rc "cap: too many args -> exit 2" "$?" 2
sh "${CAPSCAN}" "${WORK}/cap-nope" "${PLUGIN}" >/dev/null 2>&1
assert_rc "cap: unreadable repo-root -> exit 3" "$?" 3

# drift-gate: wired only when every stage ci.yml runs has its task and script.
CRD="${WORK}/cap-drift"
mkdir -p "${CRD}/.github/workflows" "${CRD}/scripts"
cp "${PLUGIN}/templates/github/workflows/ci.yml" "${CRD}/.github/workflows/ci.yml"
cp "${PLUGIN}/templates/github/pull_request_template.md" "${CRD}/.github/pull_request_template.md"
cp "${PLUGIN}/templates/scaffold/mise.toml" "${CRD}/mise.toml"
cp "${PLUGIN}/templates/scaffold/scripts/"ci-*.sh "${CRD}/scripts/"
capscan "${CRD}"
assert_eq "cap: full scaffold CI -> drift-gate present-wired" "$(capstatus "${out}" drift-gate)" "present-wired"
rm "${CRD}/scripts/ci-lint.sh"
capscan "${CRD}"
assert_eq "cap: a stage script mise.toml runs is missing -> mis-wired" "$(capstatus "${out}" drift-gate)" "mis-wired"
cp "${PLUGIN}/templates/scaffold/scripts/ci-lint.sh" "${CRD}/scripts/"
sed 's/^\[tasks\."ci:coverage"\]/[tasks."ci:gone"]/' "${PLUGIN}/templates/scaffold/mise.toml" >"${CRD}/mise.toml"
capscan "${CRD}"
assert_eq "cap: a flagged stage (--skip-deps ci:coverage) with no task -> mis-wired" "$(capstatus "${out}" drift-gate)" "mis-wired"
printf '[tasks."ci:hygiene"]\nrun = "sh scripts/ci-hygiene.sh"\n' >"${CRD}/mise.toml"
capscan "${CRD}"
assert_eq "cap: ci.yml stages with no tasks -> mis-wired" "$(capstatus "${out}" drift-gate)" "mis-wired"

# commit-gate: core.hooksPath set means the repo owns its commit gate.
CRG="${WORK}/cap-commit"
mkdir -p "${CRG}/.githooks"
git -C "${CRG}" init -q
printf '[tasks.pre-commit]\nrun = "true"\n' >"${CRG}/mise.toml"
capscan "${CRG}"
assert_eq "cap: no pre-commit hook -> commit-gate absent" "$(capstatus "${out}" commit-gate)" "absent"
git -C "${CRG}" config core.hooksPath .githooks
capscan "${CRG}"
assert_eq "cap: core.hooksPath set -> commit-gate n/a" "$(capstatus "${out}" commit-gate)" "n/a"

# A workspace (spec/workspace.yml) runs ws:-prefixed tasks from its own ci.yml.
CRW="${WORK}/cap-workspace"
mkdir -p "${CRW}/.github/workflows" "${CRW}/scripts" "${CRW}/spec"
git -C "${CRW}" init -q
: >"${CRW}/spec/workspace.yml"
cp "${PLUGIN}/templates/github/workflows/ci.yml" "${CRW}/.github/workflows/ci.yml"
cp "${PLUGIN}/templates/github/pull_request_template.md" "${CRW}/.github/pull_request_template.md"
cp "${PLUGIN}/templates/scaffold/profiles/workspace/mise.toml" "${CRW}/mise.toml"
cp "${PLUGIN}/templates/scaffold/scripts/"ci-*.sh "${CRW}/scripts/"
printf '7.0.0\n' >"${CRW}/spec/.version"
cp "${PLUGIN}/hooks/lib/questions.sh" "${CRW}/scripts/spec-questions.sh"
capscan "${CRW}"
assert_eq "cap: workspace still on the core ci.yml -> drift-gate mis-wired" "$(capstatus "${out}" drift-gate)" "mis-wired"
assert_eq "cap: workspace still on the core ci.yml -> question-gate mis-wired" "$(capstatus "${out}" question-gate)" "mis-wired"
cp "${PLUGIN}/templates/github/workflows/ci-workspace.yml" "${CRW}/.github/workflows/ci.yml"
capscan "${CRW}"
assert_eq "cap: workspace ci.yml + ws: tasks -> drift-gate present-wired" "$(capstatus "${out}" drift-gate)" "present-wired"
assert_eq "cap: workspace without a hook -> commit-gate absent" "$(capstatus "${out}" commit-gate)" "absent"
printf '#!/bin/sh\nexec mise run pre-commit\n' >"${CRW}/.git/hooks/pre-commit"
capscan "${CRW}"
assert_eq "cap: workspace hook calling pre-commit -> commit-gate mis-wired" "$(capstatus "${out}" commit-gate)" "mis-wired"
printf '#!/bin/sh\nexec mise run ws:pre-commit\n' >"${CRW}/.git/hooks/pre-commit"
capscan "${CRW}"
assert_eq "cap: workspace hook calling ws:pre-commit -> commit-gate present-wired" "$(capstatus "${out}" commit-gate)" "present-wired"
assert_eq "cap: workspace ci.yml runs ws:ci:spec -> question-gate present-wired" "$(capstatus "${out}" question-gate)" "present-wired"

# Tasks in a mise task include, reached through one gate script CI calls (#929).
# PATH without mise: the grep alone must see them.
capscan_nomise() { out="$(env PATH=/usr/bin:/bin sh "${CAPSCAN}" "$1" "${PLUGIN}" 2>/dev/null)"; }
CRI="${WORK}/cap-includes"
mkdir -p "${CRI}/.github/workflows" "${CRI}/scripts" "${CRI}/spec" "${CRI}/.mise/tasks"
git -C "${CRI}" init -q
: >"${CRI}/spec/workspace.yml"
printf '7.0.0\n' >"${CRI}/spec/.version"
cp "${PLUGIN}/templates/github/pull_request_template.md" "${CRI}/.github/pull_request_template.md"
cp "${PLUGIN}/templates/scaffold/scripts/"ci-*.sh "${CRI}/scripts/"
cp "${PLUGIN}/hooks/lib/questions.sh" "${CRI}/scripts/spec-questions.sh"
printf '[tools]\n' >"${CRI}/mise.toml"
printf 'jobs:\n  gate:\n    steps:\n      - run: sh ./scripts/gate.sh\n' >"${CRI}/.github/workflows/ci.yml"
printf '#!/bin/sh\nmise run ws:ci:hygiene\nsh scripts/ci-spec.sh\n' >"${CRI}/scripts/gate.sh"
cat >"${CRI}/.mise/tasks/repo.toml" <<'EOF'
["ws:ci:hygiene"]
run = "sh scripts/ci-hygiene.sh"
["ws:ci:lint"]
run = "sh scripts/ci-lint.sh"
["ws:ci:spec"]
run = "sh scripts/ci-spec.sh"
["ws:check"]
depends = ["ws:ci:hygiene", "ws:ci:lint"]
["ws:ci"]
depends = ["ws:check", "ws:ci:spec"]
["ws:pre-commit"]
depends = ["ws:ci:hygiene"]
EOF
capscan_nomise "${CRI}"
assert_eq "cap: include tasks + gate script -> drift-gate present-wired" "$(capstatus "${out}" drift-gate)" "present-wired"
assert_eq "cap: include tasks + gate script -> question-gate present-wired" "$(capstatus "${out}" question-gate)" "present-wired"
assert_eq "cap: ws:pre-commit in an include -> commit-gate absent, not n/a" "$(capstatus "${out}" commit-gate)" "absent"
rm "${CRI}/scripts/ci-hygiene.sh"
capscan_nomise "${CRI}"
assert_eq "cap: a stage script only an include names is missing -> drift-gate mis-wired" "$(capstatus "${out}" drift-gate)" "mis-wired"
cp "${PLUGIN}/templates/scaffold/scripts/ci-hygiene.sh" "${CRI}/scripts/"
printf '#!/bin/sh\nmise run ws:ci:hygiene\n# sh scripts/ci-spec.sh\n' >"${CRI}/scripts/gate.sh"
capscan_nomise "${CRI}"
assert_eq "cap: gate script names the spec stage only in a comment -> question-gate mis-wired" "$(capstatus "${out}" question-gate)" "mis-wired"
printf '#!/bin/sh\nmise run ws:ci:hygiene\nmise run ws:ci:spec\n' >"${CRI}/scripts/gate.sh"
sed 's/^\["ws:ci:spec"\]/["ws:ci:other"]/' "${CRI}/.mise/tasks/repo.toml" >"${CRI}/.mise/tasks/repo.toml.new"
mv "${CRI}/.mise/tasks/repo.toml.new" "${CRI}/.mise/tasks/repo.toml"
capscan_nomise "${CRI}"
assert_eq "cap: CI runs ws:ci:spec but no include defines it -> question-gate mis-wired" "$(capstatus "${out}" question-gate)" "mis-wired"
assert_eq "cap: CI runs ws:ci:spec but no include defines it -> drift-gate mis-wired" "$(capstatus "${out}" drift-gate)" "mis-wired"

# [task_config] includes replaces mise's default task dirs.
CRT="${WORK}/cap-task-config"
mkdir -p "${CRT}/.github/workflows" "${CRT}/scripts" "${CRT}/spec" "${CRT}/tasks" "${CRT}/.mise/tasks"
printf '7.0.0\n' >"${CRT}/spec/.version"
cp "${PLUGIN}/templates/scaffold/scripts/ci-spec.sh" "${CRT}/scripts/"
cp "${PLUGIN}/hooks/lib/questions.sh" "${CRT}/scripts/spec-questions.sh"
printf '      - run: mise run ci:spec\n' >"${CRT}/.github/workflows/ci.yml"
printf '[task_config]\nincludes = [\n  "./tasks",\n]\n' >"${CRT}/mise.toml"
printf '["ci:spec"]\nrun = "sh scripts/ci-spec.sh"\n' >"${CRT}/tasks/spec.toml"
capscan_nomise "${CRT}"
assert_eq "cap: task in a [task_config] include dir -> question-gate present-wired" "$(capstatus "${out}" question-gate)" "present-wired"
mv "${CRT}/tasks/spec.toml" "${CRT}/.mise/tasks/spec.toml"
capscan_nomise "${CRT}"
assert_eq "cap: task in a default dir the includes list hides -> question-gate mis-wired" "$(capstatus "${out}" question-gate)" "mis-wired"
printf '[task_config]\nincludes = ["/elsewhere/tasks"]\n' >"${CRT}/mise.toml"
capscan_nomise "${CRT}"
assert_eq "cap: includes with nothing readable still hides the default dirs" "$(capstatus "${out}" question-gate)" "mis-wired"

# The scanner never asks mise, even when the files show no task: in a trusted repo
# mise evaluates the repo's config, and this helper never executes repo content.
CAP_STUBS="${WORK}/cap-stubs"
CAP_MISE_LOG="${WORK}/cap-mise.log"
mkdir -p "${CAP_STUBS}"
cat >"${CAP_STUBS}/mise" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"${MISE_STUB_LOG}"
printf 'Source: %s/mise.toml\n' "${PWD}"
EOF
chmod +x "${CAP_STUBS}/mise"
: >"${CAP_MISE_LOG}"
out="$(env PATH="${CAP_STUBS}:/usr/bin:/bin" MISE_STUB_LOG="${CAP_MISE_LOG}" sh "${CAPSCAN}" "${CRT}" "${PLUGIN}" 2>/dev/null)"
assert_eq "cap: mise on PATH does not change a grep verdict" "$(capstatus "${out}" question-gate)" "mis-wired"
assert_eq "cap: mise on PATH is never invoked" "$(cat "${CAP_MISE_LOG}")" ""

# changelog-fragments is judged on the scanned repo, not the caller's cwd.
CRC="${WORK}/cap-changie"
mkdir -p "${CRC}/.changes/unreleased"
: >"${CRC}/.changie.yaml"
out="$(cd / && sh "${CAPSCAN}" "${CRC}" "${PLUGIN}" 2>/dev/null)"
assert_eq "cap: changelog-fragments read from the repo root" "$(capstatus "${out}" changelog-fragments)" "present-wired"

finish
