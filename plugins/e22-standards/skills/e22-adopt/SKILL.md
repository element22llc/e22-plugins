---
name: e22-adopt
description: Adopt an existing repo that never went through E22 bootstrap (a "vibe-coded" app) into E22 standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the plugin's bundled scaffolding without clobbering working code.
when_to_use: Use when a repo has working code but no /spec spine and no mise.toml, or when asked to adopt or onboard an existing app onto E22 standards.
---

# Adopt an existing repo into E22 standards

Bring a repo that never went through the E22 bootstrap — a "vibe-coded" app
with working code but no `/spec`, no `mise.toml`, no CI, no plugin install —
into E22 standards. You reverse the Greenfield spec flow: read the code, write
the spec **and the design** it implies, assess what's missing for production,
and sync in the scaffolding the plugin bundles. The result is a `feat/*`
branch and a PR for dev review — that review is the productionization gate.

This is whole-repo Brownfield adoption. For a brand-new repo (or a legacy
template fork), use `/e22-init` instead; for a single feature change to an
already-adopted repo, use the normal spec workflow (`/e22-spec-scaffold`).

## Resuming? Reconcile before anything else

If `/spec/PRODUCTIONIZATION.md` **or** the older `/spec/PRODUCTION-READINESS.md`
exists, you are resuming a prior adoption — and that file may have been written
under an **older** plugin version whose template lacked sections this version
adds (the file itself was renamed `PRODUCTION-READINESS.md` → `PRODUCTIONIZATION.md`
in v1.22.0, so the old name on disk *is* a resume signal — step 2 `git mv`s it
first). **Before** you read its checklist,
summarize status, or pick next steps, your **first action** is to reconcile it
against the current bundled template (step 2). Do not skip this because the file
"looks complete" — a newly added gate is invisible *precisely because* it isn't in
the file yet. Run the diff command in step 2 and act on its output, then continue
from the unchecked items.

## Steps

1. **Confirm it's an adoption case.** There's no `/spec` spine, no
   `mise.toml`/E22 layout, and the repo was not forked from the template. If it
   *was* forked (placeholders, existing `/spec`), redirect to `/e22-init` and
   stop. Detect the stack from the repo itself (`package.json` / `pyproject.toml`,
   frameworks, database, auth). Work on a `feat/e22-adopt` branch — never commit
   to `main` (commit-autonomy rule). Nothing is committed until the dev approves.

2. **Reconcile the adoption checklist (resume safety) — do this FIRST on a resume.**
   **Apply pending structural migrations before deciding anything else.** The
   non-additive transforms (renames/moves) live in the ledger at
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/MIGRATIONS.md` — that ledger is the
   source of truth, not this skill. Walk it by precondition and apply each entry
   that still fires. The one that gates this step is the v1.22.0 rename: if
   `/spec/PRODUCTION-READINESS.md` exists, run
   `git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md` **now** —
   before the fresh-vs-resume check below, so the old name on disk can't be
   mistaken for a fresh adoption. (On an already-bootstrapped repo, `/e22-sync`
   applies these; here we apply them inline so a resumed adoption isn't blocked.)
   Then check: if **neither** `/spec/PRODUCTIONIZATION.md` nor (pre-migration)
   `/spec/PRODUCTION-READINESS.md` existed, this is a fresh adoption — skip ahead;
   the file is created from the current bundled template in step 8. Otherwise
   `/spec/PRODUCTIONIZATION.md` now exists (either already, or from the `git mv`
   above), you are resuming, and it may have been written by
   an *older* plugin version whose template lacked sections this version adds —
   **before reading its checklist or proposing anything, run this diff** and act on
   its output (don't trust your memory of the template, and don't skip because the
   file looks complete):

   ```sh
   comm -13 \
     <(grep -hE '^(#{2,3} |- \[)' spec/PRODUCTIONIZATION.md | sed -E 's/\[[xX]\]/[ ]/' | sort -u) \
     <(grep -hE '^(#{2,3} |- \[)' "${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md" | sed -E 's/\[[xX]\]/[ ]/' | sort -u)
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

3. **Survey the codebase.** Map the apps and entry points, routes/pages,
   handlers, data models, external services, auth, and the env vars the code
   actually reads. From the routes and screens, list the **user-facing features**
   the app already has. This list drives steps 5–6.

4. **Reverse-engineer the product spec.** Interview the dev (or PO) to fill
   `/spec/vision.md`, `/spec/users.md`, `/spec/glossary.md` — **ask, don't
   invent**. Seed each from what the code implies, then confirm with a human;
   unresolved product-level questions go to `vision.md` → `## Open questions`,
   not into guessed prose.

