## Spec workflow

`/spec/features/` and `/spec/decisions/` only stay useful if they actually get
populated. **Create the artifact when the trigger fires — do not defer it:**

- **Starting a user-facing feature** → create `/spec/features/[id]/intent.md`
  and `contract.md` (run **`/e22-spec-scaffold <id>`**), before or alongside the
  code. `[id]` is a short kebab-case slug (`user-login`, `export-csv`).
- **Making an architectural or hard-to-reverse choice** (stack, database, auth
  approach, deployment model, a new cross-cutting pattern) → write an ADR at
  `/spec/decisions/000N-[slug].md` (run **`/e22-adr <slug>`**). The initial stack
  choice is usually the first ADR.
- **Behavior changes** → update the relevant `contract.md` in the same PR.

The spec ↔ code coupling rules (drift resolution, what counts as behavior, PO
acceptance) are canonical in the spec-framework reference (opened by
`/e22-spec-scaffold`). If unsure whether something needs a feature spec or an
ADR, ask the dev rather than skipping it.

### Greenfield & Brownfield guidance

**Greenfield** (new product). The starting point can be *anything* — a plain
idea or conversation, a written brief, screenshots, or a Claude Design export.
Do **not** assume a design artifact exists. Your job is to guide the dev/PO to a
real spec:

1. **Interview** to fill `/spec/vision.md` (what it is, why it exists, what
   success looks like, what it is NOT), `/spec/users.md` (who it serves, their
   job-to-be-done), and `/spec/glossary.md` (shared vocabulary). Ask, don't
   invent.
2. Draft initial `/spec/features/[id]/intent.md` files for the capabilities the
   product clearly needs. Keep scope honest — flag anything ambiguous in
   `/spec/SPEC-QUESTIONS.md` instead of guessing.
3. If a Claude Design export exists, read the **local export** (run
   `/e22-design-sources`) — never fetch the URL (it 403s). The design is
   authoritative for visual behavior; the spec for what the system does. Flag
   conflicts in `/spec/SPEC-QUESTIONS.md`.
4. Get PO approval on the intent specs before broad implementation, then build
   under `/apps` and `/packages`, writing `contract.md` as you go.

**Brownfield** (change to an existing product): triage the issue → size it (see
Change-size model) → for medium+ work write/update the spec or ADR first →
implement → update the owning `contract.md` if behavior changed.
