<!-- steer:inject-when=org-e22 -->
## Stack (e22 org pack)

**The e22 org pack** - delivered where `policy/org.yml` says `pack: e22`, which
is also what an absent file means. Another pack drops this section and leaves
the core rules, which name no product.

**Default biases**, not mandates - when intent clearly warrants a different
stack, propose the better fit and record an ADR (`/steer:adr`). Rationale and
full setup detail: `/steer:reference conventions`. When you pick or change a
piece, verify the current stable version in-session via the bundled `context7`
MCP server - never from training-data memory.

These bullets are the **app / service** profile, the default. An infra,
library, cli or workspace repo keeps the universal core - mise pinning, the
`/spec` spine, CI hygiene - and swaps the app layer for its own; `/steer:init`
records which.

- **Frontend:** Next.js + TypeScript + Tailwind.
- **Backend:** Node + TypeScript + PostgreSQL + Drizzle, kept **inside** the
  Next.js app. A standalone `apps/api`, or Python + FastAPI, only when intent
  warrants it - either split is an ADR.
- **Infra:** AWS via OpenTofu + Terragrunt (`/infra`). **CI:** GitHub Actions.
  **Deploy:** AWS via Actions - confirm the target per app; each deployable
  `apps/<app>` carries a `Dockerfile`, built by CI when present.
- **Package managers:** pnpm (Node), uv (Python). Windows: WSL2 for CLI work.
- **Editor:** VS Code; committed `.vscode/` config ships in the scaffold.
- **Lint/format:** Biome (Node/TS), Ruff (Python) - each is the lint *and*
  format tool; nothing alongside them without an ADR.
- **Testing:** Vitest (Node/TS), pytest (Python).
- **Auth:** Better Auth - high-risk; scope with the dev and write an ADR
  first. **Error tracking:** Sentry; DSNs/tokens in encrypted config at rest,
  never committed - see Secrets handling.
- **Secret store (deployed):** SSM Parameter Store `SecureString` - what Secrets
  handling means by "the declared store". Secrets Manager only for rotation,
  cross-account sharing, or large/binary values.
- **Local services:** Docker Compose via a committed `compose.yaml`, adapted
  from the bundled scaffold. **Same engine locally as deployed** (no SQLite
  stand-in for PostgreSQL) and **every published host port overridable** -
  `"${POSTGRES_PORT:-5432}:5432"`, never a bare `5432:5432` - with the override
  var in `.env.example`. Keep image majors current; an older pin needs an ADR
  plus `# steer:allow-pin`.
- **Task running:** mise is the single task entry point, and `mise run
  dev:setup` (idempotent: services up -> migrate -> seed) is the standard entry -
  keep it green. Environment tasks live in `mise.toml`, not `package.json`; a
  mise task may delegate to an app-level script, one way only.
- **Environment variables:** local config in a git-ignored `.env` /
  `.env.local`; names documented in `.env.example` - bootstrap and storage
  rules in Secrets handling.

Task-ordering mechanics, the auto-install blocks, the polyglot `dev` task and
the per-profile layouts are in `/steer:reference conventions`.

**Patterns, instantiated here:** typed by default -> TS `strict` / Python hints
under a type checker; parameterized data access -> Drizzle Kit or SQLAlchemy +
Alembic; server-first -> Server Components, `NEXT_PUBLIC_*`; shared domain
modules -> `packages/`; nothing silenced -> unexpected errors to Sentry with
context; lockfiles -> `mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
`.terraform.lock.hcl` (mise writes `mise.lock` only if it exists already);
declared dependencies -> `package.json`, `pyproject.toml`.
