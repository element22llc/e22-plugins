<!-- steer:inject-when=org-e22 -->
## Stack (e22 org pack)

The e22 org pack reaches a repo whose `policy/org.yml` says `pack: e22`, or that
has no such file. These are **default biases**, not mandates: when intent
clearly warrants a different stack, propose the better fit and record an ADR
(`/steer:spec adr`). When you pick or change a piece, verify the current stable
version in-session via the bundled `context7` MCP server - never from
training-data memory. The bullets are the **app / service** profile; rationale,
mechanics and the other profiles are in `/steer:reference conventions`.

- **App:** Next.js + TypeScript + Tailwind, with Node + PostgreSQL + Drizzle
  **inside** the Next.js app. A standalone `apps/api`, or Python + FastAPI, is an
  ADR.
- **Tooling:** pnpm / uv; Biome / Ruff, each the lint *and* format tool with
  nothing alongside it without an ADR; Vitest / pytest; VS Code.
- **Platform:** AWS via OpenTofu + Terragrunt (`/infra`), GitHub Actions, a
  `Dockerfile` per deployable `apps/<app>`. Better Auth (high-risk: scope it and
  write the ADR first), Sentry, and SSM Parameter Store `SecureString` as the
  declared secret store.
- **Local services:** a committed `compose.yaml` adapted from the scaffold, the
  **same engine as deployed** (no SQLite for PostgreSQL), every host port
  overridable (`"${POSTGRES_PORT:-5432}:5432"`, var in `.env.example`). An older
  image major needs an ADR plus `# steer:allow-pin`.
- **Tasks and env:** mise is the single task entry point; keep `mise run
  dev:setup` (services up -> migrate -> seed) green. Environment tasks live in
  `mise.toml`, not `package.json`, and delegate one way only. Local config in a
  git-ignored `.env`, names in `.env.example`.

**Patterns, instantiated here:** TS `strict` / Python hints under a type
checker; Drizzle Kit or SQLAlchemy + Alembic; Server Components, `NEXT_PUBLIC_*`
for public values only; shared modules in `packages/`; unexpected errors to
Sentry; lockfiles `mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
`.terraform.lock.hcl`; dependencies in `package.json`, `pyproject.toml`.
