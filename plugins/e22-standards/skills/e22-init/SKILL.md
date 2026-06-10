---
name: e22-init
description: One-time setup for a new E22 repo — either a freshly forked template (resolve placeholders, replace the starter) or a brand-new non-template repo started from scratch (bootstrap the /spec spine + scaffolding). In both cases pin the toolchain and leave the repo working spec-first. Use when template placeholders ([Replace …], [Product Name], @github-handle) remain, when a repo has no /spec spine and was not forked from the template, or when the dev says "set up this new repo".
---

# First-run setup for a new repo

Run this once when a repo is first brought under Element 22 standards. Detect
which of two entry conditions applies and follow that path — both end with the
toolchain pinned and the repo working spec-first, on a `feat/*` branch with
nothing committed until the dev approves.

**A. Freshly forked from the E22 template** — `[Replace …]`, `[Product Name]`,
`[e.g., …]`, or `@github-handle` placeholders are still present. The template
already ships the `/spec` skeleton and scaffolding; this path resolves the
placeholders and swaps the starter app. → **Path A** below.

**B. Brand-new non-template repo, greenfield** — there is **no `/spec` spine**
and the repo was **not** forked from the template (no placeholders), and you are
building the product from scratch (little or no app code exists yet, or you are
about to write it). The template's spine and scaffolding never came along, so
this path brings them in and starts the spec-first workflow. → **Path B** below.

