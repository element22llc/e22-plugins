# Legacy template fork — resolution procedure (init Path A)

The procedure `/steer:init` runs when a repo is an unresolved fork of the **old
static `repository-template`** — detected by `[Replace …]`, `[Product Name]`,
`[e.g., …]`, or `@github-handle` placeholders still present anywhere in the
repo. New repos never start from that template (the plugin's bundled scaffold is
the bootstrap source); this path exists only for forks that predate it. The fork
already ships a `/spec` skeleton and scaffolding, so the job is to resolve the
placeholders, swap the starter app, and back-fill the newer scaffold artifacts
the old template lacked.

**Before doing any other work**, offer to resolve the placeholders:

1. **Scan for placeholders** across at minimum:
   - `README.md` (product name, status, PO/dev handles)
   - `CLAUDE.md` (Product paragraph, Stack overrides)
   - `spec/vision.md`, `spec/users.md`, `spec/glossary.md`
   - `spec/design/source.md` (only if Greenfield)
2. **Interview once.** Ask the dev the minimum questions needed to fill them in
   one round: product name, one-line description, PO handle, dev handles,
   Greenfield-vs-Brownfield, production URL (if any). For the stack, confirm or
   override the defaults (the always-on Stack rules) rather than asking from
   scratch — and if the dev overrides them, record the choice as an ADR (run
   `/steer:adr`).
3. **Propose all edits in a single batch** so the dev can confirm the filled-in
   values (product name, handles, …) before they're applied. Once applied,
   commit them, push, and open the PR (Commit autonomy — **the merge review is
   what waits for the dev**).
4. **Pin the toolchain — for every CI/dev platform.** The template's `mise.toml`
   files use `latest` and ship **no** `mise.lock`. If `mise` (or Docker) isn't
   installed yet, run **`/steer:doctor`** first. Then run the canonical pin
   procedure — `/steer:reference conventions` → "Toolchain: `latest` in config,
   pinned in the lockfile" — in each config dir (root, and `infra/` if they'll
   touch infra): create the lock, `mise install`, `mise lock --platform
   linux-x64,macos-arm64` (+ other team platforms; `linux-x64` is mandatory —
   CI runs there), verify the `platforms.linux-x64` blocks, commit. If the dev
   defers pinning, commit **no** `mise.lock` — never an empty placeholder.
5. **Replace or remove the starter.** The template ships a minimal `apps/web` +
   `packages/core` workspace so `mise exec -- pnpm install && pnpm dev` boots a
   page on a fresh clone. It is a placeholder, not the real stack — replace it
   with the actual first app (the default frontend is Next.js), or delete both
   folders if `web` isn't your first app. See `apps/web/README.md`. The template
   deliberately ships **no** workspace lockfile (the starter's would go stale);
   once the real workspace exists, run `mise exec -- pnpm install` (or
   `mise exec -- uv lock` for Python) — through mise so it uses the pinned
   runtime, not a global/nvm one — and commit the generated `pnpm-lock.yaml` /
   `uv.lock`; from then on it is maintained with every dependency change.
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
   - **Polyglot app (Node web + Python `apps/api`):** drive the Python backend
     from **mise** (`[tasks."dev:api"] run = "uv run uvicorn …"`) and compose a
     `[tasks.dev]` with `depends = ["dev:*"]` to run web + api together — mise is
     the single, polyglot entry point. Do **not** add `dev:api`, `uv`, or a
     `concurrently` cross-stack `dev` to the root `package.json`; a
     `package.json` script never shells out to `uv` and no task is defined in
     both files (rule `10-stack`). The scaffold `mise.toml` ships this as a
     commented block — uncomment and adapt it.
   The contract (run `/steer:reference conventions` for the prose):
   `mise run dev:setup` is idempotent and, from a fresh clone after
   `mise install`, must produce a working local environment.
7. **Back-fill the newer scaffold artifacts.** A fork of the old template
   predates the plugin-bundled scaffold, so it lacks the living-docs spine —
   instantiate what's missing from `${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
   `/spec/HISTORY.md` (from `history.md`, seeded with a bootstrap entry),
   `/spec/tracker.md` (from `tracker.md` — ask which tracker the product uses),
   and `/spec/app/README.md` (from `app-docs.md`). Also back-fill the root
   `ARCHITECTURE.md` from
   `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/ARCHITECTURE.md` and fill its stack
   table + apps/packages map from the repo's `package.json` / `mise.toml` and
   actual `apps/*`+`packages/*`. Reconcile the PR template against the bundled
   `${CLAUDE_PLUGIN_ROOT}/templates/github/pull_request_template.md` so the
   drift-gate and living-docs checklists come in (additive — never drop sections
   the team added).

**When the repo is already customized:** if the scan finds no placeholders
**and** a complete spine exists (`spec/.version` plus the spine files), this
setup has already run — do not re-propose it; confirm the repo is set up and
move on.
