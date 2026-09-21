## Spec workflow

Create the artifact when the trigger fires - don't defer it:

- **Starting a user-facing feature** -> `/spec/features/[id]/intent.md` +
  `contract.md`, before or alongside the code - author via **`/steer:spec`**
  (**`/steer:build`** for a PO). `[id]` is a kebab-case slug (`user-login`).
- **Hard-to-reverse or cross-cutting choice** (stack, database, auth,
  deployment) -> ADR at `/spec/decisions/000N-[slug].md` (**`/steer:spec adr`**).
  **The bar is reversal cost, not novelty** - a pattern used once is a
  `contract.md` line until a third use makes it house style.
- **Behavior changes** -> the owning `contract.md` in the same PR, plus the app
  guide (`/spec/app/`) if it describes the old behavior.
- **Open questions** -> the feature's `intent.md` -> `## Open questions`
  (product-level ones in `vision.md`); answer them with
  **`/steer:spec questions`** before they rot.
- **A feature that began as a tracker issue** -> **`/steer:work issues
  brainstorm`** shapes it in the issue, **`materialize`** writes that intent as
  `Status: draft`, and an explicit `/steer:spec approve` flips it to `approved`.
  The issue is the work record; the spec stays product truth.

Unsure whether something needs a feature spec or an ADR? Ask the dev rather than
skipping it.

**No spine yet, or a repo that never went through bootstrap?** That is
`/steer:setup`, and it comes **before** feature code - the scaffold and the
spine, never a hand-written `package.json`, build config or CI. "Quick" or
"throwaway" relaxes the *ceremony*, never either of those. **Brownfield** is
triage -> classify (Change classification) -> spec or ADR first for Behavioral
and High-risk work -> implement -> update the owning `contract.md`.

**UI work.** A committed design export is a spec to realize in the standard
stack, not code to ship - read the **local export**, never the URL (it 403s).
Having none is the normal case: build the UI deliberately rather than defaulting
to generic AI aesthetics, and capture reusable decisions in `DESIGN.md` as you
go. Walkthrough: `/steer:reference design-sources`.

### Durable decisions land in the spine, not in side-channels

A durable design decision - stack, auth model, data model, architecture, a
locked scope or MVP cut - belongs in `/spec`: an `intent.md`, a `contract.md`,
or an ADR. That is the single source of truth a teammate inherits from the repo.
Scoping conversation, chat summaries and **assistant memory** are working notes;
never let a decision survive only there. Record each with its ratifier and date.
**No spine yet? Bootstrap before you commit the decision, not after** - the
dialogue is expected; the durable capture is what waits.

### Living documentation - document in parallel, not after

The PO/dev speaks plainly; **you** translate it into durable artifacts *as the
work happens*, never in a wrap-up pass. When conversation or implementation
reveals a requirement, constraint, risk, trade-off or decision, update the
owning artifact **in the same change as the code**: goals and acceptance ->
`intent.md` (scope changes need PO approval); behavior, data and API ->
`contract.md`; a hard-to-reverse choice -> an ADR; ambiguity -> `## Open
questions`, **never a guessed answer**; usage, workflows, configuration and
release notes -> the app guide; stack and data flow -> `ARCHITECTURE.md` with
its diagram; visual identity -> `DESIGN.md`. The PR that establishes the stack
or first app also retires the scaffold's now-false placeholder prose. Full
routing table and register: **`/steer:reference traceability`**.

- A **notable event** - ratified decision, scope change, repo-level event,
  absorbed PO document, incident -> a **new file** under `/spec/history/`
  (`YYYY-MM-DD-HHMM-<slug>.md`), immutable once merged. **An ordinary merged
  change writes none**; the commit and the PR are its record.
- **Applying a decision already made is not a new decision.** Propagate a
  settled choice in the same change and let the **PR be the gate**. Pause only
  when the decision itself is unmade - a genuine product, policy or architecture
  call - or when the edit would clobber filled-in content.
- **Internal ids stay out of end-user surfaces.** ADR ids, tracker refs,
  `Q-NNN`, feature slugs and `spec/**` paths never reach app UI copy or the app
  guide's user-facing copy and release notes: say what changed for the user, in
  the product's domain language. Refs belong in intent, contracts, ADRs,
  history, the runbook, PRs and commits.
- **Polyrepo member** (`spec/PRODUCT.md` present): `spec/features/**`, the
  product-level files, `/spec/app/` and `/spec/history/` are the **workspace's**
  - write through `workspace.path`, never a local copy, and say so in the PR if
  it does not resolve. `ARCHITECTURE.md`, `DESIGN.md` and ADRs stay per member
  (`/steer:reference polyrepo`).
