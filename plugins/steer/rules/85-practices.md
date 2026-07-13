<!-- steer:inject-when=code-project -->
## Patterns we follow (baseline)

Org baseline stated as principles; each names the **default-stack** instance in
parens so it stays actionable on the default stack and still applies on any
other. A product's own `CLAUDE.md` adds team-learned patterns on top. Full
patterns + anti-patterns prose: run `/steer:reference conventions`.

- **Typed by default** — static typing on wherever the language supports it;
  model the type rather than reaching for an untyped escape hatch. *(Default: TS
  `strict`; Python: type hints checked with a type checker.)*
- **All data access goes through a parameterized query layer — never raw or
  string-interpolated SQL.** Schema is defined in code and changed via
  committed, reviewed migrations; no ad-hoc schema edits. *(Default: Drizzle +
  Drizzle Kit; Python: SQLAlchemy 2.x + Alembic.)*
- **Validate every external input through a defined schema at the boundary
  before use** — request inputs, external API responses, config and data files
  (JSON/YAML), env vars — and derive types from that schema rather than
  hand-writing them. One validated config module instead of scattered raw env
  reads.
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
- **Every import resolves to a declared dependency** — anything you import is
  added to the manifest (and lockfile) in the same change, before you finish; a
  plausible-looking package name that isn't declared is a hallucinated
  dependency, not a working import, and breaks the moment the code runs in a
  clean environment. *(Default: `package.json`; Python: `pyproject.toml`.)*
- **ASCII in code and values** — non-ASCII "typographic" characters (em/en
  dashes `—`/`–`, arrows `→`/`←`, smart quotes `“ ” ‘ ’`, ellipsis `…`,
  non-breaking spaces) are fine in prose and docs but must never land in code,
  identifiers, config keys/values, or any string that reaches an external API or
  system. Use the ASCII equivalent (`-`, `->`, `"`, `'`, `...`, a plain space).
  Strict validators reject the rest: AWS IAM's `description`, for instance,
  permits only ASCII plus Latin-1, so a `→` pasted into a Terraform
  `role_description` fails `apply`. When you copy text into code or a value,
  ASCII-clean it first — keep the nice typography in the prose it came from.
