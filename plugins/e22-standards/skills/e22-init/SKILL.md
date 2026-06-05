---
name: e22-init
description: One-time setup for a freshly forked E22 template repo — resolve placeholders, pin the toolchain, replace the starter app. Use when template placeholders ([Replace …], [Product Name], @github-handle) remain or the dev says "set up this new repo".
---

# First-run setup (template just forked)

Run this once per fresh fork of the E22 repository template. If no placeholders
remain anywhere in the repo, the template has already been customized — say so
and stop.

## Steps

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

## When the repo is already customized

If a scan finds no placeholders, this setup has already run. Do not re-propose
it; just confirm the repo is set up and move on.
