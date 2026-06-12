---
name: e22-sync
description: Bring an already-bootstrapped E22 repo up to date with the current plugin — update the plugin, apply pending structural migrations from the ledger (renames/moves the additive reconciliation can't express), reconcile the materialized spec spine + scaffold against the current templates, re-stamp /spec/.version, and land a PR. Use on a steady-state repo after a plugin release, when a spec file/section was renamed upstream, or when asked to "sync to the latest standards / plugin version". Read-then-propose, never clobbers, never commits to main.
---

# Sync a repo to the current E22 plugin

A repo materializes part of the plugin into itself at bootstrap time — the
`/spec` spine, the bundled scaffold (CI, `mise.toml`, PR template, …). Those
copies are **frozen at the plugin version that wrote them**. `/plugin update`
refreshes the *plugin* (rules, skills, reference prose read in place), but it
does **not** touch the files already on disk. `/e22-sync` closes that gap: it
carries an already-bootstrapped repo forward to the current plugin's
conventions.

This is the steady-state counterpart to the one-time bootstraps. Use it when:

- a plugin release renamed/moved a spec artifact or changed the scaffold, and
  this repo still has the old shape;
- you want a repo's spine + scaffold reconciled against the current templates
  without re-running a full adoption;
- someone asks to "sync to the latest standards / plugin version".

It is **not** a bootstrap (no `/spec` → `/e22-init` or `/e22-adopt`), **not** a
spec-vs-tracker drift check (`/e22-drift`), and **not** a code-health audit
(`/e22-audit`). Those operate on different axes; this one is
**repo-structure-vs-plugin-conventions**.

## Axis at a glance

| Skill | Compares | Edits |
|---|---|---|
| **e22-sync** | materialized spine + scaffold ↔ current plugin conventions | yes (structural; read-then-propose) |
| e22-drift | as-built `/spec` ↔ tracker spec export | no |
| e22-audit | code ↔ standards (leverage-ranked) | no |

## Steps

1. **Confirm it's a sync case.** There must be an existing `/spec` spine — this
   repo already went through `/e22-init` or `/e22-adopt`. If there's **no
   `/spec`**, stop and redirect: `/e22-init` (greenfield / template fork) or
   `/e22-adopt` (existing app to reverse-engineer). Work on a `feat/e22-sync`
   branch — never commit to `main` (commit-autonomy rule). Nothing is committed
   until the dev approves.

2. **Update the plugin first.** The ledger and templates this skill reads are
   only current if the plugin is. Tell the dev to run
   `/plugin update e22-standards@e22-plugins` if they haven't this session, then
   resolve the **current plugin version** from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — never from memory. Call
   this `TARGET`.

3. **Read the repo's stamp.** Read `/spec/.version` for the version the spine was
   last materialized or synced at — call it `FROM`:

   ```sh
   grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+' spec/.version 2>/dev/null || echo "unstamped"
   ```

   `unstamped` means the repo predates stamping (bootstrapped before this
   feature) — treat `FROM` as `0.0.0` and rely on each migration's precondition
   to decide what actually applies. If `FROM` already equals `TARGET`, there are
   no pending migrations; skip to step 5 (additive reconciliation can still find
   template drift) — say so rather than going silent.

4. **Apply pending structural migrations.** Open the ledger at
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/MIGRATIONS.md`. Walk its entries
   oldest→newest. For each entry whose introducing version is **greater than
   `FROM`**, check its **precondition** against the repo; apply the **action**
   only if the precondition holds (entries are idempotent and self-detecting, so
   an entry already applied — or never relevant — is a safe no-op). Because the
   precondition is the real gate, when `FROM` is `unstamped` walk the **whole**
   ledger by precondition. Apply each as the ledger directs: `git mv` for
   renames so history follows, **read-then-propose, never clobber** filled-in
   content. List each migration you're applying (and each skipped, with why)
   before touching files.

5. **Reconcile the materialized templates (additive).** After structural
   migrations, run the standard **Template reconciliation** convention
   (`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`) across the
   copied-in files this repo has — `PRODUCTIONIZATION.md`, each feature's
   `intent.md` / `contract.md`, `tracker.md`, `app/README.md`, and the scaffold
   files (`.github/workflows/ci.yml`, PR template, `mise.toml` tasks, …). For
   each, run the diff command from that convention and **splice in only what's
   missing** — new `##` sections, checklist items, table rows — leaving them
   unchecked/empty. **Purely additive: never overwrite a filled-in value, reorder,
   or delete a dev/PO-added row.** Reference prose (`templates/reference/*`) and
   ADRs are exempt — do not reconcile them (they're read in place / immutable).
   For the scaffold, follow the **copy-and-adapt, never clobber** discipline from
   the scaffold `MANIFEST.md`: diff and merge into existing files (CI, compose,
   config), adapt to the repo's real stack, and never touch working app code.

6. **Re-stamp.** Write `TARGET` into `/spec/.version` (overwrite the old value):

   ```
   # E22 spec-spine version — managed by /e22-init, /e22-adopt, /e22-sync. Do not edit by hand.
   <TARGET>
   ```

7. **Record and hand off.** Append a `/spec/HISTORY.md` entry (what synced —
   `FROM → TARGET`, which migrations applied, which templates reconciled — why,
   who asked, refs). Commit on `feat/e22-sync`, then **propose** opening the PR
   and wait for the dev's confirmation before pushing/creating it — that review
   is the gate. Run the end-of-session checklist.

## Guardrails

- **Structure only, never behavior.** Sync moves/renames artifacts and splices
  in template additions; it does not refactor app code, resolve open questions,
  or re-triage productionization. Code health is `/e22-audit`; drift is
  `/e22-drift`.
- **The ledger is the source of truth for non-additive changes.** Apply
  renames/moves only from `MIGRATIONS.md` entries — never improvise a transform
  from memory of "what changed."
- **Read-then-propose, never clobber.** Diff and ask before touching any file
  that exists; reconcile scaffold into it rather than replacing it; preserve
  every filled-in value. Never touch working app code.
- **Verify versions from disk.** `TARGET` comes from `plugin.json`, `FROM` from
  `/spec/.version` — never from training-data memory.
- **Branch + PR; never commit to `main`** (commit-autonomy rule). The dev's PR
  review is the hard gate; propose the PR, don't push it unasked.
