---
name: e22-adopt
description: Adopt an existing repo that was NOT forked from the E22 template (a "vibe-coded" app) into E22 standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the template's scaffolding without clobbering working code. Use when a repo has working code but no /spec, no mise.toml, and was not created from repository-template.
---

# Adopt an existing repo into E22 standards

Bring a repo that was **not** forked from the E22 `repository-template` — a
"vibe-coded" app with working code but no `/spec`, no `mise.toml`, no CI, no
plugin install — into E22 standards. You reverse the Greenfield spec flow:
read the code, write the spec it implies, assess what's missing for production,
and sync in the scaffolding the template carries. The result is a `feat/*`
branch and a PR for dev review — that review is the productionization gate.

This is whole-repo Brownfield adoption. For a fresh fork of the template, use
`/e22-init` instead; for a single feature change to an already-adopted repo,
use the normal spec workflow (`/e22-spec-scaffold`).

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
   **Migrate the old name before deciding anything else:** if
   `/spec/PRODUCTION-READINESS.md` exists (it was renamed to `PRODUCTIONIZATION.md`
   in v1.22.0), run `git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md`
   **now** — before the fresh-vs-resume check below, so the old name on disk can't
   be mistaken for a fresh adoption.
   Then check: if **neither** `/spec/PRODUCTIONIZATION.md` nor (pre-migration)
   `/spec/PRODUCTION-READINESS.md` existed, this is a fresh adoption — skip ahead;
   the file is created from the current bundled template in step 7. Otherwise
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

6. **Document as-built decisions.** For hard-to-reverse choices already baked into
   the app (database, auth approach, framework, tenancy, deployment shape) run
   **`/e22-adr <slug>`**, Status `Accepted`, noting the ADR was recorded
   retroactively during adoption. This captures the *why* a future dev would ask
   about, even though the choice predates the spec.

7. **Triage productionization.** Copy
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
   Reject is hard-to-reverse and cross-cutting → record it as an ADR
   (**`/e22-adr`**, high-risk rule) for the dev to ratify; never force a large
   restructure silently.
   This doc is the dev's
   hardening brief and doubles as the resumable adoption checklist (a later
   session reconciles it against the current template per step 2, then continues
   from where it stopped).

8. **Check dependency freshness and flag bad practices.** A vibe-coded app pins
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

9. **Sync the template scaffolding.** Fetch `element22llc/repository-template`
   (e.g. `gh repo clone element22llc/repository-template` into a temp dir, or a
   sparse `git` checkout) and bring in the files it carries that this repo lacks —
   `mise.toml` + the standard `[tasks]` (`dev:setup`, `docker:up/down`,
   `db:migrate`, `db:seed`), `compose.yaml`, CI under `.github/workflows/`,
   `/configs`, `.env.example`, and `.claude/settings.json` enabling the
   `e22-standards` plugin via the marketplace. **Adapt to the existing stack**
   (Python → `uv` task commands; add/remove `compose.yaml` services to match what
   the app needs). **Reconcile, don't replace** — if the repo already has its own
   CI, compose, or config, merge into it rather than overwriting, and **never
   clobber working app code**: diff and ask before touching anything that exists.
   Then pin the toolchain (`mise install`) and commit the populated locks
   (`mise.lock`, plus `pnpm-lock.yaml` / `uv.lock` once the workspace resolves).

10. **Reconcile layout.** Relate code to `/apps` + `/packages` only where it's
   low-risk and clearly worth it; otherwise record the deviation in
   `PRODUCTIONIZATION.md` for the dev to decide. **Propose** any large
   restructure — never force it silently. The dev's PR review is the hard gate.

11. **Hand off.** Commit on `feat/e22-adopt`. `PRODUCTIONIZATION.md` is the
   dev's productionization brief — every gap and as-built risk is listed there.
   Propose opening the PR and wait for the dev's confirmation before
   pushing/creating it. Run the end-of-session checklist.

## Guardrails

- **Standards are not softened.** Adoption produces real spec, real tests, real
  Definition of Done — the same bar as any E22 repo. Gaps are recorded, not
  waived.
- **Never commit secrets; rotate the ones you find.** A committed credential is
  stop-and-rotate, not a quiet deletion.
- **Never clobber working code.** The app already runs — diff and ask before
  overwriting any existing file; reconcile scaffolding rather than replacing it.
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
