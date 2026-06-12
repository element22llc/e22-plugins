---
description: Bring an already-bootstrapped E22 repo up to date with the current plugin — update the plugin, apply pending structural migrations from the ledger (renames/moves the additive reconciliation can't express), reconcile the materialized spec spine + scaffold against the current templates, re-stamp /spec/.version, and land a PR. Read-then-propose, never clobbers, never commits to main.
---

Sync this repo to the current E22 plugin by following the `e22-sync` skill.

`/e22-sync` is the steady-state counterpart to the one-time bootstraps: where
`/e22-init` and `/e22-adopt` *materialize* the `/spec` spine and bundled scaffold
into a repo, sync carries an already-bootstrapped repo **forward** when the
plugin's conventions later change. `/plugin update` refreshes the plugin itself
(rules, skills, reference prose); it does not touch the files already copied onto
disk. This skill closes that gap.

If there's **no `/spec` spine**, stop and redirect — `/e22-init` (greenfield /
template fork) or `/e22-adopt` (existing app to reverse-engineer). This is not a
bootstrap, not `/e22-drift` (spec-vs-tracker), and not `/e22-audit`
(code-vs-standards) — it operates on the **repo-structure-vs-plugin-conventions**
axis.

Step 1: confirm a `/spec` exists and work on a `feat/e22-sync` branch. Step 2:
update the plugin and resolve the current version (`TARGET`) from
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. Step 3: read `/spec/.version`
(`FROM`). Step 4: apply each pending migration from
`${CLAUDE_PLUGIN_ROOT}/templates/reference/MIGRATIONS.md` whose precondition
holds (`git mv` for renames; read-then-propose). Step 5: run the additive
**Template reconciliation** across the materialized spine + scaffold files —
splice in only what's missing, never overwrite filled-in content. Step 6:
re-stamp `/spec/.version` to `TARGET`. Step 7: append a `/spec/HISTORY.md` entry
and **propose** the PR (don't push unasked). Structure only — never refactors app
code, resolves questions, or re-triages productionization; never commits to
`main`.
