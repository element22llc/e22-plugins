---
name: e22-spec-scaffold
description: Create a feature's spec (intent.md + contract.md) from the E22 templates.
when_to_use: Use when starting a user-facing feature or asked to spec out or scaffold a feature.
argument-hint: "[feature-id]"
---

# Scaffold a feature spec

Create `/spec/features/[id]/intent.md` and `contract.md` for a new user-facing
feature, using the canonical E22 templates bundled with this plugin.

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
   comm -13 \
     <(grep -hE '^(#{2,3} |- \[)' spec/features/[id]/intent.md | sed -E 's/\[[xX]\]/[ ]/' | sort -u) \
     <(grep -hE '^(#{2,3} |- \[)' "${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md" | sed -E 's/\[[xX]\]/[ ]/' | sort -u)
   # repeat with contract.md vs feature-contract.md
   ```

   It surfaces the sections the current templates add that the files lack (it
   over-reports filled/reworded lines — treat it as a candidate list). Splice the
   genuinely-new ones in empty, preserving everything already written; never
   overwrite filled-in intent/contract content and never re-add a placeholder the
   dev replaced. This is the plugin-wide **Template reconciliation** convention:
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`.
4. Fill in what you know from the conversation/issue (feature name, what it does,
   why, in/out of scope). Leave PO-acceptance checkboxes unchecked and flag any
   ambiguity in this feature's own `## Open questions` section rather than
   inventing details (run `/e22-standards:e22-questions` later to drive them to answers).
5. For a Greenfield/design-originated feature, populate the `Design source`
   section per `/e22-standards:e22-design-sources`.

## Coupling rules

The spec ↔ code rules (drift resolution, behavior vs. implementation, PO
acceptance, naming) are in the bundled reference at
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md` — read it if you
need the full rules. Key points: specs are organized by feature not code layout;
spec and code change together in the same PR; resolve drift explicitly, never
silently.

`intent.md` is the **what and why** (PO-facing); `contract.md` is the **testable
behavior + data/API surface** (dev-owned). Get PO approval on the intent before
broad implementation.
