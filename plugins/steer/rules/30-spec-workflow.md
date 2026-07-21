## Spec workflow

Create the artifact when the trigger fires — don't defer it:

- **Starting a user-facing feature** → `/spec/features/[id]/intent.md` +
  `contract.md`, before or alongside the code — author via **`/steer:spec`**
  (or **`/steer:build`** for a PO). `[id]` is a short kebab-case slug
  (`user-login`, `export-csv`).
- **Architectural or hard-to-reverse choice** (stack, database, auth,
  deployment, a new cross-cutting pattern) → ADR at
  `/spec/decisions/000N-[slug].md` (run **`/steer:adr <slug>`**). The initial
  stack choice is usually the first ADR.
- **Behavior changes** → update the owning `contract.md` in the same PR — plus
  the app guide (`/spec/app/`) if it describes the old behavior, and a
  `/spec/HISTORY.md` entry; see Living documentation.
- **Open questions** → the feature's `intent.md` → `## Open questions`
  (product-level ones in `vision.md`); sweep and answer them with
  **`/steer:questions`** before they rot.
- **A feature that began as a tracker issue** → **`/steer:issues brainstorm`**
  shapes it in the issue, **`materialize`** writes the approved intent to
  `intent.md` as `Status: draft`; an explicit `/steer:spec approve` flips it
  to `approved`. The issue is the work record; the spec stays product truth.

The spec ↔ code coupling rules (drift resolution, what counts as behavior, PO
acceptance) are canonical in the spec-framework reference `/steer:spec` draws
on. Unsure whether something needs a feature spec or an ADR? Ask the dev
rather than skipping it.

**Greenfield** (new product — an idea, brief, screenshots, or a design export):
**bootstrap first** (`/steer:init`, or `/steer:build` for a PO) — the bundled
scaffold **and** the `/spec` spine before feature code; never hand-write
`package.json` / build config / CI from scratch. Then interview to fill
`vision.md`, `users.md`, `glossary.md` (ask, don't invent; product-level
ambiguity → `vision.md` → `## Open questions`), draft feature intents, and get PO
approval before broad implementation. Design exports: read the **local export**
via `/steer:reference design-sources` — never fetch the URL (it 403s).

**A prototype is greenfield too** — "quick" / "just a prototype" / "throwaway"
relaxes the *ceremony* (lighter interview; branch/PR only via solo-trunk mode
below; a GitHub-adopted repo still keeps the issue, closed from the commit — see
Issue-first), **not** the scaffold or the spine. Even a throwaway gets the
bundled scaffold and a minimal `/spec` (vision + the feature intents being
built), auto-documented as features land (`/spec/HISTORY.md`, `/spec/app/`).
`/steer:adopt` is for *un-bootstrapped* pre-existing code, not an excuse to skip
bootstrap now.

**Solo greenfield can run on trunk** — when one person is both PO and dev
pre-MVP, `/steer:init` offers **solo trunk mode**: only the branch/PR ceremony
relaxes; scaffold, spine, tests, and Definition of Done all hold. Mechanics
and graduation are canonical in Commit autonomy.

**Brownfield** (change to an existing product): triage → size it (Change-size
model) → medium+ work writes/updates the spec or ADR first → implement →
update the owning `contract.md` if behavior changed.

**Adopting a whole repo** that never went through bootstrap (a "vibe-coded"
app with no `/spec`): run **`/steer:adopt`** once — reverse-engineer the spec
from the code, triage productionization (Keep/Refactor/Rewrite/Reject in
`PRODUCTIONIZATION.md`), sync in the bundled scaffolding — distinct from a
per-feature Brownfield change.
