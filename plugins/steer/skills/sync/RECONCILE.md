# `/steer:sync` — steps 5, 6 & 6.5: template reconciliation, capability repair, invocation hygiene

Read this file when you reach step 5 of `/steer:sync`. Steps 1–4 (confirm,
update the plugin, read the stamp, apply ledger migrations) and steps 7–9
(re-stamp, record, recommend) stay in `SKILL.md`, as do the guardrails. Under
`--check` these two steps **detect and report only** — nothing is written.

5. **Reconcile the materialized templates (additive).** After structural
   migrations, run the standard **Template reconciliation** convention
   (`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md` §"Template
   reconciliation") across the copied-in files this repo has —
   `PRODUCTIONIZATION.md`, each feature's `intent.md` / `contract.md`,
   `tracker.md`, `app/README.md`, and the scaffold files
   (`.github/workflows/ci.yml`, PR template, `mise.toml` tasks, …): for each, run
   that convention's diff command and splice in only what's missing, additive-only
   (never overwrite, reorder, or delete a dev/PO-added row). Reference prose
   (`templates/reference/*`) and ADRs are exempt — do not reconcile them (they're
   read in place / immutable).
   For the scaffold, follow the **copy-and-adapt, never clobber** discipline from
   the scaffold `MANIFEST.md`: diff and merge into existing files (CI, compose,
   config), adapt to the repo's real stack, and never touch working app code.
   For the **non-Markdown** scaffold files the heading/checklist convention can't
   parse — the line-based `.gitignore`, `.gitattributes` and `.worktreeinclude`,
   and the JSON configs (`.claude/settings.json`,
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

   **No `.mcp.json` reconcile.** The `github` and `context7` MCP
   servers ship with the **plugin** (`plugins/steer/.mcp.json`), not the scaffold — so they
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
   (`present-wired | absent | mis-wired | disabled | n/a`) plus two
   informational fingerprints, `stack` and `profile` — report both, repair
   neither — on stdout (gaps are **not** a nonzero exit). For each capability
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
     stack. **Two exceptions wait for a yes rather than being created:**
     `compose.yaml`, whose need isn't knowable — when uncertain, ask rather than
     create an unused one — and `.gitattributes`
     (`line-ending-normalization`), which changes how git treats every subsequent
     write in the repo. For the latter, propose it as:

     ```text
     .gitattributes absent → propose:
       "Add LF normalization? (from templates/scaffold/gitattributes)"
       affects future writes only; does NOT run `git add --renormalize .`
     ```

     Install the scaffold file **as `.gitattributes`** (the scaffold stores
     dotfiles without their leading dot) and say plainly that existing committed
     CRLF is untouched — renormalizing history is a deliberate one-shot that stays
     the human's call. This is the **create-missing** path only; a repo that
     *has* a `.gitattributes` gets its content reconciled additively in step 5.
   - **`mis-wired`** → for `verbatim` files **re-copy** from the plugin source —
     but **show the diff first** (or, for a generated set, the changed-file list)
     and warn that local edits are lost. Two capabilities are `verbatim`: the
     **version-pin scripts** (move product-specific pins to `policy/versions.yml`)
     and the **generated Copilot surface** (`copilot-surface-current` —
     `.github/copilot-instructions.md`, `prompts/`, `agents/`, `instructions/`;
     repo-specific Copilot guidance lives in a *separate* `*.instructions.md` the
     consumer owns, which the re-copy never touches). This re-copy is the whole
     refresh path for Copilot after a plugin update — Copilot has no SessionStart
     hook, so without it that surface stays frozen at the bootstrapping version.
     For everything else, **additively splice** only the named wiring marker (the
     `steer@e22-plugins` entry, a CI step, a PR-template section), preserving every
     existing key/step — never clobber.

   Some repairs need a human/external step sync can't do: `branch-protection.yml`
   is written here but applied server-side by `/steer:protect`. (`claude.yml`
   needs only the `ANTHROPIC_API_KEY` secret to run — the marketplace repo is
   public, so the plugin clone is anonymous and needs no credential.)

   Emit a **capability status table** (this is the whole output under `--check`):

   ```markdown
   | Capability | Files | Status | Action |
   |---|---|---|---|
   | plugin-enabled-local | .claude/settings.json | mis-wired | splice enabledPlugins.steer (proposed) |
   | delivery-mode-declared | CLAUDE.md | mis-wired | splice ## Delivery mode, default pr-flow (proposed); ask if solo-trunk fits |
   | in-ci-plugin-loading | .github/workflows/claude.yml | absent | create from scaffold (proposed); needs ANTHROPIC_API_KEY secret |
   | version-pin-enforcement | policy/versions.yml, scripts/… | mis-wired | re-copy verbatim scripts (proposed, diff shown) |
   | drift-gate | .github/workflows/ci.yml, PR template | present-wired | none |
   | branch-protection-policy | policy/branch-protection.yml | absent | create (proposed); apply via /steer:protect |
   | line-ending-normalization | .gitattributes | absent | create from scaffold (proposed, needs a yes); future writes only, no renormalize |
   | github-issue-forms | .github/ISSUE_TEMPLATE/* | n/a | none (tracker ≠ github) |
   ```

   **Under `--check`**, don't branch or write — continue to step 6.5 (invocation
   hygiene) and stop *there*; that is where `--check` ends, not here. Otherwise
   apply the proposed repairs on `feat/sync` under the read-then-propose discipline
   and carry on.

6.5. **Repair invocation hygiene (stale / invalid slash invocations in live prose).**
   A repo's live instruction prose (`CLAUDE.md`, `README.md`,
   `.github/pull_request_template.md`) is frozen at the version that wrote it, so a
   skill rename, a skill folded into a `reference` mode, or a skill turned
   `user-invocable: false` leaves invocations that no longer resolve — and Claude
   Code has no built-in check that a referenced skill exists. The v2.0.0 ledger
   migration (step 4) rewrites the pre-rebrand `/e22-*` tokens once; this step is the
   **standing** every-sync backstop that also catches the post-rebrand classes and
   any later drift. Run the read-only detector:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-invocations.sh" .
   ```

   It derives the *valid* invocation surface live from the plugin (skill names, the
   `user-invocable: false` set, and the `reference` modes) — so it never goes stale —
   and prints one TAB line per problem occurrence,
   `<file>\t<lineno>\t<found>\t<class>\t<suggested-fix>` (clean repo = silent; findings
   are on stdout, never a nonzero exit). See
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/INVOCATION.md` → "Drift detection &
   auto-repair" for the class semantics. Then, read-then-propose on `feat/sync`:

   - **`legacy-e22`** and **`reference-mode`** → **deterministic**: apply the exact
     `suggested-fix` token rewrite (a bare `reference`-mode invocation becomes
     `/steer:reference <mode>`), showing the diff. Replace only the flagged tokens —
     never a broader match, never the marketplace id.
   - **`noncallable-gateway`** → the fix is a **front-door swap that changes meaning**
     (e.g. `/steer:spec-scaffold <id>` → `/steer:spec`; `/steer:tracker-sync` →
     `/steer:issues`), so **propose it and let the dev confirm** — do not auto-rewrite.
   - **`unknown`** → a token that resolves to no skill/mode (e.g. a removed skill) →
     **surface only**, no rewrite; the dev decides.

   The detector scans only live instruction surfaces and deliberately skips
   append-only/provenance prose (`spec/history/*`, the frozen `spec/HISTORY.md`, `spec/AUDIT-REPORT.md`, `spec/DRIFT-REPORT.md`, ADRs, feature
   `intent.md` provenance) — a past `e22-adopt` mention there is a legitimate record, not
   live guidance. **`--check` stops here**: print the findings and exit — no writes.
