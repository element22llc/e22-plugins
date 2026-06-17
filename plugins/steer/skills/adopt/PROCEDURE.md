# adopt — detailed adoption procedure

Supporting runbook for the `/steer:adopt` skill. `SKILL.md` carries
the **non-negotiable guardrails** and the **phase map**; this file carries the
step-by-step detail each phase points to. Read the phase you are on here before
executing it. The guardrails in `SKILL.md` govern every phase below — when this
runbook and a guardrail seem to conflict, the guardrail wins.

## Phase 1 — Confirm it's an adoption case

There's no `/spec` spine, no `mise.toml`/standard layout, and the repo was not forked
from the template. If it *was* forked (placeholders, existing `/spec`), redirect
to `/steer:init` and stop. Detect the stack from the repo itself
(`package.json` / `pyproject.toml`, frameworks, database, auth). Work on a
`feat/adopt` branch — never commit to `main` (commit-autonomy rule). Commit
the spine + scaffold as coherent units without asking; **push and the PR wait for
the dev**.

## Phase 2 — Reconcile the adoption checklist (resume safety) — do this FIRST on a resume

**Apply pending structural migrations before deciding anything else.** The
non-additive transforms (renames/moves) live in the ledger at
`${CLAUDE_PLUGIN_ROOT}/templates/reference/MIGRATIONS.md` — that ledger is the
source of truth, not this skill. Walk it by precondition and apply each entry
that still fires. The one that gates this step is the v1.22.0 rename: if
`/spec/PRODUCTION-READINESS.md` exists, run
`git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md` **now** — before
the fresh-vs-resume check below, so the old name on disk can't be mistaken for a
fresh adoption. (On an already-bootstrapped repo, `/steer:sync`
applies these; here we apply them inline so a resumed adoption isn't blocked.)

Then check: if **neither** `/spec/PRODUCTIONIZATION.md` nor (pre-migration)
`/spec/PRODUCTION-READINESS.md` existed, this is a fresh adoption — skip ahead;
the file is created from the current bundled template in Phase 8. Otherwise
`/spec/PRODUCTIONIZATION.md` now exists (either already, or from the `git mv`
above), you are resuming, and it may have been written by an *older* plugin
version whose template lacked sections this version adds — **before reading its
checklist or proposing anything, run this diff** and act on its output (don't
trust your memory of the template, and don't skip because the file looks
complete):

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" \
  spec/PRODUCTIONIZATION.md "${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md"
```

It prints the `##` sections and checklist items the bundled template has that the
existing file lacks (e.g. a later-added `## Outdated dependencies & bad practices`
section). The list **over-reports** — a placeholder the dev replaced with real
content, or a checklist item they reworded, shows as "missing" when it isn't. So
it's a *candidate* list: open the bundled template, and **splice in** the
genuinely-new `##` sections, `## Adoption progress` checkboxes, and `## Gap
analysis` table rows, leaving the spliced-in items **unchecked / empty**. Match on
the section heading, checkbox label, and gap-analysis **Area** cell; never
duplicate an item already present (filled-in or reworded), never re-add a
placeholder the dev filled in, never reorder or overwrite filled-in content, and
never delete a row the dev added. **Preserve every value already there.** Empty
output means the file is already current. Only then continue from the unchecked
items — the freshly spliced ones included. This is the plugin-wide **Template
reconciliation** convention — full rules in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`.

## Phase 3 — Survey the codebase

Map the apps and entry points, routes/pages, handlers, data models, external
services, auth, and the env vars the code actually reads. From the routes and
screens, list the **user-facing features** the app already has. This list drives
Phases 5–6.

## Phase 4 — Reverse-engineer the product spec

Interview the dev (or PO) to fill `/spec/vision.md`, `/spec/users.md`,
`/spec/glossary.md` — **ask, don't invent**. Seed each from what the code
implies, then confirm with a human; unresolved product-level questions go to
`vision.md` → `## Open questions`, not into guessed prose.

## Phase 5 — Extract a spec per feature

For each feature from Phase 3, instantiate the feature spec (this skill invokes
`/steer:spec-scaffold <id>` to create `intent.md` + `contract.md`).
Fill `contract.md` from the **real code** (data model, API surface, behavior
rules) and mark derived sections `derived from existing code — dev confirms` (the
same "confirm at review" convention the contract template already uses). Draft
`intent.md`'s what/why from the feature's behavior but leave the PO-acceptance
boxes **unchecked** — the PO has not validated these yet. Ambiguities → that
feature's `## Open questions`.

## Phase 6 — Inventory as-built architectural choices, without inventing decisions

For hard-to-reverse choices already present in the app (database, authentication,
framework, tenancy, deployment shape, data-access strategy, and the like), record
in `PRODUCTIONIZATION.md` → **`## Architectural choices requiring decision`**: the
observed implementation, concrete evidence from the repo, its conformance with
the standards, the proposed Keep/Refactor/Rewrite/Reject disposition, and whether
a forward decision is required. **Do not author an ADR just because the
implementation exists.** The code proves a choice *exists* — it does not prove
*why* it was made, that alternatives were consciously rejected, or that anyone
authorized it; inferring a rationale and stamping an ADR `Accepted` silently
converts a standards violation (e.g. raw SQL — flagged in Phase 9) into an
approved exception. **Do not invent historical context, alternatives, rejection
reasons, deciders, or approval status.** When the dev *explicitly* chooses a
forward direction during adoption (retain Postgres, replace custom auth with
Cognito, rebuild the data layer on Drizzle, …), create a **`Proposed`** ADR via
**`/steer:adr`** — it stays `Proposed` until the named decider
explicitly accepts it; generic approval of the adoption PR does **not** ratify it.

## Phase 7 — Capture the as-built design

*Skip this phase only if the repo has no UI surface* (backend-only API, library,
CLI) — note "no UI surface — no `DESIGN.md`" in `PRODUCTIONIZATION.md` and move
on. Otherwise reverse-engineer the product's visual identity from the **real
code** into a root `DESIGN.md`, the same way Phase 5 reverse-engineers the spec
— **a Claude Design export is not required**; the running UI is the source. First
pull the format schema into context (`npx @google/design.md spec`) so the file is
valid — don't guess the token shape. Then read what the code actually defines: the
Tailwind theme config, CSS custom properties / `:root` variables, the global
stylesheet, fonts loaded, and the color, spacing, and radius scales **in use**,
plus component styling that **recurs** (buttons, inputs, cards, tables, nav,
empty/loading/error states). Apply the `DESIGN.md` **3+ places** rule — only
promote a token or component that recurs; one-off, feature-specific styling stays
in that feature's `intent.md`. Write a valid root `DESIGN.md` in the
`@google/design.md` format and validate it (`npx @google/design.md lint
DESIGN.md`). **Same as-built discipline as Phases 4–5:** seed from what the code
shows, mark derived or uncertain values for the dev to confirm, and route anything
*not* evidenced in the code (intended brand tone, colors that don't appear
anywhere) to `## Open questions` — **never invent** visual rules.

## Phase 8 — Triage productionization

Copy `${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md` to
`/spec/PRODUCTIONIZATION.md` (only if it doesn't exist yet — on a resume it's
already there and was reconciled against the current template in Phase 2) and fill
the gap analysis against the standards — tests present? lockfiles committed and
pinned? secrets handling? high-risk areas (auth, authorization, migrations,
deletion, billing, deploy)? CI present? Zod-at-boundaries and no-silenced-errors?
**data layer — is access through Drizzle/SQLAlchemy (not raw SQL), and is the
schema defined in code and migration-tracked?** layout? **Committed secrets are
stop-and-rotate** (secrets rule): call them out at the top, tell the dev, and have
the secret rotated — do not just delete the line.

**Propose a disposition for every gap-analysis area** — Keep (production-grade
as-is), Refactor (sound, harden in place), Rewrite (discard the implementation,
rebuild from the now-extracted spec), or Reject (remove; not in spec, dead, or a
liability) — with a one-line rationale. You **propose**; the dev **ratifies at PR
review**. Then roll the dispositions into the `## Overall recommendation`: **when
most areas trend Rewrite/Reject, recommend rebuilding from `/spec` rather than
hardening in place** — the spec exists now, so a rewrite is a safe, often cheaper
route to production than fixing a pile of issues. A project-level Rewrite or
Reject is one kind of explicit forward decision (Phase 6): hard-to-reverse and
cross-cutting → record it as a **`Proposed`** ADR (**`/steer:adr`**,
high-risk rule) for the dev to ratify; it stays `Proposed` until they accept, and
you never force a large restructure silently. This doc is the dev's hardening
brief and doubles as the resumable adoption checklist (a later session reconciles
it against the current template per Phase 2, then continues from where it
stopped).

## Phase 9 — Check dependency freshness and flag bad practices

A vibe-coded app pins to whatever versions the generating model knew at *its*
training cutoff — typically a major or two behind, sometimes on a library that's
since been superseded. **Do not trust your own memory of "latest"** — it has the
same cutoff problem. Query the registry **live** (`npm view <pkg> version`,
`uv pip index versions <pkg>`, the current Node LTS) and diff against what the
manifests pin. Record every dependency that is a major behind or superseded, plus
any as-built anti-patterns, in the **Outdated dependencies & bad practices**
section of `PRODUCTIONIZATION.md`. Anti-patterns to flag (vs the `practices`
rule):

- **Raw SQL of any kind** — `db.execute`, tagged-template SQL, hand-built query
  strings. The standard is data access through Drizzle/SQLAlchemy only.
  **Parameterized raw SQL is still a violation** — parameterization clears
  injection, not the raw-SQL-bypasses-the-ORM gap. Never mark it "clean" because
  it's parameterized.
- **No schema / untracked schema** — the data model isn't defined in code (no
  Drizzle schema or SQLAlchemy models, no migrations directory, schema existing
  only in a live DB). A missing schema is a *flagged gap*, not an absence of
  findings.
- Swallowed errors (empty `catch`), `any` / blanket `@ts-ignore`, unvalidated
  boundaries (no Zod/Pydantic), secrets read straight from `process.env`.

Don't write a "verified clean" verdict on any data-layer practice without
confirming both that access goes through the ORM *and* that the schema is defined
in code and migration-tracked. The dev owns the upgrade, on a clean branch with
tests green — propose, don't force, and never bump majors silently in the
adoption branch.

## Phase 10 — Sync the bundled scaffolding

The plugin carries the full repo scaffold at
`${CLAUDE_PLUGIN_ROOT}/templates/scaffold/` — read its `MANIFEST.md` and bring in
the files this repo lacks: `mise.toml` + the standard `[tasks]` (`dev:setup`,
`docker:up/down`, `db:migrate`, `db:seed`), `compose.yaml`, CI under
`.github/workflows/`, the PR template (drift-gate + living-docs checklists),
`/configs`, `.env.example`, and `.claude/settings.json` enabling the
`steer` plugin via the marketplace (dotfiles are stored without their
leading dot — rename per the MANIFEST map). Also instantiate the living-docs
artifacts from `${CLAUDE_PLUGIN_ROOT}/templates/spec/`: `/spec/tracker.md` (ask
which tracker the team uses — if GitHub Issues, run
`/steer:issues bootstrap-labels` to create the
`source:*`/`needs:*`/`risk:*` taxonomy), `/spec/app/README.md` (seed the usage/roles sections from what
Phases 3–5 learned about the app — as-built, dev confirms), and `/spec/HISTORY.md`
seeded with the adoption itself as the first entry. **Adapt to the existing
stack** (Python → `uv` task commands; add/remove `compose.yaml` services to match
what the app needs). **Reconcile, don't replace** — if the repo already has its
own CI, compose, or config, merge into it rather than overwriting, and **never
clobber working app code**: diff and ask before touching anything that exists. The
scaffold carries a `DESIGN.md` stub — **do not overwrite the `DESIGN.md` Phase 7
already reverse-engineered**; only bring in the stub for a UI repo where Phase 7
somehow produced nothing. Reverse-engineer the root `ARCHITECTURE.md` the same
way: fill its stack table, apps/packages map, and cross-cutting concerns from the
**as-built choices Phase 6 inventoried** (descriptive — *what is*, never inferring
ratified decisions; the ADRs stay `Proposed`) plus the actual `package.json` /
`mise.toml` / `compose.yaml`. **Do not overwrite an `ARCHITECTURE.md` a team
already populated**; only seed the stub when none exists. Then pin the toolchain (`mise install`) and commit the
populated locks (`mise.lock`, plus `pnpm-lock.yaml` / `uv.lock` once the workspace
resolves).

## Phase 11 — Reconcile layout

Relate code to `/apps` + `/packages` only where it's low-risk and clearly worth
it; otherwise record the deviation in `PRODUCTIONIZATION.md` for the dev to
decide. **Propose** any large restructure — never force it silently. The dev's PR
review is the hard gate.

## Phase 12 — Hand off

**Stamp the spine version:** write `/spec/.version` with the current plugin
version (resolve it from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` —
never from memory), so a later `/steer:sync` knows which structural
migrations this repo already carries:

```
# Spec-spine version — managed by /steer:init, /steer:adopt, /steer:sync. Do not edit by hand.
<plugin version>
```

Commit on `feat/adopt`. `PRODUCTIONIZATION.md` is the dev's productionization
brief — every gap and as-built risk is listed there. Propose opening the PR and
wait for the dev's confirmation before pushing/creating it. Run the end-of-session
checklist.

- **To make selected gaps actionable** (GitHub tracker), run
  **`/steer:issues publish-adoption`** — it reconciles chosen gaps
  into `kind=finding` + `source:adoption` issues (stable `finding-key`, reconcile
  not duplicate). The brief is written here with `> Lifecycle: active-adoption`
  (the resumable state); `publish-adoption` flips it to `published-snapshot`
  **only once all intended findings are filed** (partial-publication safe — see
  that mode). After a clean flip the **issue is canonical** for
  ownership/lifecycle/closure; `PRODUCTIONIZATION.md` stays the assessment
  snapshot + evidence, recording the issue ref but not tracking its
  implementation status.

## Phase 13 — Recommend the next action

As the final output, emit a `## Recommended next actions` block per the shared
contract at `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`
(categories, two-level precedence, output format, read-only + locality rules —
adoption is repo-wide *by purpose*, so a whole-repo sweep is in scope here).
Derive it from the adoption state observed, mapping these states to categories:

| Observed state | Category | Action / suggested command |
|---|---|---|
| Confirmed committed secret / critical exposure | Blocking now | Rotate & invalidate the value; then `/security-review` |
| Invalid or incomplete adoption artifacts | Blocking now | Complete/repair them (no command) |
| Extracted intents not PO-accepted | Human decision required | PO validates the named `intent.md` files (no command) |
| `Proposed` ADRs awaiting a decision | Human decision required | Review via `/steer:adr` |
| Adoption PR not yet opened | Blocking now (next transition) | Open the adoption PR (after dev confirmation) |
| Adoption PR open, awaiting review | Human decision required | A reviewer reviews/approves the PR (no command) |
| Unresolved production blocker, app not yet live | Required before initial production | Fix or explicitly accept it |
| Unresolved blocker on an already-live app, actively harming users | Urgent live-system remediation | Fix or explicitly accept it now |
| Unresolved blocker on an already-live app, not an active incident | Required before next production release | Fix or explicitly accept it |
| Selected findings not published | Recommended | `/steer:issues publish-adoption` |
| Findings published, not shaped | Recommended | `/steer:issues triage` / `decompose` |
| `/spec/.version` stale | Recommended | `/steer:sync` |
| `main` not yet protected on GitHub (GitHub tracker) | Recommended | Establish the PR gate — `/steer:protect` (advisory locally; sets the real server-side wall) |
| Nothing remaining | Complete | Optional: begin feature work — `/steer:spec` |

Pick exactly one `Current recommended action` by precedence; offer a
`Suggested command` only where a real command applies. The block is read-only —
it recommends, it does not act.
