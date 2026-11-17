#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/scan-invocations.sh - read-only invalid-invocation detector (not a hook)
# ---------------------------------------------------------------------------
INVSCAN="${PLUGIN}/scripts/scan-invocations.sh"
INV_MD="${PLUGIN}/templates/reference/INVOCATION.md"
invscan() { run_sh "${INVSCAN}" "$1" "${PLUGIN}"; }
invclass() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$3==t {print $4; exit}'; }
invfix() { printf '%s\n' "$1" | awk -F '\t' -v t="$2" '$3==t {print $5; exit}'; }

# A fixture managed repo carrying one occurrence of each class plus tokens that
# MUST NOT be flagged (a valid skill, a correct /steer:reference <mode>, the
# marketplace id) and a provenance file that must not be scanned at all.
IR0="${WORK}/inv0"
mkdir -p "${IR0}/.github" "${IR0}/spec"
{
	printf '# Manual\n'
	printf 'Health check via /e22-audit in the past.\n'             # legacy-e22 -> /steer:audit
	printf 'Full prose: /steer:conventions here.\n'                 # reference-mode
	printf 'New spec: /steer:spec-scaffold <id>.\n'                 # noncallable-gateway
	printf 'Try /steer:bogus for nothing.\n'                        # unknown
	printf 'Run /steer:work to update.\n'                           # valid -> no emit
	printf 'Update with /steer:sync today.\n'                       # noncallable-gateway (setup mode)
	printf 'Correct: /steer:reference conventions.\n'               # valid -> no emit
	printf 'Marketplace element22llc/e22-plugins stays.\n'          # not flagged
	printf 'Shape it: /e22-standards:e22-spec once.\n'              # compound legacy (pair 1) -> /steer:spec
	printf 'Then /e22-standards:build to verify.\n'                 # compound legacy (pair 2) -> /steer:build
	printf 'Legacy prereqs: /e22-standards:doctor once.\n'          # legacy -> noncallable-gateway (setup mode), NO fix
	printf 'Legacy scaffold: /e22-standards:e22-spec-scaffold x.\n' # legacy -> noncallable-gateway, NO fix
	printf 'Legacy prose: /e22-conventions covers it.\n'            # legacy -> reference-mode
	printf 'Claude loads /steer:reference gates for us.\n'          # model-only -> no emit
	printf 'Claude files it with /steer:report upstream.\n'         # model-only -> no emit
	printf 'Old channel: /e22-report filed it once.\n'              # legacy spelling -> /steer:report
	printf 'Menu: /steer:help lists them.\n'                        # absorbed-mode, ANNOTATED (capabilities=help)
	printf 'One feature: /steer:explain user-login.\n'              # absorbed-mode, ANNOTATED (feature=explain)
	printf 'Timeline: /steer:roadmap sync now.\n'                   # absorbed-mode (spec roadmap), arg carries through
	printf 'Report: /steer:status this-week, /steer:work status.\n' # public skill + public-named mode -> no emit
} >"${IR0}/CLAUDE.md"
printf 'See /steer:design-sources for exports.\n' >"${IR0}/README.md" # reference-mode
printf 'Contributor guide: /steer:conventions applies.\n' >"${IR0}/.github/pull_request_template.md"
printf '2026-06-08: reverse-engineered by /e22-audit.\n' >"${IR0}/spec/HISTORY.md" # provenance, NOT scanned

