# Conventions

Cross-cutting conventions for product repos. The always-on rules keep
only pointers; this is the full prose, loaded on demand via `/steer:reference conventions`.

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

### Enforcement: the version-pin floor

The rule above — verify and pin **current stable**, live, in-session — is how you
*choose* a version. The plugin backs it with a mechanical **EOL floor** so a stale
major never slips through when that live check didn't happen. The floor is a
deterministic, version-controlled policy file (`policy/versions.yml`): a per-product
`minimum_supported` major plus an explicit `denied` list, enforced **with no network
call and no `jq`** so it is reproducible and never fails open for lack of a tool.

It is enforced in two places against that one file:

- a `PreToolUse` hook (`hooks/check-version-pins.sh`) on the write path, and
- a CI scanner (`scripts/scan-version-pins.sh`) over committed config — the
  backstop for pins the hook can't see (Bash-mediated writes, etc.).

For common images (`postgres:`, `node:`, `python:`, `redis:`, `valkey:`, `nginx:`,
`mysql:`, `mariadb:`, `mongo:`), a pin **below the floor or in the denied list is
denied**; anything at or above the floor is allowed silently. There is **no
advisory "behind the target" tier** — what to pin is the live rule's job, not the
floor's, so the file never carries a `recommended` value that could silently rot.

- **The floor tracks upstream EOL automatically.** A scheduled workflow
  (`version-policy-refresh.yml`) is the *only* thing that consults endoflife.date:
  weekly it raises any floor that has fallen behind to the lowest cycle still
  supported upstream and opens a **human-reviewed PR**. Enforcement never makes
  that call. The floor may be deliberately *stricter* than upstream EOL — the
  refresh only ever raises it, never lowers it.
- **Deliberate older pins are allowed** (deploy-target/RDS parity, Node LTS
  policy): record an ADR and append `# steer:allow-pin <reason>` (legacy alias:
  `# pin-ok: <reason>`) on the same line as the pin; enforcement then passes it.
- **Major-only tags float the minor** — `postgres:18` only compares the major;
  `python:3.11` compares at maj.min granularity.
- **Unknown products and ambiguity fail open** — a product not in the policy, or
  anything the scanner can't statically resolve (a pin behind `${VAR}`), is not
  flagged. The floor enforces the common path; it doesn't replace the rule.
- Markdown/text files are exempt; prose legitimately mentions old versions.

### Toolchain: `latest` in config, pinned in the lockfile

The toolchain (language runtimes, CLI tools) is managed with **mise**. The
template's `mise.toml` files set every tool to `latest` on purpose — so the
template never carries stale version numbers that someone has to hand-maintain.

Reproducibility comes from the **lockfile**, not from the `mise.toml` value:

- `[settings] lockfile = true` is enabled, so `mise install` writes the exact
  resolved versions to `mise.lock` (one per config dir: root and `infra/`).
  **Caveat: mise only writes `mise.lock` if the file already exists.** The
  template ships **no** `mise.lock` — you create it the first time you pin
  (`touch mise.lock`, or run `mise lock`, before installing), otherwise the
  install silently succeeds without pinning anything. Until a populated lock is
  committed, CI runs a plain unlocked `mise install`; **never commit an empty /
  comment-only `mise.lock`** — it pins nothing yet makes CI's `--locked` fail.
- **Commit `mise.lock`.** It is the real pin — CI and every developer machine
  install from it, so they always agree. `latest` in `mise.toml` only decides
  what gets resolved the next time the lock is *regenerated*.
- **First use:** create the lock if it doesn't exist yet (`touch mise.lock`),
  run `mise install` (and the same in `infra/`), **then
  `mise lock --platform linux-x64,macos-arm64`** in each directory with a
  `mise.lock` (add `macos-x64` / `linux-arm64` / `windows-x64` for any other
  platform the team develops on — `linux-x64` is mandatory because CI runs on
  `ubuntu-latest`). `mise install` only records asset URLs + checksums for the
  **host** platform, so a lock pinned on macOS has no `linux-x64` entries and CI's
  `mise install --locked` (mise-action enables locked mode whenever a lock exists)
  fails with *"No lockfile URL found … on platform linux-x64"*. **Verify** each
  `mise.lock` now contains a `[tools.<tool>."platforms.linux-x64"]` block with
  `url` + `checksum` (`grep -q 'platforms.linux-x64' mise.lock`) — a lock with
  only `[[tools.*]]` version entries still fails `--locked` — and commit them.
  This is the "pin on adoption" step; it has not happened until the
  multi-platform lockfiles are committed.
