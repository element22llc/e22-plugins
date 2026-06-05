---
name: e22-spec-scaffold
description: Create a feature's spec (intent.md + contract.md) from the E22 templates. Use when starting a user-facing feature or asked to spec out / scaffold a feature.
---

# Scaffold a feature spec

Create `/spec/features/[id]/intent.md` and `contract.md` for a new user-facing
feature, using the canonical E22 templates bundled with this plugin.

## Steps

1. Determine the feature `[id]` — a short kebab-case slug (`user-login`,
   `export-csv`). Ask the dev if it isn't obvious.
2. Create the folder `spec/features/[id]/` in the product repo.
3. Copy the bundled templates into it:
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md` → `spec/features/[id]/intent.md`
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-contract.md` → `spec/features/[id]/contract.md`
4. Fill in what you know from the conversation/issue (feature name, what it does,
   why, in/out of scope). Leave PO-acceptance checkboxes unchecked and flag any
   ambiguity in `/spec/SPEC-QUESTIONS.md` rather than inventing details.
5. For a Greenfield/design-originated feature, populate the `Design source`
   section per `/e22-design-sources`.

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
