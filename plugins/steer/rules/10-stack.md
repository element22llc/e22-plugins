## Stack

**Default biases**, not mandates — when a project's intent clearly warrants
a different stack, propose the better fit and record an ADR under
`/spec/decisions/` (run `/steer:adr`). Rationale and full setup detail for every
bullet: run `/steer:conventions`.

- **Frontend:** Next.js + TypeScript + Tailwind.
- **Backend:** Node + TypeScript + PostgreSQL + Drizzle, kept **inside** the
  Next.js app (Route Handlers, Server Actions, server components). A standalone
  `apps/api`, or Python + FastAPI + PostgreSQL, only when intent clearly
  warrants it — either split is an ADR.
- **Infra:** AWS via OpenTofu + Terragrunt (`/infra`). **CI:** GitHub Actions.
  **Deploy:** AWS (e.g. ECS) via Actions — confirm the target per app.
- **Package managers:** pnpm (Node), uv (Python). Windows → develop in WSL2.
- **Lint/format:** Biome (Node/TS), Ruff (Python) — each is the lint *and*
  format tool; no ESLint/Prettier or Flake8/Black/isort alongside without an ADR.
- **Testing:** Vitest (Node/TS), pytest (Python).
- **Auth:** Better Auth — high-risk; scope with the dev and write an ADR first.
  **Error tracking:** Sentry; DSNs/tokens in Secrets Manager, never committed.
- **Local services:** Docker Compose via a committed `compose.yaml` — adapt the
  plugin's bundled scaffold one (`templates/scaffold/compose.yaml`), don't
  author from scratch. **Same engine locally
  as deployed** (no SQLite stand-in for PostgreSQL). Standard entry point:
  `mise run dev:setup` (idempotent: services up → migrate → seed) — keep it
  green; environment tasks live in `mise.toml`, not `package.json`. A plugin
  hook denies stale image-major pins; a deliberately older pin needs an ADR
  plus `# pin-ok: <reason>` on the same line. **Make every published host port
  overridable** — `"${POSTGRES_PORT:-5432}:5432"`, never a bare `5432:5432` —
  with the override var in `.env.example`, so a dev running several managed products
  at once isn't blocked by `port is already allocated`.
- **Environment variables:** local config in a git-ignored `.env` /
  `.env.local`; names documented in `.env.example` — bootstrap and storage
  rules are in Secrets handling.
