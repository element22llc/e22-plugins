---
name: e22-init
description: One-time setup for a new E22 repo — bootstrap the /spec spine + repo scaffolding from the plugin's bundled scaffold (the plugin replaces the old static repository-template as the bootstrap source), or resolve placeholders in a legacy template fork. In both cases pin the toolchain and leave the repo working spec-first. Use when the dev says "set up this new repo", when a repo has no /spec spine, or when template placeholders ([Replace …], [Product Name], @github-handle) remain.
---

# First-run setup for a new repo

Run this once when a repo is first brought under Element 22 standards. Detect
which of two entry conditions applies and follow that path — both end with the
toolchain pinned and the repo working spec-first, on a `feat/*` branch with
nothing committed until the dev approves.

**A. Legacy fork of the old `repository-template`** — `[Replace …]`,
`[Product Name]`, `[e.g., …]`, or `@github-handle` placeholders are still
present. The fork already ships a `/spec` skeleton and scaffolding; this path
resolves the placeholders, swaps the starter app, and back-fills the newer
scaffold artifacts the old template lacked. → **Path A** below. (New repos no
longer start from that template — the plugin's bundled scaffold is the
bootstrap source; this path exists for forks that predate it.)

**B. Plugin-driven bootstrap (the default for new repos)** — there is **no
`/spec` spine** and no template placeholders, and you are building the product
from scratch (little or no app code exists yet, or you are about to write it).
This path stands up the full repo scaffolding and spec spine from the
plugin's bundled scaffold and starts the spec-first workflow. → **Path B**
below.

**Not a match:** if the repo has **substantial pre-existing code** but no
`/spec` (a "vibe-coded" app you'd be *reverse-engineering*, not writing fresh),
that is adoption, not init — stop and use **`/e22-adopt`**. If `/spec` already
exists and no placeholders remain, setup has already run — say so and stop;
don't re-propose it.

---

## Path A — legacy template fork

If any `[Replace …]`, `[Product Name]`, `[e.g., …]`, or `@github-handle`
placeholders are still present anywhere in the repo, this is an unresolved
fork of the old template. **Before doing any other work**, offer to resolve
them:

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
7. **Back-fill the newer scaffold artifacts.** A fork of the old template
   predates the plugin-bundled scaffold, so it lacks the living-docs spine —
   instantiate what's missing from `${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
   `/spec/HISTORY.md` (from `history.md`, seeded with a bootstrap entry),
   `/spec/tracker.md` (from `tracker.md` — ask which tracker the product
   uses), and `/spec/app/README.md` (from `app-docs.md`). Reconcile the PR
   template against the bundled
   `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/github/pull_request_template.md`
   so the drift-gate and living-docs checklists come in (additive — never
   drop sections the team added).

### When the repo is already customized

If a scan finds no placeholders **and** `/spec` already exists, this setup has
already run. Do not re-propose it; just confirm the repo is set up and move on.

---

## Path B — plugin-driven bootstrap (default)

The repo has no `/spec` spine, and you are starting a new product here. The
goal: stand up the full repo scaffolding + spec spine from the plugin's
bundled scaffold, then proceed spec-first — so feature code is never written
ahead of its intent/contract. Work on a `feat/*` branch; commit nothing until
the dev approves.

1. **Confirm the mode.** Verify there's no `/spec`, and that this is genuinely
   greenfield (you're writing the code from scratch), not reverse-engineering
   a pre-existing app — that would be `/e22-adopt`. If a design export/URL or
   screenshots are the input, read them via `/e22-design-sources` first (never
   fetch a Claude Design URL — it 403s).
2. **Instantiate the bundled scaffold.** Everything lives in the plugin — no
   external template repo to fetch. Read
   `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/MANIFEST.md` and follow its
   install map: copy each scaffold file to its target path (renaming the
   dotfiles as mapped — `gitignore` → `.gitignore`, `env.example` →
   `.env.example`, `claude/`, `vscode/`, `github/`, `mcp.json`), and
   instantiate the spec spine from `${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
   `vision.md`, `users.md`, `glossary.md`, plus the living-docs artifacts —
   `/spec/HISTORY.md` (from `history.md`), `/spec/tracker.md` (from
   `tracker.md`), and `/spec/app/README.md` (from `app-docs.md`). Create empty
   `spec/features/` and `spec/decisions/` dirs. **Adapt to the chosen stack
   and never clobber existing files** (the MANIFEST's per-file notes say what
   to adapt — e.g. drop `package.json`/`pnpm-workspace.yaml`/`biome.json` for
   a Python-only product, swap task commands to `uv run …`).
3. **Interview to fill the spine.** Ask the dev (or PO) the minimum to populate
   `vision.md`, `users.md`, `glossary.md`, the README placeholders, **and
   `/spec/tracker.md`** (which issue tracker does this product use — Jira,
   GitHub Issues, Linear, Azure DevOps, other, none yet — and its
   project/reference format). **Ask, don't invent**; route product-level
   ambiguity to `vision.md` → `## Open questions` rather than guessing.
   Confirm or override the E22 stack defaults (the always-on Stack rules). A
   PO-driven idea→app flow runs through `/e22-build` instead.
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
   same PR, plus the app guide and an action-history entry (Living
   documentation rule).
7. **Hand off.** Seed `/spec/HISTORY.md` with the bootstrap entry (what, why,
   who asked, the bootstrap PR). **Stamp the spine version:** write
   `/spec/.version` with the current plugin version (resolve it from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — never from memory) so a
   later `/e22-sync` knows which structural migrations this repo predates:

   ```
   # E22 spec-spine version — managed by /e22-init, /e22-adopt, /e22-sync. Do not edit by hand.
   <plugin version>
   ```

   Commit on the `feat/*` branch and open a PR for dev review — that review is
   the productionization gate.

### Guardrails

Never clobber working code or overwrite a value the dev already filled in.
Never commit secrets — `.env`/`.env.local` stay git-ignored, names documented in
`.env.example`. Propose batches for approval; don't commit to `main`.
