<!-- steer:inject-when=code-project -->
## Patterns we follow (baseline)

Org baseline stated as **principles**, so they hold on any stack; where an org
pack is delivered it names the concrete instance of each. A product's own
`CLAUDE.md` adds team-learned patterns on top. Full patterns + anti-patterns
prose: `/steer:reference conventions`.

- **Follow the patterns already in the touched app/package** - the local idiom
  wins over a better one introduced in passing; change the house style
  deliberately, in its own change.
- **Typed by default** - static typing on wherever the language supports it;
  model the type rather than reaching for an untyped escape hatch.
- **All data access goes through a parameterized query layer - never raw or
  string-interpolated SQL.** Schema is defined in code and changed via
  committed, reviewed migrations; no ad-hoc schema edits.
- **Validate every external input through a defined schema at the boundary
  before use** - request inputs, external API responses, config and data
  files, env vars - and derive types from that schema rather than hand-writing
  them. One validated config module, not scattered raw env reads.
- **Server-first** - secrets and DB access stay server-side; client code is
  explicit and lean; only genuinely public values reach the client.
- **Domain logic lives in shared, testable modules**, not in UI components or
  route handlers - keep handlers thin.
- **Slice work vertically** - thin end-to-end slices (schema to UI), not
  layer by layer; each merge leaves the product working.
- **Nothing silenced** - no empty `catch` / swallowed errors; an unexpected
  error reaches the error tracker with context. No escape hatch without a
  why-comment (`any` casts, `@ts-ignore`/`@ts-expect-error`, wholesale
  lint-rule disabling).
- **Lockfiles are maintained, not optional** - committed and updated in the
  same change that touches their config/deps; never deleted or ignored to
  dodge an error.
- **Every import resolves to a declared dependency** - added to the manifest
  (and lockfile) in the same change; a plausible-looking undeclared package
  name is a hallucinated dependency that breaks in a clean environment.
- **ASCII everywhere** - em/en dashes, curly quotes, ellipsis, arrows, bullets
  and non-breaking spaces never appear in anything you produce: not in code,
  config, identifiers or strings bound for an external API, and not in
  comments, specs, docs, commit messages, PR text or chat either. Write `-`,
  `'`, `"`, `...`, `*`, `->`; strict validators reject the rest. This is about
  those characters only - accented letters, guillemets and other non-English
  text are unaffected, and the apostrophe is `'` in every language, French
  included.
