---
name: e22-adr
description: Create a numbered ADR from the E22 template.
when_to_use: Use for any hard-to-reverse or cross-cutting choice (stack, database, auth, deployment, new pattern) or when asked to record a decision.
---

# Write an ADR

Create a new Architecture Decision Record at `/spec/decisions/000N-[slug].md` in
the product repo, from the bundled E22 template.

## Steps

1. Decide the next sequential number: list `spec/decisions/` and use the highest
   existing `000N` + 1 (start at `0001`). **Never renumber** existing ADRs.
2. Pick a short kebab-case `[slug]` (`use-postgres-for-search`).
3. Copy `${CLAUDE_PLUGIN_ROOT}/templates/spec/adr.md` → `spec/decisions/000N-[slug].md`.
4. Fill in Context, Decision, Alternatives considered (with rejection reasons),
   and Consequences (positive / negative / neutral). Set Status to `Proposed`
   until accepted; set Deciders.

## When to write one (and when not)

Write an ADR for choices that are hard to reverse (database, auth provider,
deployment platform, tenancy model, major pattern), a new pattern other features
will follow, an explicit rejection of an obvious alternative, or anything a
future dev would ask "why did they do it this way?" about.

Do **not** write one for routine implementation choices, things obvious from the
code, or single-feature decisions (those go in the feature's `contract.md`).

When superseding an ADR, mark the old one `Superseded by [link]` and link the new
one — do not delete or renumber it. Full guidance:
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`.

ADRs are **exempt from template reconciliation** — they are immutable,
point-in-time records. Never retrofit a newer `adr.md` template's sections into an
existing ADR; supersede it with a new one instead.
