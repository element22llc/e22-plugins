---
name: steer-spec-scaffold
description: Create a feature's spec (intent.md + contract.md) from the bundled templates, or additively reconcile an existing one without overwriting filled-in content.
argument-hint: '[feature-id]'
user-invocable: false
---

<!-- Generated from the steer plugin's skills/spec-scaffold/SKILL.md — do not edit by hand.
     Refresh with /steer:sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Invoked by /steer-spec, /steer-build, /steer-init, /steer-adopt, or /steer-intake with a resolved feature id — not a direct entry point.

# Scaffold a feature spec

Create `/spec/features/[id]/intent.md` and `contract.md` for a new user-facing
feature, using the canonical templates bundled with this plugin.

## Steps

1. Determine the feature `[id]` — a short kebab-case slug (`user-login`,
   `export-csv`). Ask the dev if it isn't obvious.
2. Create the folder `spec/features/[id]/` **in the repo that owns the product
   spine**. Normally that is this repo — but in a polyrepo **member**
   (`spec/PRODUCT.md` present) all of `spec/features/**` belongs to the
   **workspace**: resolve it via `workspace.path`, else the GitHub gateway, and
   create the feature there. **Never** create `spec/features/**` in a member; if
   the workspace is unreachable by either route, say so and stop rather than
   writing locally (`/steer-reference polyrepo`). **If the folder already
   exists**, this `[id]` was scaffolded before — do not clobber it; go to step 3's
   reconcile branch.
3. Instantiate the two spec files from the bundled templates:
   - `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/spec/feature-intent.md` → `spec/features/[id]/intent.md`
   - `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/spec/feature-contract.md` → `spec/features/[id]/contract.md`

   For a **new** feature, copy them in. For an **existing** feature (a re-run, or a
   feature spec'd under an older plugin version), **reconcile instead of copy** —
   don't eyeball it; run the diff first and act on its output (per file, intent then
   contract):

   ```sh
   sh "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/scripts/template-reconcile.sh" \
     spec/features/[id]/intent.md "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/spec/feature-intent.md"
   # repeat with contract.md vs feature-contract.md
   ```

   Splice in only the genuinely-new sections/items it reports (empty/unchecked),
   preserving everything already written; never overwrite filled-in
   intent/contract content or re-add a placeholder the dev replaced. Full rules —
   the plugin-wide **Template reconciliation** convention (over-reports handling,
   anchor matching, additive-only):
   `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/SPEC-FRAMEWORK.md` §"Template
   reconciliation".
4. Fill in what you know from the conversation/issue (feature name, what it does,
   why, in/out of scope). Leave PO-acceptance checkboxes unchecked and flag any
   ambiguity in this feature's own `## Open questions` section rather than
   inventing details (run `/steer-questions` later to drive them to answers).
5. For a Greenfield/design-originated feature, populate the `Design source`
   section per `/steer-reference design-sources`.

## Coupling rules

The spec ↔ code rules (drift resolution, behavior vs. implementation, PO
acceptance, naming) are in the bundled reference at
`https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/SPEC-FRAMEWORK.md` — read it if you
need the full rules. Key points: specs are organized by feature not code layout;
spec and code change together in the same PR; resolve drift explicitly, never
silently.

`intent.md` is the **what and why** (PO-facing); `contract.md` is the **testable
behavior + data/API surface** (dev-owned). Get PO approval on the intent before
broad implementation.