- **Bumping:** run `mise upgrade` to move the lock forward, review the diff like
  any other change, and — for infra tools — validate in non-prod before prod.

**Backends must be cross-platform (macOS + Linux).** The mise registry's
default backend for a tool is not always usable on every platform — e.g. plain
`pnpm` resolves to `aqua:pnpm/pnpm`, which has no valid macOS asset; managed repos
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
  (`mise install` / `mise upgrade` / `mise lock --platform …`, `pnpm install`,
  `uv lock`, `tofu init`). Once a `mise.lock` holds every CI/dev platform,
  `mise install` and `mise upgrade` keep all of those platforms in sync; you only
  re-run `mise lock --platform …` to add a newly-used platform.
- Lockfile-only diffs deserve the same review as code: an unexplained large
  lockfile change is a smell, not noise.

### Standard mise tasks

Every product repo exposes the same task vocabulary via `[tasks]` in the root
`mise.toml`, so one muscle memory works across all managed repos:

- **`mise run dev:setup`** — the one-command local environment. **Idempotent**:
  safe to rerun anytime. It starts the Compose services (`docker compose up -d
  --wait`), applies database migrations, and seeds local dev data. The ordering
  is **declared** (`dev:setup` → `db:seed` → `db:migrate` → `docker:up` via
  `depends`), not a hand-written command list — see *Declaring task ordering*.
- **`mise run docker:up` / `docker:down`** — just the backing services.
- **`mise run db:migrate` / `db:seed`** — just the database steps. In Node repos
  these fan out with `pnpm --recursive --if-present run …`, so each app/package
  owns its own `db:migrate`/`db:seed` script and packages without one are
  skipped; Python repos call `uv run …` instead.

mise is the single task **entry surface**, not the single home. The split:

- **Environment/orchestration tasks live in `mise.toml`** — they orchestrate
  tooling **outside** the workspace (Docker, the DB), which mise already owns,
  and are **polyglot**: `mise run dev:setup` works identically in a Python (uv)
  product with no root `package.json` workflow.
- **App-level scripts stay in `package.json`** (`dev`, `build`, `test`,
  `typecheck` fanning out across workspace packages) — pnpm owns that fan-out.
  Don't relocate them into mise. When you want them discoverable from one place,
  add a thin mise task that **delegates** (`run = "pnpm build"`), rather than
  moving the logic — so `mise tasks` lists the whole repo's vocabulary while pnpm
  still owns the workspace graph.

The delegation is **one-way**. A mise task may wrap a `package.json` script; a
`package.json` script must **never** wrap a mise task or shell out to a non-Node
toolchain (`uv`/Python), and **no task is defined in both files**. `package.json`
owns the Node workspace graph and nothing else.

**Polyglot app (Node web + Python `apps/api`).** When the sanctioned API split
exists (a Python `apps/api` alongside the Node `apps/web` — see the `apps/`
README, recorded as an ADR), the backend is **outside** the pnpm workspace, so by
the rule above it is an **orchestration task in `mise.toml`**, run with `uv run`
— never a root-`package.json` script. Compose the two long-running servers with a
mise `dev` task that fans out over `dev:*` in parallel (mise runs `depends`
concurrently; bump `--jobs` if you have more than four). The root `package.json`
carries no `dev:api`, no `uv`, and no `concurrently` cross-stack runner:

