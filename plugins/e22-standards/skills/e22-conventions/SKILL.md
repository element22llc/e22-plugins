---
name: e22-conventions
description: Full E22 conventions reference — versioning, mise toolchain & lockfiles, backend placement, local services, monorepo layout, pnpm/uv, Biome/Ruff, Vitest/pytest, baseline patterns.
when_to_use: Use for any tooling or convention question, or the rationale behind a stack default.
---

# Element 22 conventions reference

Read the full conventions prose bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/CONVENTIONS.md`

It covers, in detail:

- **Versioning policy** — default to current stable; check a registry rather than
  trusting training-data memory; avoid prerelease without a reason.
- **Toolchain** — mise with `latest` in `mise.toml` and the exact versions pinned
  in the committed `mise.lock`; pin-on-adoption via `mise install` (mise only
  writes the lock if the file exists — the template ships placeholders); bump
  via `mise upgrade`; backends must work on both macOS and Linux.
- **Lockfile discipline** — `mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
  `.terraform.lock.hcl` are committed and updated with every dependency/tool
  change; never deleted or ignored to dodge an error.
- **Standard mise tasks** — `mise run dev:setup` (idempotent: services up →
  migrate → seed) and friends; why environment tasks live in `mise.toml`, not
  `package.json`; how `/e22-standards:e22-init` adapts them per product.
- **Backend placement** — backend inside the Next.js app by default; when a
  standalone `apps/api` or the Python/FastAPI switch is warranted (ADR either way).
- **Local services** — Docker Compose from the template `compose.yaml`, the
  same-engine-as-deployed rule, and how `dev:setup` ties in.
- **Monorepo layout** — `/apps`, `/packages`, `/configs`; polyrepo across
  products, monorepo within one.
- **Workspace tooling** — pnpm (Node), uv (Python).
- **Linting & formatting** — Biome (Node/TS), Ruff (Python); no ESLint/Prettier
  or Flake8/Black/isort alongside them without an ADR.
- **Testing** — Vitest (Node/TS), pytest (Python).
- **Auth & error tracking** — Better Auth, Sentry.
- **Baseline patterns & anti-patterns** — the full prose behind the always-on
  practices baseline (Drizzle/Zod/server-first, what to avoid, Python mapping).
- **Windows** — develop inside WSL2.

Open that file and answer from it. If a convention is genuinely unclear or the
project warrants deviating, record an ADR (run `/e22-standards:e22-adr`) rather than guessing.
