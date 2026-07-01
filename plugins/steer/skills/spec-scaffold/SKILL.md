---
name: spec-scaffold
description: Create a feature's spec (intent.md + contract.md) from the bundled templates.
when_to_use: "Invoked by /steer:spec, /steer:build, /steer:init, or /steer:adopt with a resolved feature id to instantiate intent.md + contract.md — not a direct entry point."
argument-hint: "[feature-id]"
# Internal one-shot helper: invoked by /steer:spec, build, init,
# and adopt to instantiate the templates. Model-callable, hidden from the slash
# menu, so spec authoring stays a single user-facing entry point (spec / build).
user-invocable: false
---

# Scaffold a feature spec

Create `/spec/features/[id]/intent.md` and `contract.md` for a new user-facing
feature, using the canonical templates bundled with this plugin.

## Steps

1. Determine the feature `[id]` — a short kebab-case slug (`user-login`,
   `export-csv`). Ask the dev if it isn't obvious.
2. Create the folder `spec/features/[id]/` in the product repo. **If it already
   exists**, this `[id]` was scaffolded before — do not clobber it; go to step 3's
   reconcile branch.
3. Instantiate the two spec files from the bundled templates:
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md` → `spec/features/[id]/intent.md`
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-contract.md` → `spec/features/[id]/contract.md`

   For a **new** feature, copy them in. For an **existing** feature (a re-run, or a
   feature spec'd under an older plugin version), **reconcile instead of copy** —
   don't eyeball it; run the diff first and act on its output (per file, intent then
   contract):

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" \
     spec/features/[id]/intent.md "${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md"
   # repeat with contract.md vs feature-contract.md
   ```

   Splice in only the genuinely-new sections/items it reports (empty/unchecked),
   preserving everything already written; never overwrite filled-in
   intent/contract content or re-add a placeholder the dev replaced. Full rules —
   the plugin-wide **Template reconciliation** convention (over-reports handling,
   anchor matching, additive-only):
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md` §"Template
   reconciliation".
4. Fill in what you know from the conversation/issue (feature name, what it does,
   why, in/out of scope). Leave PO-acceptance checkboxes unchecked and flag any
   ambiguity in this feature's own `## Open questions` section rather than
   inventing details (run `/steer:questions` later to drive them to answers).
5. For a Greenfield/design-originated feature, populate the `Design source`
   section per `/steer:reference design-sources`.

## Coupling rules

The spec ↔ code rules (drift resolution, behavior vs. implementation, PO
acceptance, naming) are in the bundled reference at
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md` — read it if you
need the full rules. Key points: specs are organized by feature not code layout;
spec and code change together in the same PR; resolve drift explicitly, never
silently.

`intent.md` is the **what and why** (PO-facing); `contract.md` is the **testable
behavior + data/API surface** (dev-owned). Get PO approval on the intent before
broad implementation.