```toml
# mise.toml — mise is the polyglot entry point; web stays in package.json
[tasks."dev:web"]
run = "pnpm --filter web dev"            # delegates to apps/web/package.json
[tasks."dev:api"]
run = "uv run uvicorn app.main:app --reload --port ${API_PORT:-8000}"
[tasks.dev]
description = "Run the full app locally (web + api)"
depends = ["dev:*"]                       # both servers in parallel; mise is the single entry point
```

```jsonc
// apps/web/package.json — Node app script lives with its package, no uv, no api task
{ "scripts": { "dev": "next dev" } }
```

`mise run dev` is the one command; `dev:web` delegates into pnpm, `dev:api` runs
uv directly. Nothing is duplicated and no `pnpm`⇄`mise` loop can form.

The template ships these tasks wired to the default stack (Postgres in
`compose.yaml`, migrate/seed fan-out). **Adapt them to the product during
`/steer:init`** — wire real migrate/seed commands, add services, swap pnpm for uv,
or delete the docker/db tasks if the product has no backing services — and keep
`dev:setup` green as the stack evolves: a fresh clone plus `mise install &&
mise run dev:setup` must always produce a working local environment.

### Declaring task ordering

Order tasks with **declared dependencies**, never a manual
`run = ["mise run a", "mise run b"]` chain (a chain hides the graph, re-runs
steps already satisfied, and doesn't fail fast):

```toml
[tasks."docker:up"]
run = "docker compose up -d --wait"

[tasks."db:migrate"]
depends = ["docker:up"]   # runs first; if it fails, db:migrate does not run
run = "pnpm --recursive --if-present run db:migrate"

[tasks."db:seed"]
depends = ["db:migrate"]

[tasks."dev:setup"]
depends = ["db:seed"]     # transitively pulls docker:up → db:migrate → db:seed
```

- **`depends`** — dependencies run **before** the task, in dependency order;
  a failed dependency aborts the task. Put the ordering on each task so it is
  intrinsic, and have the umbrella task (`dev:setup`) depend on the terminal step.
- **`depends_post`** — runs **after** the task; use for teardown/cleanup
  (e.g. a `docker:clean` that should follow an integration-test task).
- **`wait_for`** — soft ordering: "run after X *if* X is also scheduled this
  run, but don't trigger X." Niche; reach for `depends` first.

### Auto-installing workspace dependencies

Don't hand-roll an `install` task. The scaffold declares mise **`[deps]`
providers** that install workspace deps automatically before any `mise run` /
`mise x`:

```toml
[settings]
experimental = true        # [deps] auto-install is gated experimental in mise

[deps.pnpm]
auto = true                # `pnpm install` — runs only when pnpm-lock.yaml changed
[deps.uv]
auto = true                # `uv sync`     — runs only when uv.lock changed
```

- Each provider is **content-hashed against its lockfile** and runs **only when
  stale**, and is active **only when both configured and its lockfile exists** —
  so a Node-only repo's `[deps.uv]` simply no-ops until a `uv.lock` appears (and
  vice versa). This is the "install no-op on unchanged" property for free.
- It rides on `experimental = true`. mise may change experimental behavior
  between releases; steer accepts that trade because the toolchain (mise
  included) is **pinned via `mise.lock`**, so the surface only moves on a
  deliberate `mise upgrade`.
- Escape hatch: `mise run --no-deps <task>` skips auto-install for one command.
- The same provider shape (`auto` / `depends` / `run` / `sources` / `outputs`)
  covers non-package-manager bootstrap too — e.g. the infra profile's commented
  `[deps.ansible-galaxy]` provider installs roles from `requirements.yml`.

### Skipping unchanged tasks (`sources` / `outputs`)

For tasks that **produce files** (codegen, asset/build steps) and aren't covered
by a `[deps]` provider, declare `sources` and `outputs` so mise skips the task
when nothing changed:

```toml
[tasks.codegen]
run = "pnpm gen"
sources = ["schema/**/*.graphql"]
outputs = ["src/generated/**/*.ts"]
```

### File tasks vs `scripts/`

