## Spec workflow

Create the artifact when the trigger fires - don't defer it:

- **Starting a user-facing feature** -> `/spec/features/[id]/intent.md` +
  `contract.md` (`[id]` a kebab-case slug), before or alongside the code, via
  **`/steer:spec`** (**`/steer:build`** for a PO).
- **Hard-to-reverse or cross-cutting choice** (stack, database, auth,
  deployment) -> ADR at `/spec/decisions/000N-[slug].md` (**`/steer:spec adr`**).
  **The bar is reversal cost, not novelty** - a pattern used once is a
  `contract.md` line until a third use makes it house style.
- **Behavior changes** -> the owning `contract.md` in the same PR, plus the app
  guide (`/spec/app/`) if it describes the old behavior.
- **Open questions** -> the feature's `intent.md` -> `## Open questions`
  (product-level ones in `vision.md`), **never a guessed answer**; resolve them
  with **`/steer:spec questions`**.
- **A feature that began as a tracker issue** -> shaped in the issue by
  **`/steer:work issues brainstorm`**, written as a `Status: draft` intent by
  **`materialize`**, approved only by an explicit `/steer:spec approve`.

Unsure whether it needs a feature spec or an ADR? Ask the dev. No spine yet ->
`/steer:setup` before any feature code, never a hand-written `package.json`,
build config or CI. **Brownfield**: classify (Change classification), spec or
ADR first for Behavioral and High-risk work, implement, update the owning
`contract.md`. A committed design export is a spec to realize, not code to ship
(`/steer:reference design-sources`).

### Durable decisions land in the spine, not in side-channels

A durable decision - stack, auth model, data model, architecture, a locked scope
or MVP cut - goes in an `intent.md`, a `contract.md` or an ADR, with its
ratifier and date. Chat, summaries and assistant memory are working notes, never
the record. **No spine yet? Bootstrap before you record the decision.**

Every other durable project fact gets a home on disk too - a test, the spec, the
app guide, an issue, the product `CLAUDE.md` - never Claude Code's auto memory,
which no teammate sees. Auto memory keeps only the personal; where it
contradicts the repo, the repo wins.

### Living documentation - document in parallel, not after

Translate what the conversation and the code reveal into the owning artifact
**in the same change as the code**, never in a wrap-up pass: acceptance ->
`intent.md` (scope changes need PO approval); behavior, data and API ->
`contract.md`; usage and release notes -> the app guide; stack and data flow ->
`ARCHITECTURE.md` and its diagram; visual identity -> `DESIGN.md`. Full routing table:
**`/steer:reference traceability`**.

- A **notable event** - ratified decision, scope change, absorbed PO document,
  incident -> a new file under `/spec/history/` (`YYYY-MM-DD-HHMM-<slug>.md`),
  immutable once merged. **An ordinary merged change writes none.**
- **Applying a decision already made is not a new decision.** Propagate it in
  the same change and let the PR be the gate; pause only on an unmade decision
  or an edit that would clobber filled-in content.
- **Internal ids stay out of end-user surfaces.** ADR ids, tracker refs,
  `Q-NNN`, feature slugs and `spec/**` paths never reach app UI copy or the app
  guide's user-facing copy and release notes.