5. **Extract a spec per feature.** For each feature from step 3, run
   **`/e22-spec-scaffold <id>`** to create `intent.md` + `contract.md`. Fill
   `contract.md` from the **real code** (data model, API surface, behavior rules)
   and mark derived sections `derived from existing code — dev confirms` (the
   same "confirm at review" convention the contract template already uses). Draft
   `intent.md`'s what/why from the feature's behavior but leave the PO-acceptance
   boxes **unchecked** — the PO has not validated these yet. Ambiguities → that
   feature's `## Open questions`.

6. **Inventory as-built architectural choices — without inventing decisions.**
   For hard-to-reverse choices already present in the app (database,
   authentication, framework, tenancy, deployment shape, data-access strategy,
   and the like), record in `PRODUCTIONIZATION.md` → **`## Architectural choices
   requiring decision`**: the observed implementation, concrete evidence from the
   repo, its conformance with E22 standards, the proposed
   Keep/Refactor/Rewrite/Reject disposition, and whether a forward decision is
   required. **Do not author an ADR just because the implementation exists.** The
   code proves a choice *exists* — it does not prove *why* it was made, that
   alternatives were consciously rejected, or that anyone authorized it; inferring
   a rationale and stamping an ADR `Accepted` silently converts a standards
   violation (e.g. raw SQL — flagged in step 9) into an approved exception. **Do
   not invent historical context, alternatives, rejection reasons, deciders, or
   approval status.** When the dev *explicitly* chooses a forward direction during
   adoption (retain Postgres, replace custom auth with Cognito, rebuild the data
   layer on Drizzle, …), create a **`Proposed`** ADR via **`/e22-adr`** — it stays
   `Proposed` until the named decider explicitly accepts it; generic approval of
   the adoption PR does **not** ratify it.

7. **Capture the as-built design.** *Skip this step only if the repo has no UI
   surface* (backend-only API, library, CLI) — note "no UI surface — no
   `DESIGN.md`" in `PRODUCTIONIZATION.md` and move on. Otherwise reverse-engineer
   the product's visual identity from the **real code** into a root `DESIGN.md`,
   the same way step 5 reverse-engineers the spec — **a Claude Design export is
   not required**; the running UI is the source. First pull the format schema
   into context (`npx @google/design.md spec`) so the file is valid — don't guess
   the token shape. Then read what the code actually defines: the Tailwind theme
   config, CSS custom properties / `:root` variables, the global stylesheet,
   fonts loaded, and the color, spacing, and radius scales **in use**, plus
   component styling that **recurs** (buttons, inputs, cards, tables, nav,
   empty/loading/error states). Apply the `DESIGN.md` **3+ places** rule — only
   promote a token or component that recurs; one-off, feature-specific styling
   stays in that feature's `intent.md`. Write a valid root `DESIGN.md` in the
   `@google/design.md` format and validate it (`npx @google/design.md lint
   DESIGN.md`). **Same as-built discipline as steps 4–5:** seed from what the
   code shows, mark derived or uncertain values for the dev to confirm, and route
   anything *not* evidenced in the code (intended brand tone, colors that don't
   appear anywhere) to `## Open questions` — **never invent** visual rules.

8. **Triage productionization.** Copy
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md` to
   `/spec/PRODUCTIONIZATION.md` (only if it doesn't exist yet — on a resume it's
   already there and was reconciled against the current template in step 2) and
   fill the gap analysis against E22 standards
   — tests present? lockfiles committed and pinned? secrets handling? high-risk
   areas (auth, authorization, migrations, deletion, billing, deploy)? CI present?
   Zod-at-boundaries and no-silenced-errors? **data layer — is access through
   Drizzle/SQLAlchemy (not raw SQL), and is the schema defined in code and
   migration-tracked?** layout? **Committed secrets are
   stop-and-rotate** (secrets rule): call them out at the top, tell the dev, and
   have the secret rotated — do not just delete the line.
   **Propose a disposition for every gap-analysis area** — Keep (production-grade
   as-is), Refactor (sound, harden in place), Rewrite (discard the implementation,
   rebuild from the now-extracted spec), or Reject (remove; not in spec, dead, or a
   liability) — with a one-line rationale. You **propose**; the dev **ratifies at PR
   review**. Then roll the dispositions into the `## Overall recommendation`: **when
   most areas trend Rewrite/Reject, recommend rebuilding from `/spec` rather than
   hardening in place** — the spec exists now, so a rewrite is a safe, often cheaper
   route to production than fixing a pile of issues. A project-level Rewrite or
   Reject is one kind of explicit forward decision (step 6): hard-to-reverse and
   cross-cutting → record it as a **`Proposed`** ADR (**`/e22-adr`**, high-risk
   rule) for the dev to ratify; it stays `Proposed` until they accept, and you
   never force a large restructure silently.
   This doc is the dev's
   hardening brief and doubles as the resumable adoption checklist (a later
   session reconciles it against the current template per step 2, then continues
   from where it stopped).