mise can auto-discover **file tasks** — standalone executable scripts in a
task directory (default `mise-tasks/`), each a task named after the file with a
`#MISE description=…` header. This is an option when a task outgrows an inline
`run` string. steer keeps loose project helpers in **`scripts/`** (invoked from a
task's `run`, or via `${CLAUDE_PLUGIN_ROOT}` for plugin scripts); adopt
`mise-tasks/` deliberately if a repo prefers file tasks — don't move `scripts/`
wholesale.

## Backend placement

For the UI web app, keep the backend **inside** the Next.js app — Route
Handlers (`app/api/**`), Server Actions, and server components / server-side
data fetching — rather than standing up a separate API app. This is the default
to keep the stack simple. Only split out a standalone `apps/api` when the
intent clearly warrants it: a non-web consumer, independent scaling/deploy
needs, or a different runtime. Switch to Python + FastAPI + PostgreSQL when the
project intent calls for it — data- or ML-heavy work, or a Python-ecosystem
dependency. Either split is a deliberate choice: record it as an ADR.

## Local services

Run backing services (PostgreSQL, Redis, etc.) with Docker Compose via a
committed `compose.yaml`, so local matches deployed:

- **Don't author `compose.yaml` from scratch** — start from the plugin's
  bundled scaffold one and adapt, so generated services can't reintroduce
  stale image majors (the version-pin hook enforces the common path; see
  Versioning policy → Enforcement).
- **Do not substitute a different engine for local dev** (e.g. SQLite in place
  of PostgreSQL) — develop against the same database you deploy, or you'll ship
  behavior the real engine doesn't have.
- **Make published host ports overridable.** A PO or dev often has several
  products running at once, and every repo that hardcodes `"5432:5432"` collides
  on the second `docker compose up` (`Bind for 0.0.0.0:5432 failed: port is
  already allocated`). Bind through an env var with the canonical port as the
  default — `"${POSTGRES_PORT:-5432}:5432"` — and list that var in `.env.example`.
  A dev hitting a collision then sets `POSTGRES_PORT=5433` in their git-ignored
  `.env` (Compose reads it automatically) and mirrors it in `DATABASE_URL`; the
  container-internal port and every other service are untouched. The
  scaffold `compose.yaml` already does this for Postgres — keep the
  pattern when you add Redis, MinIO, or any other service. (Container, network,
  and volume *names* don't need this — Compose namespaces them per project
  directory automatically; only host port bindings collide.)
- `pnpm dev` / `uv run` assume the Compose services are up; the standard entry
  point is `mise run dev:setup` (see Standard mise tasks).

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

These are the **default biases**, not mandates — lean toward them, and if a
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

### Editor & IDE

**[Visual Studio Code](https://code.visualstudio.com/) is the default editor.**
A default bias, not a mandate — use whatever editor you're productive in — but
the *shared, committed* workspace config targets VS Code, and that's where the
team's setup is documented and kept in sync.

- **Workspace config is committed, in `.vscode/`.** `extensions.json` lists the
  recommended extensions (VS Code prompts contributors to install them on first
  open); `settings.json` carries shared editor defaults (Biome as the
  format-on-save formatter, so the editor matches `pnpm format` / CI). Both ship
  in the plugin's bundled scaffold and install during `/steer:init` —
  per-user overrides go in a git-ignored `.vscode/settings.local.json`, never in
  the committed file.
- **Prefer in-editor extensions over standalone apps for adjacent activities.**
  Lean on VS Code's extension ecosystem to keep day-to-day work in one place
  rather than juggling separate tools — for example **database access** (browse
  and query the PostgreSQL instance from the editor), Tailwind IntelliSense,
  Terraform/HCL for `/infra`, GitHub Actions authoring, ShellCheck, and `.env`
  ergonomics. Each recommended extension maps to a tool already in the stack, so
  the list stays aligned with the toolchain (e.g. Biome, not ESLint/Prettier).
- **Keep `extensions.json` aligned with the stack.** When the stack gains a tool,
  add the matching extension (and drop ones for tools you remove) so a fresh
  clone's "recommended extensions" prompt reflects the real toolchain. The
  Python path (Ruff, Python) is recommended only once you enable Python in
  `mise.toml`.

Database access through an editor extension is for **browsing and ad-hoc
queries** during development — application data access still goes through the ORM
(Drizzle/SQLAlchemy), parameterized and migration-tracked (see Baseline
patterns). The extension is a window onto the same local Compose database, not a
second access path in the app.

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

These are the defaults, not mandates — swap one only with an ADR under
`/spec/decisions`. Wire them into the CI `lint` step (see
`.github/workflows/ci.yml`) once the stack exists so a green `ci` enforces them.

### Testing

One test runner per language:

- **Node / TypeScript → [Vitest](https://vitest.dev).** Use it for unit and
  integration tests across `/apps` and `/packages`; run with `pnpm test`. Prefer
  it over Jest; don't run both in one repo.
- **Python → [pytest](https://docs.pytest.org/).** Run with `uv run pytest`.

The "tests in the same PR" rule is in the always-on Testing rules.

#### Coverage

Coverage is a **signal to find untested behavior, not a target** — see the always-on
Coverage rules. Measure it every run and keep it visible; gate only the lines a PR
**changes**, never a global percentage.

One coverage tool per language, emitting a standard report:

- **Node / TypeScript → Vitest `--coverage`** (`@vitest/coverage-v8`). Run
  `pnpm test -- --coverage`; emits `coverage/lcov.info`.
- **Python → [`pytest-cov`](https://pytest-cov.readthedocs.io/).** Run
  `uv run pytest --cov --cov-report=xml`; emits `coverage.xml`.
- **Changed-line regression → [`diff-cover`](https://github.com/Bachmann1234/diff_cover).**
  Language-agnostic: it consumes `lcov.info` / `coverage.xml`, compares against the
  base branch, and fails when too little of the **changed** code is exercised
  ("cover what you touch"). CI wires this into the test step; there is deliberately
  **no** global `--cov-fail-under` gate.

### Auth & error tracking

- **Auth → [Better Auth](https://better-auth.com/)** for the Node/Next.js stack.
  Auth is a high-risk area — scope with the dev and record an ADR before wiring
  it in.
- **Error tracking → [Sentry](https://sentry.io)** for error capture on both
  frontend and backend. Keep DSNs and auth tokens in encrypted config at rest —
  SSM Parameter Store `SecureString` by default (cheaper), Secrets Manager when
  you need rotation / cross-account / large values — never commit them.

## Deployment & environments

The always-on "Deployment & environments" rule carries the condensed model; this
is the rationale and the AWS-specific shape. Full operational detail lives in the
scaffold's [`infra/README.md`](../scaffold/infra/README.md).

- **Environments** — `non-prod` (shared validation) and `prod`, plus a **review
  app** per open feature PR (torn down on merge/close). The review-app mechanism
  is product-specific — pick one and record it in an ADR.
- **Branch-driven promotion** — promotion moves code between branches rather than
  triggering environments by hand:
  - merge to `main` → **auto-deploy non-prod**;
  - a reviewed promotion PR from `main` into a long-lived **`prod` branch** is the
    **production approval gate**, and merging it → **auto-deploy prod**.
  - **Why a branch, not an environment approval?** GitHub's native
    deployment-environment "required reviewers" gate is Enterprise-only for
    private repos; a protected `prod` branch (required PR review, no direct push,
    no admin bypass) gives the same human gate on any plan. `/steer:protect`
    applies that protection — see the `prod` entry in
    `policy/branch-protection.yml`.
- **Observable by default** — a deployed environment ships logs, metrics with
  alarms, error tracking (Sentry), per-app health checks, and alerting routed to a
  human. "Deployed but unobservable" is not done; capture the wiring in
  `ARCHITECTURE.md`.
- **Rollback & migrations** — every prod deploy has a known rollback (revert the
  `prod` merge / redeploy the prior SHA); migrations are **expand/contract** so the
  running version survives the deploy and a rollback never leaves schema ahead of
  code.

## Baseline patterns & anti-patterns (full prose)

The always-on rules carry the condensed baseline; this is the full version for
the default stack (Next.js + TS + Tailwind; Node/TS + PostgreSQL + Drizzle
inside the Next.js app; Biome; Vitest/pytest; Better Auth; Sentry).

Patterns:

- **Data access through Drizzle, always parameterized.** Use the query builder /
  prepared statements; let Drizzle generate SQL. Manage schema changes with
  Drizzle Kit migrations, checked into git and reviewed.
- **Validate at every boundary through a defined schema.** Route Handler /
  Server Action inputs, external API responses, config and data files
  (JSON/YAML), and environment variables are parsed through a schema before use;
  derive TS types from the schema rather than hand-writing them.
- **Server-first.** Prefer Server Components and server-side data fetching;
  secrets and DB access stay server-side. Mark Client Components explicitly and
  keep them lean. Only expose `NEXT_PUBLIC_*` for genuinely public values.
- **Keep route/action handlers thin.** Put reusable domain logic in `packages/`
  so it is testable in isolation and shared across apps.
- **Strict typing.** TS `strict` on; prefer `unknown` + narrowing over `any`;
  infer types from the Drizzle schema and your validation schemas. A
  `@ts-expect-error` carries a comment explaining why.
- **Explicit error handling + Sentry.** Catch where you can act; otherwise let
  it propagate. Report unexpected errors to Sentry with context; never swallow.
- **One validated config module** for environment access instead of scattered
  `process.env` reads.
- **`async/await` with no floating promises** — handle or `await` every promise.
- **Comments carry weight or don't exist.** Code is self-documenting through
  names and structure; reserve comments for the non-obvious *why* (plus the
  why-comment an escape hatch requires). Match the file's existing comment density
  rather than adding narration on top of it.

Anti-patterns to avoid:

- **Raw SQL at all** — `db.execute`, tagged-template SQL, or hand-built query
  strings — even when parameterized. The standard is data access through Drizzle;
  parameterizing a raw query clears the injection risk but not the bypass of the
  ORM's typing and migration tracking. String-interpolating user input is the
  worst case (injection), but raw SQL is the anti-pattern regardless.
- **`any` casts or blanket `@ts-ignore`** to silence the compiler instead of
  modeling the type, and disabling Biome rules wholesale rather than fixing.
- **Trusting unvalidated input** from requests, params, env, or external APIs
  reaching the DB, filesystem, or shell.
- **Leaking server-only code or secrets to the client** — server modules
  imported into Client Components, sensitive values behind `NEXT_PUBLIC_`.
- **Silent failures** — empty `catch`, swallowing errors, or returning a
  fallback that hides a real fault.
- **Business logic inside React components or route handlers** instead of a
  shared, testable `packages/` module.
- **N+1 query patterns** and fetching whole tables to filter in JS — push
  filtering/joins into the query.
- **Untracked or non-reproducible DB changes** — no schema defined in code at
  all (schema living only in a running database), ad-hoc schema edits outside
  Drizzle migrations, or a missing migrations history; destructive migrations
  without a reviewed forward path.
- **Deleting or ignoring a lockfile to make an error go away** — fix the
  resolution problem or regenerate the lock with its owning tool; a dependency
  change without the matching lockfile diff is an incomplete change.
- **Noise comments** — comments that restate the code, narrate obvious steps,
  decorative section banners, or commented-out dead code left in the file. They go
  stale and drown the why-comments that earn their place; delete on sight.

For the Python/FastAPI path the same principles map: SQLAlchemy 2.x + Alembic
(parameterized, migration-tracked), Pydantic v2 for boundary validation, type
hints checked with a type checker (mypy or pyright), Ruff for lint/format.

## Windows: use WSL

Do **CLI and IDE work** — local Claude Code, the terminal, your editor — inside
**WSL2** (Windows Subsystem for Linux), not native Windows. The toolchain (mise,
uv, pnpm, OpenTofu/Terragrunt) and the shell scripts CI lints all assume a POSIX
environment, so WSL avoids a class of path, line-ending, and shell-incompatibility
issues. The **Claude Desktop Code tab** runs its own environment where **Git for
Windows** is enough (builds included). Setup steps are in the product README.