invscan "${IR0}"
assert_eq "inv: /e22-audit -> legacy-e22" "$(invclass "${out}" /e22-audit)" "legacy-e22"
assert_eq "inv: /e22-audit fix -> /steer:audit" "$(invfix "${out}" /e22-audit)" "/steer:audit"
assert_eq "inv: /steer:conventions -> reference-mode" "$(invclass "${out}" /steer:conventions)" "reference-mode"
assert_eq "inv: /steer:conventions fix -> reference form" "$(invfix "${out}" /steer:conventions)" "/steer:reference conventions"
assert_eq "inv: /steer:design-sources -> reference-mode (README)" "$(invclass "${out}" /steer:design-sources)" "reference-mode"
assert_eq "inv: /steer:spec-scaffold -> noncallable-gateway" "$(invclass "${out}" /steer:spec-scaffold)" "noncallable-gateway"
assert_eq "inv: /steer:bogus -> unknown" "$(invclass "${out}" /steer:bogus)" "unknown"
# Compound pre-rebrand token: the skill is the token AFTER `:e22-`, never
# `standards` (which is itself a live skill, so the naive read suggests
# /steer:standards and RECONCILE.md would deterministically rewrite the line to
# `/steer:standards:e22-init`).
assert_eq "inv: /e22-standards:e22-spec -> legacy-e22" "$(invclass "${out}" /e22-standards:e22-spec)" "legacy-e22"
assert_eq "inv: /e22-standards:e22-spec fix -> /steer:spec" "$(invfix "${out}" /e22-standards:e22-spec)" "/steer:spec"
# MIGRATIONS.md v2.0.0 pair 2: the single-prefix form, `:<skill>` with no `e22-`.
assert_eq "inv: /e22-standards:build -> legacy-e22" "$(invclass "${out}" /e22-standards:build)" "legacy-e22"
assert_eq "inv: /e22-standards:build fix -> /steer:build" "$(invfix "${out}" /e22-standards:build)" "/steer:build"
# Same single-prefix form, but the skill it names went internal behind a front door.
# The verdict follows the live skill, so a pre-rebrand token resolves the whole way to
# the front-door invocation in one step rather than stopping at a dead /steer:doctor.
assert_eq "inv: single-prefix legacy -> absorbed-mode" "$(invclass "${out}" /e22-standards:doctor)" "absorbed-mode"
assert_eq "inv: single-prefix legacy fix -> /steer:setup doctor" "$(invfix "${out}" /e22-standards:doctor)" "/steer:setup doctor"
# A legacy token must get the SAME verdict its /steer: spelling would: a
# user-invocable:false gateway is a human routing decision (no mechanical fix, since
# RECONCILE.md applies a legacy-e22 fix deterministically), and a `reference` mode
# gets the deterministic reference form rather than degrading to `unknown`.
assert_eq "inv: legacy gateway -> noncallable-gateway" "$(invclass "${out}" /e22-standards:e22-spec-scaffold)" "noncallable-gateway"
assert_eq "inv: legacy gateway -> no mechanical fix" "$(invfix "${out}" /e22-standards:e22-spec-scaffold)" "-"
assert_eq "inv: legacy mode -> reference-mode" "$(invclass "${out}" /e22-conventions)" "reference-mode"
assert_eq "inv: legacy mode fix -> reference form" "$(invfix "${out}" /e22-conventions)" "/steer:reference conventions"
# ...and the compound head must not ALSO be reported as the bare `standards` skill.
printf '%s' "${out}" | awk -F '\t' '$3=="/e22-standards"' | grep -q . &&
	bad "inv: compound head must not double-report as /e22-standards" || ok
