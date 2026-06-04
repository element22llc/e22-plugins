## Patterns we follow (E22 baseline)

These apply to the default stack (Next.js + TS + Tailwind; Node/TS + PostgreSQL +
Drizzle inside the Next.js app; Biome; Vitest/pytest; Better Auth; Sentry; Zod
for validation). They are the org baseline — a product's own `CLAUDE.md` adds
team-learned patterns on top.

- **Data access through Drizzle, always parameterized.** Use the query builder /
  prepared statements; let Drizzle generate SQL. Manage schema changes with
  Drizzle Kit migrations, checked into git and reviewed.
- **Validate at every boundary with Zod.** Route Handler / Server Action inputs,
  external API responses, and environment variables are parsed through a schema
  before use; derive TS types from the schema rather than hand-writing them.
- **Server-first.** Prefer Server Components and server-side data fetching;
  secrets and DB access stay server-side. Mark Client Components explicitly and
  keep them lean. Only expose `NEXT_PUBLIC_*` for genuinely public values.
- **Keep route/action handlers thin.** Put reusable domain logic in `packages/`
  so it is testable in isolation and shared across apps.
- **Strict typing.** TS `strict` on; prefer `unknown` + narrowing over `any`;
  infer types from Drizzle schema and Zod. A `@ts-expect-error` carries a comment
  explaining why.
- **Explicit error handling + Sentry.** Catch where you can act; otherwise let it
  propagate. Report unexpected errors to Sentry with context; never swallow.
- **One validated config module** for environment access instead of scattered
  `process.env` reads.
- **`async/await` with no floating promises** — handle or `await` every promise.
- **Lockfiles are maintained, not optional.** `mise.lock`, `pnpm-lock.yaml`,
  `uv.lock`, `.terraform.lock.hcl` are committed and updated in the same change
  that touches their config/deps. Caveat: mise only writes `mise.lock` if the
  file already exists — restore a missing one (`touch` / `mise lock`) instead of
  skipping the pin. (run `/e22-conventions` for the full discipline.)

## Things to avoid (E22 anti-patterns)

- **Raw / string-interpolated SQL** or concatenating user input into queries —
  injection risk; go through Drizzle with parameters.
- **`any` casts or blanket `@ts-ignore`** to silence the compiler instead of
  modeling the type, and disabling Biome rules wholesale rather than fixing.
- **Trusting unvalidated input** from requests, params, env, or external APIs
  reaching the DB, filesystem, or shell.
- **Leaking server-only code or secrets to the client** — server modules imported
  into Client Components, sensitive values behind `NEXT_PUBLIC_`.
- **Silent failures** — empty `catch`, swallowing errors, or returning a fallback
  that hides a real fault.
- **Business logic inside React components or route handlers** instead of a
  shared, testable `packages/` module.
- **N+1 query patterns** and fetching whole tables to filter in JS — push
  filtering/joins into the query.
- **Untracked or non-reproducible DB changes** — ad-hoc schema edits outside
  Drizzle migrations; destructive migrations without a reviewed forward path.
- **Deleting or ignoring a lockfile to make an error go away** — fix the
  resolution problem or regenerate the lock with its owning tool; a dependency
  change without the matching lockfile diff is an incomplete change.

For the Python/FastAPI path the same principles map: SQLAlchemy 2.x + Alembic
(parameterized, migration-tracked), Pydantic v2 for boundary validation, Ruff
for lint/format.
