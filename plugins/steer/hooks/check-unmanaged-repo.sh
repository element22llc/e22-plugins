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
#   itself. Presents BOTH bootstrap routes rather than guessing greenfield-vs-
#   adopt from code volume (a brittle heuristic) — the session picks based on
#   whether the code is being written fresh or already existed.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd is the CONSUMER repo. Fail-soft:
#   any ambiguity → stay silent, never block a session.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"

# Resolve the work-tree root. Not a git work tree → not a project we manage.
ROOT="$(steer_repo_root .)" || exit 0

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

# STATE = unmanaged: no spec/ at all → full greenfield/adopt bootstrap nudge.
printf '<!-- steer: no /spec spine -->\n'
printf '⚠ **This repo has no `/spec` spine.** The org standards are loaded, but '
printf 'nothing has bootstrapped the spec-first workflow here yet — so work risks '
printf 'silently degrading to toolchain conventions only, with feature code '
printf 'written ahead of any vision/intent/contract.\n\n'
printf 'Before writing (or continuing to write) feature code, bootstrap the repo '
printf -- '— pick the path that matches:\n\n'
printf -- '- **Starting a new product from scratch here** (greenfield — you are '
printf 'writing the code; little or no app exists yet) → run **`/steer:init`**. It '
printf 'sets up the `/spec` spine (`vision.md`, `users.md`, `glossary.md`, '
printf 'action history, tracker, app guide), `CLAUDE.md`, and the repo '
printf 'scaffolding from the plugin'"'"'s bundled scaffold, then drives spec-first: each '
printf 'feature through **`/steer:spec-scaffold`** before its code, the initial '
printf 'stack recorded via **`/steer:adr`**.\n'
printf -- '- **Reverse-engineering an existing app** (substantial code already '
printf 'here, not written this session) → run **`/steer:adopt`**. It reconstructs '
printf 'the spec from the code and triages productionization.\n\n'
printf '**A "prototype" / "quick" / "throwaway" build does not skip this.** A '
printf 'prototype is greenfield: it still gets the bundled scaffold (so it costs '
printf 'nothing to graduate) and a `/spec` spine — "quick" relaxes interview depth '
printf 'and per-feature ceremony, never the scaffold or the spine.\n\n'
printf '**A non-app repo does not skip this either.** The universal core — mise '
printf 'toolchain pinning, the `/spec` spine, and stack-agnostic CI hygiene — '
printf 'applies to **every** managed repo, **including infrastructure/IaC '
printf '(Ansible, Terraform, OpenTofu, Pulumi), libraries, and CLIs**. '
printf '`/steer:init` detects the repo **profile** (app / infra / service / '
printf 'library / cli) and lays the core plus only the matching extras — an infra '
printf 'repo gets a tofu/terragrunt/ansible-flavored root `mise.toml` + infra CI, '
printf '*not* `package.json` / `compose.yaml`. Do not skip the bootstrap because '
printf 'the default app scaffold looks like a poor fit; pick the profile instead. '
printf 'Hand-writing toolchain / CI from scratch here is the failure this notice '
printf 'exists to prevent.\n\n'
printf 'This notice clears itself once `/spec` exists. (Not a managed product '
printf 'repo? Ignore it.)\n'
