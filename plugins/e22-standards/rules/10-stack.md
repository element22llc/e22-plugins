## Stack

These are E22's **default biases**, not mandates. Lean toward them, but when a
project's intent clearly warrants a different stack, propose the better fit and
**record the choice as an ADR under `/spec/decisions/`** (run `/e22-adr`).

- **Frontend:** Next.js + TypeScript + Tailwind.
- **Backend:** Node + TypeScript + PostgreSQL + Drizzle by default. **For the UI
  web app, keep the backend *inside* the Next.js app** — use Route Handlers
  (`app/api/**`), Server Actions, and server components / server-side data
  fetching rather than standing up a separate API app. This is the default to
  keep the stack simple; only split out a standalone `apps/api` when the intent
  clearly warrants it (a non-web consumer, independent scaling/deploy, or a
  different runtime). Switch to Python + FastAPI + PostgreSQL when the project
  intent calls for it — data- or ML-heavy work, or a Python-ecosystem
  dependency; that case is a deliberate split and should be recorded as an ADR.
- **Infra:** AWS, provisioned with **OpenTofu + Terragrunt** — see `/infra`.
- **CI:** GitHub Actions.
- **Deployment:** AWS (e.g. ECS) via GitHub Actions — confirm the target per app.
- **Package managers:** **pnpm** for Node, **uv** for Python. On Windows, develop
  inside **WSL2**. Rationale and setup: run `/e22-conventions`.
- **Linting & formatting:** **Biome** for Node/TypeScript, **Ruff** for Python.
  Both are the default lint *and* format tools — don't add ESLint/Prettier or
  Flake8/Black/isort alongside them without an ADR.
- **Testing:** **Vitest** for Node/TypeScript, **pytest** for Python.
- **Auth:** **[Better Auth](https://better-auth.com/)** for the Node/Next.js
  stack. Auth is a high-risk area — scope with the dev and write an ADR before
  wiring it in.
- **Error tracking:** **Sentry** for error capture (frontend + backend). Keep
  DSNs and tokens in Secrets Manager, never committed (see Secrets handling).
- **Local services:** run backing services (PostgreSQL, Redis, etc.) with
  **Docker Compose** via a committed `compose.yaml`, so local matches deployed.
  **Do not substitute a different engine for local dev** (e.g. SQLite in place of
  PostgreSQL) — develop against the same database you deploy. `pnpm dev` /
  `uv run` should assume the Compose services are up.
- **Environment variables:** store local config in a **`.env`** file (or
  `.env.local`), which is git-ignored and **never committed**. There is no
  committed `.env.example`; document required variables in the relevant app's
  `README.md` instead, and keep deployed secrets in AWS Secrets Manager (see
  Secrets handling). **When setting up or running an app locally, make sure
  `.env` exists and carries the base variables the app needs to boot** — e.g.
  `DATABASE_URL` pointing at the local Compose PostgreSQL, and freshly generated
  local-only secrets (auth secret, API tokens). Create or fill it as part of
  getting local dev running — don't leave the dev to hand-assemble it from the
  README. Never copy deployed/production secret values into it.
