## Patterns we follow (E22 baseline)

Org baseline for the default stack; a product's own `CLAUDE.md` adds
team-learned patterns on top. Full patterns + anti-patterns prose (and the
Python/FastAPI mapping): run `/e22-conventions`.

- **Data access through Drizzle only, parameterized** — never raw or
  string-interpolated SQL. Schema changes via Drizzle Kit migrations, committed
  and reviewed; no ad-hoc schema edits.
- **Zod at every boundary** — Route Handler / Server Action inputs, external
  API responses, env vars — parsed before use; derive TS types from the schema.
  One validated config module instead of scattered `process.env` reads.
- **Server-first** — secrets and DB access stay server-side; Client Components
  explicit and lean; `NEXT_PUBLIC_*` only for genuinely public values.
- **Domain logic in `packages/`**, not in React components or route handlers —
  thin handlers, testable shared modules.
- **Nothing silenced** — no empty `catch` / swallowed errors (unexpected errors
  go to Sentry with context); no `any` casts or blanket `@ts-ignore` (a
  `@ts-expect-error` carries a why-comment); no disabling lint rules wholesale.
- **Lockfiles are maintained, not optional** — `mise.lock`, `pnpm-lock.yaml`,
  `uv.lock`, `.terraform.lock.hcl` are committed and updated in the same change
  that touches their config/deps; never deleted or ignored to dodge an error.
  (mise only writes `mise.lock` if the file already exists — restore a missing
  one first.)

Python/FastAPI path maps the same: SQLAlchemy 2.x + Alembic (parameterized,
migration-tracked), Pydantic v2 at boundaries, Ruff.