9. **Check dependency freshness and flag bad practices.** A vibe-coded app pins
   to whatever versions the generating model knew at *its* training cutoff —
   typically a major or two behind, sometimes on a library that's since been
   superseded. **Do not trust your own memory of "latest"** — it has the same
   cutoff problem. Query the registry **live** (`npm view <pkg> version`,
   `uv pip index versions <pkg>`, the current Node LTS) and diff against what the
   manifests pin. Record every dependency that is a major behind or superseded,
   plus any as-built anti-patterns, in the **Outdated dependencies & bad
   practices** section of `PRODUCTIONIZATION.md`. Anti-patterns to flag (vs
   the `practices` rule):
   - **Raw SQL of any kind** — `db.execute`, tagged-template SQL, hand-built
     query strings. The standard is data access through Drizzle/SQLAlchemy only.
     **Parameterized raw SQL is still a violation** — parameterization clears
     injection, not the raw-SQL-bypasses-the-ORM gap. Never mark it "clean"
     because it's parameterized.
   - **No schema / untracked schema** — the data model isn't defined in code
     (no Drizzle schema or SQLAlchemy models, no migrations directory, schema
     existing only in a live DB). A missing schema is a *flagged gap*, not an
     absence of findings.
   - Swallowed errors (empty `catch`), `any` / blanket `@ts-ignore`, unvalidated
     boundaries (no Zod/Pydantic), secrets read straight from `process.env`.

   Don't write a "verified clean" verdict on any data-layer practice without
   confirming both that access goes through the ORM *and* that the schema is
   defined in code and migration-tracked. The dev owns the upgrade, on a clean
   branch with tests green — propose, don't force, and never bump majors silently
   in the adoption branch.