# Valid invocations and the marketplace id emit nothing.
# A skill a front door ABSORBED as a mode is a rename, not a routing decision: the
# door dispatches to the same skill, so the fix is deterministic and sync applies it
# unattended - the same pairs MIGRATIONS.md's 7.0 entry carries as a one-shot.
assert_eq "inv: /steer:sync -> absorbed-mode" "$(invclass "${out}" /steer:sync)" "absorbed-mode"
assert_eq "inv: /steer:sync fix -> /steer:setup sync" "$(invfix "${out}" /steer:sync)" "/steer:setup sync"
# A mode named after what it DOES annotates the skill it enters (`capabilities=help`,
# `feature=explain`); the suggestion must be the mode's name, not the skill's.
assert_eq "inv: /steer:help -> absorbed-mode" "$(invclass "${out}" /steer:help)" "absorbed-mode"
assert_eq "inv: /steer:help fix -> /steer:next capabilities" "$(invfix "${out}" /steer:help)" "/steer:next capabilities"
assert_eq "inv: /steer:explain fix -> /steer:status feature" "$(invfix "${out}" /steer:explain)" "/steer:status feature"
# `roadmap` carries its own `sync` mode. Scanning only a PUBLIC skill's marker is what
# stops that mode claiming the `sync` skill and handing it two owners.
assert_eq "inv: /steer:roadmap fix -> /steer:spec roadmap" "$(invfix "${out}" /steer:roadmap)" "/steer:spec roadmap"
# `work status` and `audit spec` are modes named after PUBLIC skills - an unannotated
# mode claims a skill only when an INTERNAL one shares its name, so neither is flagged.
assert_eq "inv: public /steer:status not flagged" "$(invclass "${out}" /steer:status)" ""
# The two true gateways keep the human-decision verdict: no door absorbed them, and a
# front-door swap there changes meaning.
assert_eq "inv: /steer:spec-scaffold stays a gateway" "$(invclass "${out}" /steer:spec-scaffold)" "noncallable-gateway"
printf '%s' "${out}" | grep -q '/steer:work' && bad "inv: valid /steer:work must not be flagged" || ok
printf '%s' "${out}" | grep -q 'e22-plugins' && bad "inv: marketplace id must not be flagged" || ok
# `reference` and `report` are user-invocable:false, but a human-facing doc names
# them as a DELEGATION ("Claude loads /steer:reference gates"), and there is no
# front door to rewrite them to - so the scanner exempts them by name rather than
# reporting an unfixable `noncallable-gateway` on prose that is correct. The
# exemption covers the modern spelling only: a pre-rebrand `/e22-report` is still
# a stale token with a deterministic fix.
assert_eq "inv: correct /steer:reference not flagged" "$(invclass "${out}" /steer:reference)" ""
assert_eq "inv: model-only /steer:report not flagged" "$(invclass "${out}" /steer:report)" ""
assert_eq "inv: legacy /e22-report -> legacy-e22" "$(invclass "${out}" /e22-report)" "legacy-e22"
assert_eq "inv: legacy /e22-report fix -> /steer:report" "$(invfix "${out}" /e22-report)" "/steer:report"
# Provenance file is out of scope entirely - no finding cites HISTORY.md.
printf '%s' "${out}" | grep -q 'spec/HISTORY.md' && bad "inv: provenance HISTORY.md must not be scanned" || ok

# Clean repo (the current scaffold CLAUDE.md) -> silent.
IR1="${WORK}/inv1"
mkdir -p "${IR1}"
cp "${PLUGIN}/templates/scaffold/CLAUDE.template.md" "${IR1}/CLAUDE.md"
invscan "${IR1}"
assert_empty "inv: clean scaffold CLAUDE.md -> silent" "${out}"

# Every class the detector emits is documented in INVOCATION.md.
invscan "${IR0}"
printf '%s\n' "${out}" | awk -F '\t' '{print $4}' | sort -u | while IFS= read -r _cls; do
	[ -n "${_cls}" ] || continue
	grep -q "\`${_cls}\`" "${INV_MD}" || printf 'UNDOC %s\n' "${_cls}"
done >"${WORK}/inv-undoc"
assert_empty "inv: all emitted classes documented in INVOCATION.md" "$(cat "${WORK}/inv-undoc")"

# Exit-code contract: findings on stdout (exit 0); usage -> 2; unreadable root -> 3.
sh "${INVSCAN}" "${IR0}" "${PLUGIN}" >/dev/null 2>&1
assert_rc "inv: findings run exits 0" "$?" 0
sh "${INVSCAN}" a b c >/dev/null 2>&1
assert_rc "inv: too many args -> exit 2" "$?" 2
sh "${INVSCAN}" "${WORK}/inv-nope" "${PLUGIN}" >/dev/null 2>&1
assert_rc "inv: unreadable repo-root -> exit 3" "$?" 3

finish
