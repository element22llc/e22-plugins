---
name: adr
description: Create a numbered ADR from the bundled template.
when_to_use: Use for any hard-to-reverse or cross-cutting choice (stack, database, auth, deployment, new pattern) or when asked to record a decision.
---

# Write an ADR

Create a new Architecture Decision Record at `/spec/decisions/000N-[slug].md` in
the product repo, from the bundled template.

## Steps

1. Decide the next sequential number: list `spec/decisions/` and use the highest
   existing `000N` + 1 (start at `0001`). **Never renumber** existing ADRs.
2. Pick a short kebab-case `[slug]` (`use-postgres-for-search`).
3. Ensure the dir exists (`mkdir -p spec/decisions`), then copy
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/adr.md` → `spec/decisions/000N-[slug].md`.
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
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`.

ADRs are **exempt from template reconciliation** — they are immutable,
point-in-time records. Never retrofit a newer `adr.md` template's sections into an
existing ADR; supersede it with a new one instead.

## Recommend the next action

After drafting the ADR, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. A freshly written ADR
is `Proposed`, so the next step is a human decision — not a command.

| Observed state | Category | Action / suggested command |
|---|---|---|
| ADR drafted, `Status: Proposed` | Human decision required | The Deciders ratify (`Accepted`) or reject it (no command) |
| ADR accepted, supersedes an older one | Recommended | Mark the old ADR `Superseded by [link]` |
| Accepted, no follow-up | Complete | `No action is currently required.` |

The block recommends; ratifying the decision stays with the named Deciders.