10. **Sync the bundled scaffolding.** The plugin carries the full repo
   scaffold at `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/` — read its
   `MANIFEST.md` and bring in the files this repo lacks: `mise.toml` + the
   standard `[tasks]` (`dev:setup`, `docker:up/down`, `db:migrate`,
   `db:seed`), `compose.yaml`, CI under `.github/workflows/`, the PR template
   (drift-gate + living-docs checklists), `/configs`, `.env.example`, and
   `.claude/settings.json` enabling the `e22-standards` plugin via the
   marketplace (dotfiles are stored without their leading dot — rename per the
   MANIFEST map). Also instantiate the living-docs artifacts from
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/`: `/spec/tracker.md` (ask which
   tracker the team uses — if GitHub Issues, run `/e22-issues bootstrap-labels`
   to create the `source:*`/`needs:*`/`risk:*` taxonomy and set
   `project.owner`/`number` if a Project is used), `/spec/app/README.md` (seed the usage/roles
   sections from what steps 3–5 learned about the app — as-built, dev
   confirms), and `/spec/HISTORY.md` seeded with the adoption itself as the
   first entry. **Adapt to the existing stack** (Python → `uv` task commands;
   add/remove `compose.yaml` services to match what the app needs).
   **Reconcile, don't replace** — if the repo already has its own CI, compose,
   or config, merge into it rather than overwriting, and **never clobber
   working app code**: diff and ask before touching anything that exists. The
   scaffold carries a `DESIGN.md` stub — **do not overwrite the `DESIGN.md`
   step 7 already reverse-engineered**; only bring in the stub for a UI repo
   where step 7 somehow produced nothing. Then pin the toolchain
   (`mise install`) and commit the populated locks (`mise.lock`, plus
   `pnpm-lock.yaml` / `uv.lock` once the workspace resolves).

11. **Reconcile layout.** Relate code to `/apps` + `/packages` only where it's
   low-risk and clearly worth it; otherwise record the deviation in
   `PRODUCTIONIZATION.md` for the dev to decide. **Propose** any large
   restructure — never force it silently. The dev's PR review is the hard gate.

12. **Hand off.** **Stamp the spine version:** write `/spec/.version` with the
   current plugin version (resolve it from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — never from memory), so a
   later `/e22-sync` knows which structural migrations this repo already carries:

   ```
   # E22 spec-spine version — managed by /e22-init, /e22-adopt, /e22-sync. Do not edit by hand.
   <plugin version>
   ```

   Commit on `feat/e22-adopt`. `PRODUCTIONIZATION.md` is the dev's
   productionization brief — every gap and as-built risk is listed there.
   Propose opening the PR and wait for the dev's confirmation before
   pushing/creating it. Run the end-of-session checklist.
   - **To make selected gaps actionable** (GitHub tracker), run **`/e22-issues
     publish-adoption`** — it reconciles chosen gaps into `kind=finding` +
     `source:adoption` issues (stable `finding-key`, reconcile not duplicate).
     After publication the **issue is canonical** for ownership/lifecycle/closure;
     `PRODUCTIONIZATION.md` stays the assessment snapshot + evidence, recording
     the issue ref but not tracking its implementation status.

13. **Recommend the next action.** As the final output, emit a
   `## Recommended next actions` block per the shared contract at
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md` (categories,
   two-level precedence, output format, read-only + locality rules — adoption is
   repo-wide *by purpose*, so a whole-repo sweep is in scope here). Derive it from
   the adoption state observed, mapping these states to categories:

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Confirmed committed secret / critical exposure | Blocking now | Rotate & invalidate the value; then `/security-review` |
   | Invalid or incomplete adoption artifacts | Blocking now | Complete/repair them (no command) |
   | Extracted intents not PO-accepted | Human decision required | PO validates the named `intent.md` files (no command) |
   | `Proposed` ADRs awaiting a decision | Human decision required | Review via `/e22-adr` |
   | Adoption PR not yet opened | Blocking now (next transition) | Open the adoption PR (after dev confirmation) |
   | Adoption PR open, awaiting review | Human decision required | A reviewer reviews/approves the PR (no command) |
   | Unresolved production blocker among findings | Required before production | Fix or explicitly accept it |
   | Selected findings not published | Recommended | `/e22-issues publish-adoption` |
   | Findings published, not shaped | Recommended | `/e22-issues triage` / `decompose` |
   | `/spec/.version` stale | Recommended | `/e22-sync` |
   | Nothing remaining | Complete | Optional: begin feature work — `/e22-spec` |

   Pick exactly one `Current recommended action` by precedence; offer a
   `Suggested command` only where a real command applies. The block is read-only
   — it recommends, it does not act.

## Guardrails

- **Standards are not softened.** Adoption produces real spec, real tests, real
  Definition of Done — the same bar as any E22 repo. Gaps are recorded, not
  waived.
- **Never commit secrets; rotate the ones you find.** A committed credential is
  stop-and-rotate, not a quiet deletion.
- **Never clobber working code.** The app already runs — diff and ask before
  overwriting any existing file; reconcile scaffolding rather than replacing it.
- **Decisions are recorded, never inferred.** As-built architectural choices are
  captured as **facts + evidence + conformance disposition + decision candidate**
  (`PRODUCTIONIZATION.md`), not as ratified ADRs. An ADR is authored only when a
  human makes an explicit forward decision, and stays `Proposed` until the named
  decider accepts it — adoption never manufactures a rationale or an `Accepted`
  status from code alone.
- **Design is captured as-built, not invented.** Reverse-engineer `DESIGN.md`
  from the code's real tokens (no Claude Design export required); unknown visual
  intent goes to `## Open questions`, never guessed — and a captured `DESIGN.md`
  is never overwritten by the template stub.
- **Propose big restructures, don't force them.** Layout moves and risky changes
  go through the dev's PR review.
- **Up-to-date by default; verify against the registry.** Flag outdated majors
  and superseded libraries from **live** registry data, not memory — but the dev
  owns the upgrade, on its own branch with tests green. Never bump majors
  silently in the adoption branch.
- **Ask, don't invent.** Product intent and ambiguous behavior go to the human
  and to the owning feature's `## Open questions` (or `vision.md` for
  product-level) — never guessed into the spec. Run `/e22-questions` to resolve
  them.
- **Resume is additive, never destructive — and reconcile first.** On a re-run, the
  first action is to reconcile the existing `PRODUCTIONIZATION.md` by running the
  step-2 diff and splicing in the sections/rows the current template adds — before
  reading the checklist or proposing next steps. Never overwrite filled-in analysis,
  never restart adoption from scratch. A repo adopted under an older plugin version
  must pick up newly added gates on its next run.
