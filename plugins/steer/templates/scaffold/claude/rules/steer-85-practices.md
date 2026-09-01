---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.py"
  - "**/*.sql"
  - "**/*.go"
  - "**/*.rs"
  - "**/*.java"
  - "**/*.rb"
---
<!-- steer:managed 85-practices v6.0.0 body-cksum:3576035871 — installed by /steer:init / /steer:adopt and reconciled by /steer:sync. Edit the rule in the steer plugin, not here: a local edit is detected and preserved, but it will not reach any other repo. -->
<!-- PROMOTED back to a binding rule after audit: this carries prohibitions, not
     guidance — 'all data access goes through a parameterized query layer' — injection prevention. A rule
     that is only reachable by lookup is a rule that does not apply. -->

## Patterns we follow (baseline)

Org baseline stated as principles; each names the **default-stack** instance in
parens so it stays actionable there and still applies on any other stack. A
product's own `CLAUDE.md` adds team-learned patterns on top. Full patterns +
anti-patterns prose: `/steer:reference conventions`.

- **Typed by default** — static typing on wherever the language supports it;
  model the type rather than reaching for an untyped escape hatch. *(TS
  `strict`; Python: type hints checked with a type checker.)*
- **All data access goes through a parameterized query layer — never raw or
  string-interpolated SQL.** Schema is defined in code and changed via
  committed, reviewed migrations; no ad-hoc schema edits. *(Drizzle + Drizzle
  Kit; Python: SQLAlchemy 2.x + Alembic.)*
- **Validate every external input through a defined schema at the boundary
  before use** — request inputs, external API responses, config and data
  files, env vars — and derive types from that schema rather than hand-writing
  them. One validated config module, not scattered raw env reads.
- **Server-first** — secrets and DB access stay server-side; client code is
  explicit and lean; only genuinely public values reach the client. *(Next.js
  Server Components / `NEXT_PUBLIC_*`.)*
- **Domain logic lives in shared, testable modules**, not in UI components or
  route handlers — keep handlers thin. *(Monorepo `packages/`.)*
- **Slice work vertically** — thin end-to-end slices (schema to UI), not
  layer by layer; each merge leaves the product working.
- **Nothing silenced** — no empty `catch` / swallowed errors (unexpected
  errors go to Sentry with context); no escape hatches without a why-comment
  (`any` casts, `@ts-ignore`/`@ts-expect-error`, wholesale lint-rule
  disabling).
- **Lockfiles are maintained, not optional** — committed and updated in the
  same change that touches their config/deps; never deleted or ignored to
  dodge an error. *(`mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
  `.terraform.lock.hcl`; mise only writes `mise.lock` if it already exists —
  restore a missing one first.)*
- **Every import resolves to a declared dependency** — added to the manifest
  (and lockfile) in the same change; a plausible-looking undeclared package
  name is a hallucinated dependency that breaks in a clean environment.
  *(`package.json`; Python: `pyproject.toml`.)*
- **ASCII in code and values** — typographic characters (em/en dashes, arrows,
  smart quotes, ellipsis, non-breaking spaces) belong in prose and docs, never
  in code, identifiers, config keys/values, or strings bound for an external
  API — use the ASCII equivalent. Strict validators reject the rest.
