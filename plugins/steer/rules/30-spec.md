## Spec workflow

Create the artifact when the trigger fires - don't defer it:

- **Starting a user-facing feature** -> `/spec/features/[id]/intent.md` +
  `contract.md`, before or alongside the code - author via **`/steer:spec`**
  (or **`/steer:build`** for a PO). `[id]` is a kebab-case slug (`user-login`).
- **Hard-to-reverse or cross-cutting choice** (stack, database, auth,
  deployment) -> ADR at `/spec/decisions/000N-[slug].md` (**`/steer:adr
  <slug>`**). **The bar is reversal cost, not novelty** - a pattern used in one
  place is a `contract.md` line until a third use makes it house style.
- **Behavior changes** -> the owning `contract.md` in the same PR, plus the app
  guide (`/spec/app/`) if it describes the old behavior.
- **Open questions** -> the feature's `intent.md` -> `## Open questions`
  (product-level ones in `vision.md`); answer them with **`/steer:questions`**
  before they rot.
- **A feature that began as a tracker issue** -> **`/steer:issues brainstorm`**
  shapes it in the issue, **`materialize`** writes the approved intent as
  `Status: draft`, and an explicit `/steer:spec approve` flips it to
  `approved`. The issue is the work record; the spec stays product truth.

Unsure whether something needs a feature spec or an ADR? Ask the dev rather than
skipping it.

**No spine yet, or a repo that never went through bootstrap?** That is
`/steer:setup`, and it comes **before** feature code - the scaffold and the
spine, never a hand-written `package.json`, build config or CI. It routes to the
greenfield interview, to `/steer:adopt` for existing code, or to solo trunk mode
for a one-person pre-MVP product, and the flows themselves live in the
spec-framework reference. "Quick" or "throwaway" relaxes the *ceremony*, never
the scaffold or the spine.

**Brownfield** (change to an existing product): triage -> classify it (Change
classification) -> Behavioral and High-risk work writes the spec or ADR first ->
implement -> update the owning `contract.md` if behavior changed.

**UI work, with or without a design export.** A committed export (Claude Design
ZIP, Figma, screenshots) is a spec to realize in the standard stack, not code to
ship - read the **local export**, never the URL (it 403s). No export is the
normal case: build the UI deliberately rather than defaulting to generic AI
aesthetics, and capture the reusable decisions in `DESIGN.md` as you go. Full
walkthrough: `/steer:reference design-sources`.

### Durable decisions land in the spine, not in side-channels

A durable design decision - stack, auth model, data model, architecture, a
locked scope or MVP cut - belongs in `/spec`: an `intent.md`, a `contract.md`,
or an ADR. That is the single source of truth a teammate inherits from the repo.
Scoping conversation, chat summaries and **assistant memory** are working notes;
never let a decision survive only there. Record each with its ratifier and date
(Answering a human gate). **No spine yet? Bootstrap before you commit the
decision, not after** - the scoping dialogue is fine and expected; what waits
for the spine is the durable capture of what was decided.

### Living documentation - document in parallel, not after

The PO/dev speaks plainly; **you** translate it into durable artifacts *as the
work happens*, never in a wrap-up pass. When conversation or implementation
reveals a requirement, constraint, assumption, risk, trade-off or decision,
update (or propose) the owning artifact **in the same change as the code**:
goals and acceptance -> `intent.md` (scope changes need PO approval); behavior,
data and API -> `contract.md`; a hard-to-reverse choice -> an ADR; ambiguity ->
`## Open questions`, **never a guessed answer**; usage, workflows, roles,
configuration, troubleshooting, release notes -> the app guide; stack, the
apps/packages map, cross-component data flow -> root `ARCHITECTURE.md` with its
linked diagram; visual identity and reusable tokens -> root `DESIGN.md`. The PR
that establishes the stack or the first app also retires the scaffold's
now-false placeholder prose. The full routing table, register and extraction
discipline: **`/steer:reference traceability`**.

- A **notable event** - ratified decision, scope change, repo-level event,
  absorbed PO document, incident -> a **new file** under `/spec/history/`
  (`YYYY-MM-DD-HHMM-<slug>.md`), immutable once merged. **An ordinary merged
  change writes none**; the commit and the PR are its record.
- **Applying a decision already made is not a new decision.** Propagate a
  settled choice in the same change and let the **PR be the gate**. Pause only
  when the decision itself is unmade - a genuine product, policy or
  architecture call, anything under High-risk areas - or when the edit would
  clobber filled-in content.
- **Internal ids stay out of end-user surfaces.** ADR ids, tracker refs,
  `Q-NNN`, feature slugs and `spec/**` paths never reach app UI copy or the app
  guide's user-facing copy and release notes: say what changed for the user, in
  the product's own domain language. Refs belong in intent, contracts, ADRs,
  history, the runbook, PRs and commits.
- **Polyrepo member** (`spec/PRODUCT.md` present): `spec/features/**`, the
  product-level files, `/spec/app/` and `/spec/history/` are the **workspace's**
  - write them through `workspace.path`, never a local copy; if it does not
  resolve, say so in the PR. `ARCHITECTURE.md`, `DESIGN.md` and ADRs stay per
  member (`/steer:reference polyrepo`).
