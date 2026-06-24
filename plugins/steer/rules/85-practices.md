## Patterns we follow (baseline)

Org baseline stated as principles; each names the **default-stack** instance in
parens so it stays actionable on the default stack and still applies on any
other. A product's own `CLAUDE.md` adds team-learned patterns on top. Full
patterns + anti-patterns prose: run `/steer:reference conventions`.

- **All data access goes through a parameterized query layer — never raw or
  string-interpolated SQL.** Schema is defined in code and changed via
  committed, reviewed migrations; no ad-hoc schema edits. *(Default: Drizzle +
  Drizzle Kit; Python: SQLAlchemy 2.x + Alembic.)*
- **Validate every external input at the boundary before use** — request inputs,
  external API responses, env vars — and derive types from the schema. One
  validated config module instead of scattered raw env reads. *(Default: Zod;
  Python: Pydantic v2.)*
- **Server-first** — secrets and DB access stay server-side; client code is
  explicit and lean; only genuinely public values are exposed to the client.
  *(Default: Next.js Server Components / `NEXT_PUBLIC_*`.)*
- **Domain logic lives in shared, testable modules**, not in UI components or
  route handlers — keep handlers thin. *(Default: monorepo `packages/`.)*
- **Nothing silenced** — no empty `catch` / swallowed errors (unexpected errors
  go to Sentry with context); no escape hatches without a why-comment (`any`
  casts, `@ts-ignore`/`@ts-expect-error`, wholesale lint-rule disabling).
- **Lockfiles are maintained, not optional** — they are committed and updated in
  the same change that touches their config/deps; never deleted or ignored to
  dodge an error. *(Default: `mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
  `.terraform.lock.hcl` — and mise only writes `mise.lock` if the file already
  exists, so restore a missing one first.)*
