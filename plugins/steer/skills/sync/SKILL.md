---
name: sync
description: Bring an already-bootstrapped managed repo up to date with the current plugin — update the plugin, apply pending structural migrations from the ledger (renames/moves the additive reconciliation can't express), reconcile the materialized spec spine + scaffold against the current templates, repair missing or mis-wired capability-critical scaffold (plugin enablement, in-CI loading, version-pin enforcement, drift gate, branch-protection), re-stamp /spec/.version, and land a PR. Supports a read-only --check mode. Read-then-propose, never clobbers, never commits to main.
when_to_use: 'Use on a steady-state repo after a plugin release, when a spec file/section was renamed upstream, when a repo adopted before a capability existed is missing the scaffold/wiring that enables it, or when asked to "sync to the latest standards / plugin version". Pass --check for a read-only capability + drift report with no branch or PR.'
---

# Sync a repo to the current plugin

A repo materializes part of the plugin into itself at bootstrap time — the
`/spec` spine, the bundled scaffold (CI, `mise.toml`, PR template, …). Those
copies are **frozen at the plugin version that wrote them**. `/plugin update`
refreshes the *plugin* (rules, skills, reference prose read in place), but it
does **not** touch the files already on disk. `/steer:sync` closes that gap: it
carries an already-bootstrapped repo forward to the current plugin's
conventions.

This is the steady-state counterpart to the one-time bootstraps. Use it when:

- a plugin release renamed/moved a spec artifact or changed the scaffold, and
  this repo still has the old shape;
- you want a repo's spine + scaffold reconciled against the current templates
  without re-running a full adoption;
- someone asks to "sync to the latest standards / plugin version".

It is **not** a bootstrap (no `/spec` → `/steer:init` or `/steer:adopt`), **not** a
spec-vs-tracker drift check (`/steer:drift`), and **not** a code-health audit
(`/steer:audit`). Those operate on different axes; this one is
**repo-structure-vs-plugin-conventions**.

## Axis at a glance

| Skill | Compares | Edits |
|---|---|---|
| **sync** | materialized spine + scaffold ↔ current plugin conventions **and capability prerequisites** | yes (structural; read-then-propose) |
| drift | as-built `/spec` ↔ tracker spec export | no |
| audit | code ↔ standards (leverage-ranked) | no |

Pass **`--check`** to run read-only: steps 1–6 detect and report (the migration
preview + the capability status table) but nothing is branched, written, or
PR'd. Use it to see what a full sync would do.

## Steps

1. **Confirm it's a sync case, and capture the base branch.** There must be an
   existing `/spec` spine — this repo already went through `/steer:init`
   or `/steer:adopt`. If there's **no `/spec`**, stop and redirect:
   `/steer:init` (greenfield / template fork) or `/steer:adopt`
   (existing app to reverse-engineer). **Before creating any branch, record the
   currently checked-out branch — call it `BASE`:**

   ```sh
   BASE=$(git rev-parse --abbrev-ref HEAD)
   ```

   `BASE` is the branch the dev invoked the sync from; the sync's PR targets it
   (step 8), so the sync lands back onto the work it continues, not `main`.

   **If invoked as `/steer:sync --check`**, do **not** branch or write anything:
   run steps 2–6 read-only (the migration preview + the capability status table)
   and stop. The rest of this section is the full (writing) flow. Then
   branch a `feat/sync` off `BASE` and work there — never commit to `main` or
   to `BASE` directly (commit-autonomy rule). If `BASE` *is* `main` (the dev ran
   sync from a clean trunk), that's the one case the PR targets `main`. Nothing is
   committed until the dev approves.

2. **Update the plugin first.** The ledger and templates this skill reads are
   only current if the plugin is. Tell the dev to run
   `/plugin update steer@e22-plugins` if they haven't this session, then
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
   ledger by precondition. Apply each as the ledger directs — `git mv` for
   renames so history follows, `git rm` for deletions, or an **in-file token
   rewrite** (replace only the exact old→new string pairs the entry enumerates,
   never a broader match) — all **read-then-propose, never clobber** filled-in
   content. For a token-rewrite entry, run its precondition grep first and show
   the diff of proposed substitutions before applying. List each migration
   you're applying (and each skipped, with why) before touching files.

5. **Reconcile the materialized templates (additive).** After structural
   migrations, run the standard **Template reconciliation** convention
   (`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`) across the
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
   For the **non-Markdown** scaffold files the heading/checklist convention can't
   parse — `.gitignore` and the JSON configs (`.claude/settings.json`,
   `biome.json`, `configs/tsconfig.base.json`) — reconcile with the
   structured helper instead, which is additive and never overwrites an existing
   value or line:

   ```
   # check (read-only): empty output = current; any output = additive delta
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" \
     auto .gitignore "${CLAUDE_PLUGIN_ROOT}/templates/scaffold/gitignore"
   # apply the additive merge once you've shown the delta
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" \
     auto .claude/settings.json \
     "${CLAUDE_PLUGIN_ROOT}/templates/scaffold/claude/settings.json" --apply
   ```

   This is the **content**-level merge (permission lists, companion-plugin
   entries, config keys). For the `permissions` block it also **de-conflicts
   across precedence tiers** (deny > ask > allow): a pattern that would end up
   in two tiers — e.g. a locally allow-listed `Bash(git push)` meeting the
   template's `ask` copy — is kept only in its most-restrictive tier, so the
   merge never leaves a contradictory `allow`+`ask` pair (a `-` line in the
   delta shows the dropped copy). The plugin-*enablement* wiring inside
   `.claude/settings.json` — the `steer@e22-plugins` marker — is separately
   verified by capability repair (step 6); both are additive and the merge here
   never flips an existing value, so a deliberate `"steer@e22-plugins": false`
   opt-off is preserved.

   **No `.mcp.json` reconcile.** The `github` + `markitdown` MCP servers ship
   with the **plugin** (`plugins/steer/.mcp.json`), not the scaffold — so they
   refresh with the `/plugin update` in step 2 and are **not** part of scaffold
   reconciliation; there is no scaffold template to diff a repo `.mcp.json`
   against. A repo bootstrapped before v2.11.0 still has the old repo-local
   `.mcp.json`, whose entries now duplicate the plugin's; the **v2.11.0 migration
   in step 4** removes the redundant copy (or just the duplicated keys, keeping
   product-specific servers). Don't reconcile `.mcp.json` here.

6. **Repair capability gaps (missing / mis-wired scaffold wiring).** Additive
   reconciliation (step 5) only splices into files that *already exist* and the
   ledger only transforms files that exist — so a repo adopted before a
   capability shipped (or that lost a wiring file) silently lacks it, and the
   sync so far would report "current." Close that here. Run the read-only
   detector and walk the capability map:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-capabilities.sh" .
   ```

   It prints one `id<TAB>status<TAB>files` line per capability
   (`present-wired | absent | mis-wired | disabled | n/a`) plus a `stack`
   fingerprint, on stdout (gaps are **not** a nonzero exit). For each capability
   read its entry in
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/CAPABILITIES.md` for the repair
   semantics + conditionality, then:

   - **`present-wired` / `n/a` / `disabled`** → nothing to do. `n/a` means the
     conditional predicate doesn't apply (wrong stack/tracker) — never re-add it.
     `disabled` (a `"steer@e22-plugins": false`) is a deliberate opt-off — respect
     it. There is no opt-out file; a deliberately-dropped *always* capability will
     re-appear as a proposal each sync and the dev declines it.
   - **`absent`** → **create** the file(s) from the bundled scaffold
     (copy-and-adapt per the scaffold `MANIFEST.md`), adapting to the repo's real
     stack. `compose.yaml` is the exception: its need isn't knowable — **propose
     only after confirming with the dev**, and when uncertain, ask rather than
     create.
   - **`mis-wired`** → for `verbatim` files (the version-pin scripts) **re-copy**
     from the plugin source — but **show the diff first** and warn that local
     edits are lost (move product-specific pins to `policy/versions.yml`). For
     everything else, **additively splice** only the named wiring marker (the
     `steer@e22-plugins` entry, a CI step, a PR-template section), preserving every
     existing key/step — never clobber.

   Some repairs need a human/external step sync can't do: `claude.yml` is inert
   without the org `STEER_APP_ID`/`STEER_APP_PRIVATE_KEY` — create it but report it
   **`wired-pending-secret`**, don't claim it's enabled; `branch-protection.yml`
   is written here but applied server-side by `/steer:protect`.

   Emit a **capability status table** (this is the whole output under `--check`):

   ```markdown
   | Capability | Files | Status | Action |
   |---|---|---|---|
   | plugin-enabled-local | .claude/settings.json | mis-wired | splice enabledPlugins.steer (proposed) |
   | in-ci-plugin-loading | .github/workflows/claude.yml | absent | create from scaffold (proposed); needs STEER_APP_ID |
   | version-pin-enforcement | policy/versions.yml, scripts/… | mis-wired | re-copy verbatim scripts (proposed, diff shown) |
   | drift-gate | .github/workflows/ci.yml, PR template | present-wired | none |
   | branch-protection-policy | policy/branch-protection.yml | absent | create (proposed); apply via /steer:protect |
   | github-issue-forms | .github/ISSUE_TEMPLATE/* | n/a | none (tracker ≠ github) |
   ```

   **`--check` stops here**: print the migration preview + this table and exit —
   no branch, no writes, no PR. Otherwise apply the proposed repairs on
   `feat/sync` under the read-then-propose discipline and carry on.

7. **Re-stamp.** Write `TARGET` into `/spec/.version` (overwrite the old value):

   ```
   # Spec-spine version — managed by /steer:init, /steer:adopt, /steer:sync. Do not edit by hand.
   <TARGET>
   ```

8. **Record and hand off.** Append a `/spec/HISTORY.md` entry (what synced —
   `FROM → TARGET`, which migrations applied, which templates reconciled, which
   capability gaps repaired — why, who asked, refs). Commit on `feat/sync`, then
   **propose** opening the PR
   **against `BASE`** (the branch captured in step 1) and wait for the dev's
   confirmation before pushing/creating it — that review is the gate. The PR base
   is **always `BASE`**, not `main` — the sync rejoins the work it continues. Do
   not ask the dev which base to use; state that the PR targets `BASE` and let
   them correct it if wrong. When you create it:

   ```sh
   gh pr create --base "$BASE" --head feat/sync ...
   ```

   Run the end-of-session checklist.

9. **Recommend the next action.** Emit a `## Recommended next actions` block per
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, derived from the
   sync's state.

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Failed migration or merge conflict | Blocking now | Resolve it before continuing |
   | Pending migrations in the ledger | Blocking now (next transition) | Apply them |
   | Reconcile or capability-repair batch proposed, not approved | Human decision required | Dev reviews the proposed batch (no command) |
   | Capability needs an external secret/config (`claude.yml` org App; branch protection) | Human decision required | Dev adds `STEER_APP_ID`/secret, or applies the gate via `/steer:protect` |
   | Capability follow-up after a created file (Issue Forms added) | Recommended | `/steer:issues bootstrap-labels` |
   | Sync PR open, awaiting review | Human decision required | A dev reviews/merges the PR (no command) — execution is done, integration is not |
   | Nothing pending; `/spec/.version` current; all capabilities present-and-wired | Complete | `No action is currently required.` |

   Pick one `Current recommended action` by precedence (a failed migration
   outranks a capability gap). An opened-but-unmerged sync PR is **not**
   `Complete`. Never clobbers, never commits to `main`.

## Guardrails

- **Structure only, never behavior.** Sync moves/renames artifacts and splices
  in template additions; it does not refactor app code, resolve open questions,
  or re-triage productionization. Code health is `/steer:audit`; drift is
  `/steer:drift`.
- **The ledger is the source of truth for non-additive changes.** Apply
  renames/moves/in-file rewrites only from `MIGRATIONS.md` entries — never
  improvise a transform from memory of "what changed."
- **Capability repair is presence + wiring only.** `CAPABILITIES.md` is the
  source of truth for which files unlock which capability and how to repair a gap.
  Create a capability-critical file only when its conditional predicate applies
  and it isn't `disabled`; re-copy a `verbatim` script only because it's
  contractually identical (after showing the diff); otherwise splice the named
  marker / propose, never clobber. Don't broaden into app code (`/steer:audit`)
  or spec↔tracker drift (`/steer:drift`).
- **Read-then-propose, never clobber.** Diff and ask before touching any file
  that exists; reconcile scaffold into it rather than replacing it; preserve
  every filled-in value. Never touch working app code.
- **Verify versions from disk.** `TARGET` comes from `plugin.json`, `FROM` from
  `/spec/.version` — never from training-data memory.
- **Branch + PR; never commit to `main`** (commit-autonomy rule). The dev's PR
  review is the hard gate; propose the PR, don't push it unasked.
- **The PR targets `BASE`, never `main` by default.** `BASE` is the branch the
  dev invoked the sync from (captured in step 1), so the sync lands back onto the
  work it continues. Only when `BASE` is itself `main` does the PR target `main`.
  Never silently default `gh pr create` to the repo's default branch, and never
  ask the dev to pick the base — `BASE` already answers that.
