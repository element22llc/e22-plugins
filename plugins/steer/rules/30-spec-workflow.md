## Spec workflow

`/spec/features/` and `/spec/decisions/` only stay useful if they actually get
populated. **Create the artifact when the trigger fires — do not defer it:**

- **Starting a user-facing feature** → `/spec/features/[id]/intent.md` +
  `contract.md`, before or alongside the code; author them via
  **`/steer:spec`** (or **`/steer:build`** for a PO),
  which instantiates the templates for you. `[id]` is a short kebab-case slug
  (`user-login`, `export-csv`).
- **Architectural or hard-to-reverse choice** (stack, database, auth approach,
  deployment model, a new cross-cutting pattern) → ADR at
  `/spec/decisions/000N-[slug].md` (run **`/steer:adr <slug>`**). The initial
  stack choice is usually the first ADR.
- **Behavior changes** → update the relevant `contract.md` in the same PR —
  plus the app guide (`/spec/app/`) if it describes the old behavior, and an
  action-history entry (`/spec/HISTORY.md`); see Living documentation.
- **Open questions** → live in each feature's `intent.md` → `## Open questions`
  (product-level ones in `vision.md`); run **`/steer:questions`** to sweep and
  answer them before they rot.
- **A feature that began as a tracker issue** (PO capture) → on a GitHub tracker,
  **`/steer:issues brainstorm`** shapes it in the issue, then
  **`/steer:issues materialize`** writes the approved product intent into
  `intent.md` as `Status: draft`; an explicit `/steer:spec approve` flips it to
  `approved`. The issue is the work record; the spec stays product truth.

The spec ↔ code coupling rules (drift resolution, what counts as behavior, PO
acceptance) are canonical in the spec-framework reference, which the spec
workflow (`/steer:spec`) draws on as it authors the spec. If unsure
whether something needs a feature spec or an ADR, ask the dev rather than
skipping it.

**Greenfield** (new product): the input can be anything — an idea, a brief,
screenshots, or a Claude Design export; don't assume a design artifact exists.
**Bootstrap first** (`/steer:init`, or `/steer:build` for a PO): install the
plugin's bundled scaffold (`mise.toml`, `compose.yaml`, CI, PR template,
`.gitignore`, …) **and** the `/spec` spine before feature code — never hand-write
`package.json` / build config / CI from scratch, that is what the scaffold is for.
Then interview to fill `/spec/vision.md`, `users.md`, `glossary.md` (ask,
don't invent; product-level ambiguity → `vision.md` → `## Open questions`),
draft feature intents,
and get PO approval before broad implementation. The full step-by-step flow is
in the spec-framework reference, drawn on by the spec workflow
(**`/steer:spec`**); a PO driving it uses **`/steer:build`**. Design exports: read the **local export** via
`/steer:design-sources` — never fetch the URL (it 403s).

**A prototype is greenfield too** — "quick", "just a prototype", "throwaway"
relax the *ceremony* (lighter interview, no per-feature issue/PR, high-risk
choices stubbed and marked), **not** the scaffold or the spine. Even a throwaway
gets the bundled scaffold (so it costs nothing to graduate later) and at least a
minimal `/spec` (vision + the feature intents being built), with the build
auto-documented as it goes — seed `/spec/HISTORY.md` and the app guide
(`/spec/app/`) as features land. `/steer:adopt` is for *un-bootstrapped*
pre-existing code, not an excuse to skip bootstrap now and reverse-engineer later.

**Solo greenfield can run on trunk.** When one person is both PO and dev pre-MVP,
`/steer:init` offers **solo trunk mode**: commit straight to `main` — no `feat/*`
branch, no per-feature PR — until the MVP works, declared in the product `CLAUDE.md`
(`Delivery mode: solo trunk (pre-MVP)`) and unwound at graduation (MVP works / first
deploy / second contributor → `/steer:protect`). This relaxes only the branch/PR
ceremony; the scaffold, spine, tests, and Definition of Done all hold. See Commit autonomy.

**Brownfield** (change to an existing product): triage → size it (Change-size
model) → medium+ work writes/updates the spec or ADR first → implement →
update the owning `contract.md` if behavior changed.

**Adopting a whole repo** that never went through bootstrap (a
"vibe-coded" app with no `/spec`): run **`/steer:adopt`** once to reverse-engineer
the spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject
per area in `PRODUCTIONIZATION.md`), and sync in the plugin's bundled
scaffolding — distinct from a per-feature Brownfield change above.