**Not a match:** if the repo has **substantial pre-existing code** but no
`/spec` (a "vibe-coded" app you'd be *reverse-engineering*, not writing fresh),
that is adoption, not init — stop and use **`/e22-adopt`**. If `/spec` already
exists and no placeholders remain, setup has already run — say so and stop;
don't re-propose it.

---

## Path A — fresh template fork

If any `[Replace …]`, `[Product Name]`, `[e.g., …]`, or `@github-handle`
placeholders are still present anywhere in the repo, this is a fresh clone.
**Before doing any other work**, offer to resolve them:

1. Scan for placeholders across at minimum:
   - `README.md` (product name, status, PO/dev handles)
   - `CLAUDE.md` (Product paragraph, Stack overrides)
   - `spec/vision.md`, `spec/users.md`, `spec/glossary.md`
   - `spec/design/source.md` (only if Greenfield)
2. Ask the dev the minimum questions needed to fill them in one round: product
   name, one-line description, PO handle, dev handles, Greenfield-vs-Brownfield,
   production URL (if any). For the stack, confirm or override the E22 defaults
   (the always-on Stack rules) rather than asking from scratch — and if the dev
   overrides them, record the choice as an ADR (run `/e22-adr`).
3. Propose all edits in a single batch for review; do not commit until the dev
   approves.
4. **Pin the toolchain.** The template's `mise.toml` files use `latest` so they
   carry no stale versions; the committed placeholder `mise.lock` files are
   what `mise install` writes the resolved versions into (mise only writes the
   lock if the file already exists — if a placeholder is missing, restore it
   with `touch mise.lock` or run `mise lock` first; never delete it). Have the
   dev run `mise install` (and `cd infra && mise install` if they'll touch
   infra), then **verify each `mise.lock` now contains real `[[tools.*]]`
   version entries** — a still-empty lock means nothing was pinned — and commit
   them. They are the real version pins (run `/e22-conventions` for the
   rationale, including the cross-platform backend rule and lockfile-maintenance
   discipline).
5. **Replace or remove the starter.** The template ships a minimal `apps/web` +
   `packages/core` workspace so `pnpm install && pnpm dev` boots a page on a
   fresh clone. It is a placeholder, not the real stack — replace it with the
   actual first app (the default frontend is Next.js), or delete both folders if
   `web` isn't your first app. See `apps/web/README.md`. The template
   deliberately ships **no** workspace lockfile (the starter's would go stale);
   once the real workspace exists, run `pnpm install` (or `uv lock` for Python)
   and commit the generated `pnpm-lock.yaml` / `uv.lock` — from then on it is
   maintained with every dependency change.
6. **Adapt the standard tasks to this product.** The template's `mise.toml`
   ships a baseline `dev:setup` task (plus `docker:up/down`, `db:migrate`,
   `db:seed`) wired to the default stack: Postgres in `compose.yaml`,
   migrate/seed fanned out via `pnpm --recursive --if-present`. Make it real for
   this product:
   - add the services the product actually needs to `compose.yaml` (or delete
     it and the docker/db tasks if there are no backing services);
   - once the real app exists, give it `db:migrate` / `db:seed` scripts (e.g.
     drizzle-kit + a seed script) so the fan-out picks them up;
   - Python products: swap the `pnpm …` task commands for `uv run …`.
   The contract (run `/e22-conventions` for the prose): `mise run dev:setup` is
   idempotent and, from a fresh clone after `mise install`, must produce a
   working local environment.

### When the repo is already customized

If a scan finds no placeholders **and** `/spec` already exists, this setup has
already run. Do not re-propose it; just confirm the repo is set up and move on.

---

## Path B — non-template greenfield bootstrap

The repo has no `/spec` spine and was not forked from the template, but you are
starting a new product here. The goal: stand up the same spine + scaffolding a
fork would have had, then proceed spec-first — so feature code is never written
ahead of its intent/contract. Work on a `feat/*` branch; commit nothing until
the dev approves.

1. **Confirm the mode.** Verify there's no `/spec` and no template lineage, and
   that this is genuinely greenfield (you're writing the code from scratch), not
   reverse-engineering a pre-existing app — that would be `/e22-adopt`. If a
   design export/URL or screenshots are the input, read them via
   `/e22-design-sources` first (never fetch a Claude Design URL — it 403s).
2. **Bring in the spine + scaffolding from the template.** The plugin bundles
   the per-feature/ADR templates under `${CLAUDE_PLUGIN_ROOT}/templates/spec/`,
   but the product-level spine (`spec/vision.md`, `spec/users.md`,
   `spec/glossary.md`) and the repo scaffolding (`mise.toml` + the standard
   `dev:setup`/`docker`/`db` tasks, `compose.yaml`, GitHub Actions CI,
   `.env.example`, `.claude/settings.json`) live in
   [`element22llc/repository-template`](https://github.com/element22llc/repository-template).
   Fetch that repo (`gh repo clone element22llc/repository-template` into a temp
   dir) and bring those files in, **adapting to the chosen stack and never
   clobbering working code** — same scaffolding-sync discipline as `/e22-adopt`
   step 9. If the clone isn't reachable, scaffold the spine from the bundled
   `templates/spec/` plus a minimal stack-appropriate `mise.toml`/`compose.yaml`,
   and note what couldn't be synced.
3. **Interview to fill the spine.** Ask the dev (or PO) the minimum to populate
   `vision.md`, `users.md`, `glossary.md` — **ask, don't invent**; route
   product-level ambiguity to `vision.md` → `## Open questions` rather than
   guessing. Confirm or override the E22 stack defaults (the always-on Stack
   rules). A PO-driven idea→app flow runs through `/e22-build` instead.
4. **Record the initial stack as the first ADR.** The stack choice is usually
   the first decision worth an ADR — run `/e22-adr`. **Any deviation from the
   E22 defaults** (e.g. a standalone Python/Typer CLI instead of Next.js/TS, or
   Python + FastAPI instead of the in-Next backend) **must** get one either way.
5. **Pin the toolchain and lock the workspace.** Run `mise install`, then verify
   each `mise.lock` contains real `[[tools.*]]` entries and commit it. Once the
   first real app/workspace exists, generate and commit the workspace lock
   (`pnpm-lock.yaml` or `uv.lock`); maintain it with every dependency change.
   Make `mise run dev:setup` real and idempotent for this product (Python:
   `uv run …` task commands; drop `compose.yaml` + docker/db tasks if there are
   no backing services).
6. **Proceed spec-first.** From here, every user-facing feature gets its
   `/spec/features/[id]/intent.md` + `contract.md` via **`/e22-spec-scaffold`**
   *before or alongside* its code — not after. Get PO approval on intent before
   broad implementation. Behavior changes update the owning `contract.md` in the
   same PR.
7. **Hand off.** Commit on the `feat/*` branch and open a PR for dev review —
   that review is the productionization gate.

### Guardrails

Never clobber working code or overwrite a value the dev already filled in.
Never commit secrets — `.env`/`.env.local` stay git-ignored, names documented in
`.env.example`. Propose batches for approval; don't commit to `main`.
