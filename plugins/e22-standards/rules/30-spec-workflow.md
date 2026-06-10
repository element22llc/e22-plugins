## Spec workflow

`/spec/features/` and `/spec/decisions/` only stay useful if they actually get
populated. **Create the artifact when the trigger fires — do not defer it:**

- **Starting a user-facing feature** → `/spec/features/[id]/intent.md` +
  `contract.md` (run **`/e22-spec-scaffold <id>`**), before or alongside the
  code. `[id]` is a short kebab-case slug (`user-login`, `export-csv`).
- **Architectural or hard-to-reverse choice** (stack, database, auth approach,
  deployment model, a new cross-cutting pattern) → ADR at
  `/spec/decisions/000N-[slug].md` (run **`/e22-adr <slug>`**). The initial
  stack choice is usually the first ADR.
- **Behavior changes** → update the relevant `contract.md` in the same PR.
- **Open questions** → live in each feature's `intent.md` → `## Open questions`
  (product-level ones in `vision.md`); run **`/e22-questions`** to sweep and
  answer them before they rot.

The spec ↔ code coupling rules (drift resolution, what counts as behavior, PO
acceptance) are canonical in the spec-framework reference (opened by
`/e22-spec-scaffold`). If unsure whether something needs a feature spec or an
ADR, ask the dev rather than skipping it.

**Greenfield** (new product): the input can be anything — an idea, a brief,
screenshots, or a Claude Design export; don't assume a design artifact exists.
Interview first to fill `/spec/vision.md`, `users.md`, `glossary.md` (ask,
don't invent; product-level ambiguity → `vision.md` → `## Open questions`),
draft feature intents,
and get PO approval before broad implementation. The full step-by-step flow is
in the spec-framework reference (`/e22-spec-scaffold`); a PO driving it uses
**`/e22-build`**. Design exports: read the **local export** via
`/e22-design-sources` — never fetch the URL (it 403s).

**Brownfield** (change to an existing product): triage → size it (Change-size
model) → medium+ work writes/updates the spec or ADR first → implement →
update the owning `contract.md` if behavior changed.

**Adopting a whole repo** that was never forked from the template (a
"vibe-coded" app with no `/spec`): run **`/e22-adopt`** once to reverse-engineer
the spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject
per area in `PRODUCTIONIZATION.md`), and sync in the template
scaffolding — distinct from a per-feature Brownfield change above.
