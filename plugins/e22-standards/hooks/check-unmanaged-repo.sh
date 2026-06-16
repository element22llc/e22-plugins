#!/usr/bin/env sh
# e22-standards SessionStart hook — unmanaged-repo detector (greenfield nudge).
#
# WHY THIS EXISTS
#   A repo with the plugin enabled but no /spec spine still gets the always-on
#   rules injected — yet nothing PUSHES the spec-first bootstrap. So a session
#   silently degrades to "toolchain conventions only" and writes feature code
#   with no vision/intent/contract behind it (the exact failure that prompted
#   this hook: a brand-new non-template repo where code was written from scratch
#   with the plugin active, but the spec spine never appeared). The drift and
#   open-questions hooks only fire once /spec ALREADY exists — they cannot catch
#   a repo that never got a spine. /e22-standards:e22-init (plugin-driven bootstrap, or a
#   legacy fork) and /e22-standards:e22-adopt (reverse-engineer existing code) are the fixes,
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
ROOT="$(e22_repo_root .)" || exit 0

# This IS the e22-standards source / marketplace repo itself, not a product
# repo — never nag the plugin's own tree. (A product repo has .claude/ for
# settings, never the .claude-plugin/ authoring directory.)
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# A bare, foreign, or half-migrated spec/ must NOT silence the bootstrap nudge —
# only a complete, version-stamped spine (spec/.version + spine files) does.
STATE="$(e22_spine_state "${ROOT}")"
[ "${STATE}" = "managed" ] && exit 0

# A spec/ exists but carries no E22 ownership marker — do not assume E22. Offer
# adoption once, softly, rather than the full greenfield bootstrap.
if [ "${STATE}" = "foreign" ]; then
	printf '<!-- e22-standards: spec/ without E22 spine marker -->\n'
	printf '⚠ **This repo has a `spec/` directory but no E22 spine marker (`spec/.version`).** '
	printf 'The org standards are loaded, but this is not a recognized E22 spine. If this repo '
	printf 'should be E22-managed, run **`/e22-standards:e22-adopt`** to reconstruct the spine '
	printf 'from the code; otherwise ignore this notice.\n'
	exit 0
fi

# A version-stamped spine is missing required files — repair rather than rebuild.
if [ "${STATE}" = "damaged" ]; then
	printf '<!-- e22-standards: incomplete /spec spine -->\n'
	printf '⚠ **This repo has an incomplete E22 spine** (`spec/.version` is present but spine '
	printf 'files are missing). Run **`/e22-standards:e22-sync`** to reconcile it against the '
	printf 'current templates before continuing feature work.\n'
	exit 0
fi

# STATE = unmanaged: no spec/ at all → full greenfield/adopt bootstrap nudge.
printf '<!-- e22-standards: no /spec spine -->\n'
printf '⚠ **This repo has no `/spec` spine.** The org standards are loaded, but '
printf 'nothing has bootstrapped the spec-first workflow here yet — so work risks '
printf 'silently degrading to toolchain conventions only, with feature code '
printf 'written ahead of any vision/intent/contract.\n\n'
printf 'Before writing (or continuing to write) feature code, bootstrap the repo '
printf -- '— pick the path that matches:\n\n'
printf -- '- **Starting a new product from scratch here** (greenfield — you are '
printf 'writing the code; little or no app exists yet) → run **`/e22-standards:e22-init`**. It '
printf 'sets up the `/spec` spine (`vision.md`, `users.md`, `glossary.md`, '
printf 'action history, tracker, app guide), `CLAUDE.md`, and the repo '
printf 'scaffolding from the plugin'"'"'s bundled scaffold, then drives spec-first: each '
printf 'feature through **`/e22-standards:e22-spec-scaffold`** before its code, the initial '
printf 'stack recorded via **`/e22-standards:e22-adr`**.\n'
printf -- '- **Reverse-engineering an existing app** (substantial code already '
printf 'here, not written this session) → run **`/e22-standards:e22-adopt`**. It reconstructs '
printf 'the spec from the code and triages productionization.\n\n'
printf 'This notice clears itself once `/spec` exists. (Not an Element 22 product '
printf 'repo? Ignore it.)\n'
