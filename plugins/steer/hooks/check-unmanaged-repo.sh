#!/usr/bin/env sh
# steer SessionStart hook — unmanaged-repo detector (greenfield nudge).
#
# WHY THIS EXISTS
#   A repo with the plugin enabled but no /spec spine still gets the always-on
#   rules injected — yet nothing PUSHES the spec-first bootstrap. So a session
#   silently degrades to "toolchain conventions only" and writes feature code
#   with no vision/intent/contract behind it (the exact failure that prompted
#   this hook: a brand-new non-template repo where code was written from scratch
#   with the plugin active, but the spec spine never appeared). The drift and
#   open-questions hooks only fire once /spec ALREADY exists — they cannot catch
#   a repo that never got a spine. /steer:init (plugin-driven bootstrap, or a
#   legacy fork) and /steer:adopt (reverse-engineer existing code) are the fixes,
#   but a skill is pull, not push: it only runs when someone invokes it, and the
#   router prose that mentions it is easy to deprioritize while coding. This hook
#   makes the missing spine a high-salience session-start signal so the bootstrap
#   happens BEFORE feature code, not as an afterthought.
#
# MECHANISM
#   Everything written to stdout becomes session `additionalContext` (same path
#   as inject-standards.sh / check-open-questions.sh). SILENT once /spec exists,
#   so an initialized or adopted repo gets zero noise and the notice clears
#   itself. Presents the bootstrap routes (PO-guided build, developer init, or
#   adopt) rather than guessing greenfield-vs-adopt from code volume (a brittle
#   heuristic) — the session picks based on who is driving (a non-technical owner
#   vs a developer) and whether the code is being written fresh or already existed.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. The CONSUMER repo comes from the
#   SessionStart payload `cwd` — never the hook process's own cwd, which the
#   harness does not guarantee to match (mirrors check-template-drift.sh, #331).
#   Fail-soft: any ambiguity → stay silent, never block a session.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"

# Resolve the work-tree root from the payload cwd (which may be a SUBDIRECTORY
# of the repo). Not a git work tree → not a project we manage.
# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || exit 0

# This IS the steer source / marketplace repo itself, not a product
# repo — never nag the plugin's own tree. (A product repo has .claude/ for
# settings, never the .claude-plugin/ authoring directory.)
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# A bare, foreign, or half-migrated spec/ must NOT silence the bootstrap nudge —
# only a complete, version-stamped spine (spec/.version + spine files) does.
STATE="$(steer_spine_state "${ROOT}")"
[ "${STATE}" = "managed" ] && exit 0

# A spec/ exists but carries no ownership marker — do not assume it is managed. Offer
# adoption once, softly, rather than the full greenfield bootstrap.
if [ "${STATE}" = "foreign" ]; then
	printf '<!-- steer: spec/ without spec-spine marker -->\n'
	printf '⚠ **This repo has a `spec/` directory but no spec-spine marker (`spec/.version`).** '
	printf 'The org standards are loaded, but this is not a recognized spec spine. If this repo '
	printf 'should be standards-managed, run **`/steer:adopt`** to reconstruct the spine '
	printf 'from the code; otherwise ignore this notice.\n'
	exit 0
fi

# A version-stamped spine is missing required files — repair rather than rebuild.
if [ "${STATE}" = "damaged" ]; then
	printf '<!-- steer: incomplete /spec spine -->\n'
	printf '⚠ **This repo has an incomplete spec spine** (`spec/.version` is present but spine '
	printf 'files are missing). Run **`/steer:sync`** to reconcile it against the '
	printf 'current templates before continuing feature work.\n'
	exit 0
fi

# STATE = unmanaged: no spec/ at all -> onboarding card + bootstrap nudge.
# Lead with the plain-language orientation (what steer is, what you can just
# say), keep the bootstrap routes, and sanction spec-only work (lite mode) so
# thinking a feature through never has to wait on scaffolding. Only CODE needs
# the bootstrap first.
printf '<!-- steer: no /spec spine -->\n'
printf '**This repo is not set up on the org standards yet** (no `/spec` spine). '
printf 'The standards are loaded, and the user does not need to learn any command '
printf -- '— they can just say what they want:\n\n'
printf -- '- **"Help me think an idea/feature through"** -> **`/steer:spec`** works '
printf '**right now, spec-only (lite mode)**: it drafts the feature intent under '
printf '`spec/features/<id>/` with no toolchain or scaffold required, and setup '
printf 'can follow later.\n'
printf -- '- **"Build my app idea"** (non-technical owner, not writing code) -> '
printf '**`/steer:build`** — the guided idea->working-app flow; it bootstraps for '
printf 'you and drives interview, spec, scaffold, and build.\n'
printf -- '- **"Set this repo up properly"** -> **`/steer:init`** (developer '
printf 'greenfield: spine + scaffold + pinned toolchain) or **`/steer:adopt`** '
printf '(substantial existing code: reverse-engineer the spec, triage '
printf 'productionization). `/steer:setup` picks between them.\n\n'
printf '**Before feature CODE is written, the bootstrap is required** — spec-only '
printf 'work is the one sanctioned exception. A "prototype" / "quick" / '
printf '"throwaway" build does not skip it (quick relaxes ceremony, never the '
printf 'scaffold or spine), and a non-app repo does not either: `/steer:init` '
printf 'detects the profile (app / infra / library / cli) and lays the universal '
printf 'core plus only the matching extras — never hand-write toolchain/CI from '
printf 'scratch here.\n\n'
printf 'This notice clears itself once `/spec` exists. (Not a managed product '
printf 'repo? Ignore it.)\n'
