<!-- steer:inject-when=code-project -->
## Stack

**Default biases**, not mandates — when intent clearly warrants a different
stack, propose the better fit and record an ADR (`/steer:adr`). Rationale and
full setup detail: `/steer:reference conventions`. Verify current stable
versions in-session when you pick or change a piece — don't trust training-data
memory.

These bullets are the **app / service** profile (the default). An **infra**
repo (Ansible / Terraform / OpenTofu / Pulumi) makes the Infra bullet its
*primary* stack — IaC toolchain at the root, no Node/web layer; a **library**
or **cli** follows its own package language and skips the app/web/compose
bullets. `/steer:init` records the profile; the universal core (mise pinning,
`/spec` spine, CI hygiene) is the same for all.

- **Frontend:** Next.js + TypeScript + Tailwind.
- **Backend:** Node + TypeScript + PostgreSQL + Drizzle, kept **inside** the
  Next.js app (Route Handlers, Server Actions, server components). A
  standalone `apps/api`, or Python + FastAPI + PostgreSQL, only when intent
  clearly warrants it — either split is an ADR.
- **Infra:** AWS via OpenTofu + Terragrunt (`/infra`). **CI:** GitHub Actions.
  **Deploy:** AWS (e.g. ECS) via Actions — confirm the target per app; each
  deployable `apps/<app>` carries a `Dockerfile` (built by CI when present).
  Promotion, environments, and the `prod`-branch gate: Deployment &
  environments.
- **Package managers:** pnpm (Node), uv (Python). Windows: WSL2 for CLI/IDE
  work; on the Claude Desktop Code tab, Git for Windows is enough.
- **Editor:** VS Code; committed `.vscode/` config ships in the scaffold.
  Prefer in-editor extensions for adjacent work over standalone apps.
- **Lint/format:** Biome (Node/TS), Ruff (Python) — each is the lint *and*
  format tool; no ESLint/Prettier or Flake8/Black/isort alongside without an
  ADR.
- **Testing:** Vitest (Node/TS), pytest (Python).
- **Auth:** Better Auth — high-risk; scope with the dev and write an ADR
  first. **Error tracking:** Sentry; DSNs/tokens in encrypted config at rest,
  never committed — see Secrets handling.
- **Local services:** Docker Compose via a committed `compose.yaml` — adapt
  the plugin's bundled scaffold one, don't author from scratch. **Same engine
  locally as deployed** (no SQLite stand-in for PostgreSQL). Standard entry
  point: `mise run dev:setup` (idempotent: services up → migrate → seed) —
  keep it green; environment tasks live in `mise.toml`, not `package.json`. A
  plugin hook denies stale image-major pins (deliberate exceptions: ADR +
  `# steer:allow-pin` — the denial names the full remedy). **Every published
  host port overridable** — `"${POSTGRES_PORT:-5432}:5432"`, never a bare
  `5432:5432` — with the override var in `.env.example`.
- **Task running:** mise is the single task entry point. Declare ordering with
  `depends` / `depends_post`, never `run = ["mise run …"]` chains. App-level
  Node scripts (`dev` / `build` / `test` / `typecheck`) stay in
  `package.json`; a mise task may delegate to them — delegation is
  **one-way**: no `package.json` script shells out to `uv`/Python or
  re-defines a mise task. A Python backend is a mise/`uv run` task; compose a
  polyglot `dev` in `mise.toml` (`depends = ["dev:*"]`), not a
  root-`package.json` `concurrently` script. Let `[deps.pnpm]` / `[deps.uv]`
  (`auto = true`) install workspace deps on lockfile change.
- **Environment variables:** local config in a git-ignored `.env` /
  `.env.local`; names documented in `.env.example` — bootstrap and storage
  rules in Secrets handling.
