---
name: e22-adopt
description: Adopt an existing repo that was NOT forked from the E22 template (a "vibe-coded" app) into E22 standards — reverse-engineer the /spec from the code, assess production readiness, and sync the template's scaffolding without clobbering working code. Use when a repo has working code but no /spec, no mise.toml, and was not created from repository-template.
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

## Steps

1. **Confirm it's an adoption case.** There's no `/spec` spine, no
   `mise.toml`/E22 layout, and the repo was not forked from the template. If it
   *was* forked (placeholders, existing `/spec`), redirect to `/e22-init` and
   stop. Detect the stack from the repo itself (`package.json` / `pyproject.toml`,
   frameworks, database, auth). Work on a `feat/e22-adopt` branch — never commit
   to `main` (commit-autonomy rule). Nothing is committed until the dev approves.

2. **Survey the codebase.** Map the apps and entry points, routes/pages,
   handlers, data models, external services, auth, and the env vars the code
   actually reads. From the routes and screens, list the **user-facing features**
   the app already has. This list drives steps 4–5.

3. **Reverse-engineer the product spec.** Interview the dev (or PO) to fill
   `/spec/vision.md`, `/spec/users.md`, `/spec/glossary.md` — **ask, don't
   invent**. Seed each from what the code implies, then confirm with a human;
   unresolved product questions go to `/spec/SPEC-QUESTIONS.md`, not into guessed
   prose.

4. **Extract a spec per feature.** For each feature from step 2, run
   **`/e22-spec-scaffold <id>`** to create `intent.md` + `contract.md`. Fill
   `contract.md` from the **real code** (data model, API surface, behavior rules)
   and mark derived sections `derived from existing code — dev confirms` (the
   same "confirm at review" convention the contract template already uses). Draft
   `intent.md`'s what/why from the feature's behavior but leave the PO-acceptance
   boxes **unchecked** — the PO has not validated these yet. Ambiguities →
   `/spec/SPEC-QUESTIONS.md`.

5. **Document as-built decisions.** For hard-to-reverse choices already baked into
   the app (database, auth approach, framework, tenancy, deployment shape) run
   **`/e22-adr <slug>`**, Status `Accepted`, noting the ADR was recorded
   retroactively during adoption. This captures the *why* a future dev would ask
   about, even though the choice predates the spec.

6. **Assess production readiness.** Copy
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/production-readiness.md` to
   `/spec/PRODUCTION-READINESS.md` and fill the gap analysis against E22 standards
   — tests present? lockfiles committed and pinned? secrets handling? high-risk
   areas (auth, authorization, migrations, deletion, billing, deploy)? CI present?
   Zod-at-boundaries and no-silenced-errors? layout? **Committed secrets are
   stop-and-rotate** (secrets rule): call them out at the top, tell the dev, and
   have the secret rotated — do not just delete the line. This doc is the dev's
   hardening brief and doubles as the resumable adoption checklist (a later
   session reads it first and continues from where it stopped).

7. **Sync the template scaffolding.** Fetch `element22llc/repository-template`
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

8. **Reconcile layout.** Relate code to `/apps` + `/packages` only where it's
   low-risk and clearly worth it; otherwise record the deviation in
   `PRODUCTION-READINESS.md` for the dev to decide. **Propose** any large
   restructure — never force it silently. The dev's PR review is the hard gate.

9. **Hand off.** Commit on `feat/e22-adopt`. `PRODUCTION-READINESS.md` is the
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
- **Ask, don't invent.** Product intent and ambiguous behavior go to the human
  and to `/spec/SPEC-QUESTIONS.md` — never guessed into the spec.
