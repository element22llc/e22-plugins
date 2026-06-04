# Conventions

Cross-cutting conventions for Element 22 product repos. The always-on rules keep
only pointers; this is the full prose, loaded on demand via `/e22-conventions`.

## Versioning policy

Default to **current stable** versions of all tools, runtimes, frameworks, and
libraries.

- When setting up a new product, pin to the current stable release of each tool
  unless the org has approved a specific baseline.
- When adding a dependency, prefer the current stable major/minor.
- When suggesting a library or framework, check what the current stable version
  is rather than relying on training-data memory.
- Avoid prerelease, beta, or canary versions unless there is a specific reason.
  Note the reason in the relevant ADR or commit message.
- Dependency upgrades are routine work, but they should still be reviewed like
  any other change.
- For existing products, upgrade intentionally and verify with CI and the
  non-prod environment before production.

Before writing **any** pinned version (Docker image tag, base image, runtime,
engines field), verify what current stable is **in this session** — check the
registry, [endoflife.date](https://endoflife.date), or the official site. Treat
training-data memory of versions as stale by default: the failure mode is being
*confidently* wrong, not unsure, so "ask when unsure" is not enough. If you
cannot verify, say so and ask the dev. Do not guess.

### Enforcement: the version-pin hook

The plugin backs the rule above mechanically with a `PreToolUse` hook
(`hooks/check-version-pins.sh`): writes that pin a stale major for common
images (`postgres:`, `node:`, `python:`, `redis:`, `valkey:`, `nginx:`,
`mysql:`, `mariadb:`, `mongo:`) are denied, with current stable resolved from
the endoflife.date API at write time — the hook hardcodes no version numbers,
so it cannot itself go stale.

- **Deliberate older pins are allowed** (deploy-target/RDS parity, Node LTS
  policy): record an ADR and append `# pin-ok: <reason>` on the same line as
  the pin; the hook then passes it.
- **Major-only tags float the minor** — `postgres:18` only compares the major;
  `python:3.11` compares at maj.min granularity.
- The hook **fails open**: no network, or a product it doesn't know, and the
  write proceeds — it enforces the common path, it doesn't replace the rule.
- Markdown/text files are exempt; prose legitimately mentions old versions.

### Toolchain: `latest` in config, pinned in the lockfile

The toolchain (language runtimes, CLI tools) is managed with **mise**. The
template's `mise.toml` files set every tool to `latest` on purpose — so the
template never carries stale version numbers that someone has to hand-maintain.

Reproducibility comes from the **lockfile**, not from the `mise.toml` value:

- `[settings] lockfile = true` is enabled, so `mise install` writes the exact
  resolved versions to `mise.lock` (one per config dir: root and `infra/`).
  **Caveat: mise only writes `mise.lock` if the file already exists.** The
  template therefore ships committed placeholder `mise.lock` files — never
  delete them. If a repo is missing one, recreate it (`touch mise.lock`, or run
  `mise lock`) before installing, otherwise the install silently succeeds
  without pinning anything.
- **Commit `mise.lock`.** It is the real pin — CI and every developer machine
  install from it, so they always agree. `latest` in `mise.toml` only decides
  what gets resolved the next time the lock is *regenerated*.
- **First use:** run `mise install` (and `cd infra && mise install`), **verify
  the `mise.lock` files now contain real `[[tools.*]]` entries** (not just the
  placeholder comment), and commit them. This is the "pin on adoption" step —
  it has not happened until the populated lockfiles are committed.
- **Bumping:** run `mise upgrade` to move the lock forward, review the diff like
  any other change, and — for infra tools — validate in non-prod before prod.

**Backends must be cross-platform (macOS + Linux).** The mise registry's
default backend for a tool is not always usable on every platform — e.g. plain
`pnpm` resolves to `aqua:pnpm/pnpm`, which has no valid macOS asset; E22 repos
pin `"npm:pnpm"` explicitly instead. When adding a tool to `mise.toml`, choose
a backend whose binaries exist for both macOS (devs) and Linux (CI), and verify
`mise install` succeeds before committing.

This keeps the "default to current stable" rule above (you resolve `latest` once,
at adoption) without leaving an unpinned `latest` in any active product.
mise setup steps are in the product README.

### Lockfiles are maintained, never bypassed

This applies to **every** lockfile in the repo, not just mise's:

- `mise.lock` (toolchain), `pnpm-lock.yaml` (Node workspaces), `uv.lock`
  (Python), `.terraform.lock.hcl` (infra providers) — all are **committed and
  kept in sync** with their config file as part of the change that touches it.
  Adding/removing a dependency or tool without the matching lockfile diff is an
  incomplete change.
- **Never delete or `.gitignore` a lockfile to make an error go away.** Fix the
  resolution problem, or regenerate the lock with the owning tool
  (`mise install` / `mise upgrade`, `pnpm install`, `uv lock`, `tofu init`).
- Lockfile-only diffs deserve the same review as code: an unexplained large
  lockfile change is a smell, not noise.

### Standard mise tasks

Every product repo exposes the same task vocabulary via `[tasks]` in the root
`mise.toml`, so one muscle memory works across all E22 repos:

- **`mise run dev:setup`** — the one-command local environment. **Idempotent**:
  safe to rerun anytime. It starts the Compose services (`docker compose up -d
  --wait`), applies database migrations, and seeds local dev data.
- **`mise run docker:up` / `docker:down`** — just the backing services.
- **`mise run db:migrate` / `db:seed`** — just the database steps. In Node repos
  these fan out with `pnpm --recursive --if-present run …`, so each app/package
  owns its own `db:migrate`/`db:seed` script and packages without one are
  skipped; Python repos call `uv run …` instead.

Why `mise.toml` and not `package.json`:

- These tasks orchestrate tooling **outside** the workspace (Docker, the DB) —
  environment concerns, which mise already owns. `package.json` scripts stay
  app-level (`dev`, `build`, `test`, `typecheck` fanning out to workspace
  packages).
- mise tasks are **polyglot**: `mise run dev:setup` works identically in a
  Python (uv) product that has no root `package.json` workflow.
- `mise tasks` lists them, making the repo self-documenting.

The template ships these tasks wired to the default stack (Postgres in
`compose.yaml`, migrate/seed fan-out). **Adapt them to the product during
`/e22-init`** — wire real migrate/seed commands, add services, swap pnpm for uv,
or delete the docker/db tasks if the product has no backing services — and keep
`dev:setup` green as the stack evolves: a fresh clone plus `mise install &&
mise run dev:setup` must always produce a working local environment.

## Internal monorepo layout

Code lives at the repo root in three top-level directories:

- **`/apps`** — deployable applications. Each app is independently buildable and
  deployable, with its own deploy target.
- **`/packages`** — shared libraries consumed by apps or other packages. Not
  independently deployed.
- **`/configs`** — shared tooling configuration (lint, base tsconfig, formatter,
  test presets) referenced by apps and packages.

A single product repo may hold multiple apps and packages. The org stays
polyrepo *across* products (SOC2 isolation); the monorepo is internal to this
one product.

## Workspace tooling

These are E22's **default biases**, not mandates — lean toward them, and if a
project warrants a different tool, record the choice as an ADR under
`/spec/decisions`. `mise` still pins the underlying runtimes regardless of which
package manager you use.

- **Node.js → [pnpm](https://pnpm.io).** Use pnpm for installs and for workspaces
  (`pnpm-workspace.yaml`) across `/apps` and `/packages`. Prefer it over npm or
  yarn; don't mix lockfiles in one repo.
- **Python → [uv](https://docs.astral.sh/uv/).** Use uv for environments,
  dependency resolution, and locking (`uv add`, `uv sync`, `uv run`). Prefer it
  over pip/Poetry/pip-tools.

Layered task runners (turbo, nx) remain a per-project call — record them in an
ADR if adopted.

### Linting & formatting

One linter+formatter per language, installed via mise (single fast binaries, so
they fit the lockfile model above):

- **Node / TypeScript → [Biome](https://biomejs.dev).** One tool for both lint
  and format. Prefer it over ESLint + Prettier; don't run them alongside Biome.
  Init per workspace with `biome init`, then `biome check` (lint) and
  `biome format`. Pinned in the root `mise.toml`.
- **Python → [Ruff](https://docs.astral.sh/ruff/).** One tool for both lint
  (`ruff check`) and format (`ruff format`). Prefer it over Flake8 / Black /
  isort. Uncomment `ruff` in the root `mise.toml` for Python products.

These are E22 defaults, not mandates — swap one only with an ADR under
`/spec/decisions`. Wire them into the CI `lint` step (see
`.github/workflows/ci.yml`) once the stack exists so a green `ci` enforces them.

### Testing

One test runner per language:

- **Node / TypeScript → [Vitest](https://vitest.dev).** Use it for unit and
  integration tests across `/apps` and `/packages`; run with `pnpm test`. Prefer
  it over Jest; don't run both in one repo.
- **Python → [pytest](https://docs.pytest.org/).** Run with `uv run pytest`.

Coverage expectations and the "tests in the same PR" rule are in the always-on
Testing rules.

### Auth & error tracking

- **Auth → [Better Auth](https://better-auth.com/)** for the Node/Next.js stack.
  Auth is a high-risk area — scope with the dev and record an ADR before wiring
  it in.
- **Error tracking → [Sentry](https://sentry.io)** for error capture on both
  frontend and backend. Keep DSNs and auth tokens in Secrets Manager — never
  commit them.

## Windows: use WSL

Develop inside **WSL2** (Windows Subsystem for Linux), not native Windows. The
toolchain (mise, uv, pnpm, OpenTofu/Terragrunt) and the shell scripts CI lints
all assume a POSIX environment, so WSL avoids a class of path, line-ending, and
shell-incompatibility issues. Setup steps are in the product README.
