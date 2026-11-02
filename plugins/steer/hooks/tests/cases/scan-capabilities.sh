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

finish
