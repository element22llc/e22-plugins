# [Feature Name] - Contract

> Owner: dev team
> Last updated: YYYY-MM-DD
> Implements: ./intent.md

## Behavior rules

[Concrete rules the implementation must satisfy. These should be testable.]

Write each rule as a named requirement: a `### R-NNN - <short name>` heading, a
one-line statement, and one or more Given/When/Then scenarios. Validation and
error states are requirements too. IDs are per feature (`R-001`, `R-002`, ...),
never renumbered, and never reused once a requirement is removed - take the next
number above the highest this file has ever used (`git log -p` on it shows
removed ones). A PR that changes this file lists the IDs it added, modified or
removed in its Spec delta. State current truth; how a rule changed belongs in
that Spec delta, not here.

A requirement reverse-engineered from existing code carries `(derived from
existing code - dev confirms)` after its statement, so a reviewer knows a change
to it alters as-built behavior; the dev deletes the marker on confirming it.
Tests may cite a requirement as `<feature-id>/R-001` in a test name or comment -
optional, not a gate. Rules written before this format, as plain `- Given ...`
bullets, stay valid; number them when you next touch them.

The seed below is marked `<!-- steer:placeholder -->` - delete the marker (and
the bracketed text) when you write a real requirement.

### R-001 - [Short name] <!-- steer:placeholder -->

[One sentence stating what must hold.]

- Given [context], when [action], then [observable outcome]

## Data model

[Tables, fields, types. Only the parts that matter for this feature. Derive
from the intent's "Key concepts & data" / "Lifecycle expectations". If drafted
pre-production (e.g. a PO build), mark it `proposed - dev confirms at review`.]

```text
table: example
  id: uuid (pk)
  user_id: uuid (fk -> users.id)
  created_at: timestamp
```

## API surface

[Endpoints, payloads, response shapes. Skip if not applicable.]

```text
POST /api/example
  body: { name: string }
  returns: { id: uuid }
```

## Implementation pointers (optional)

A **hint** to where this feature lives - not a maintained index. Hand-kept file
lists go stale on every refactor, so keep this light. If it's absent or stale,
find the code by searching the repo.

For a feature spanning multiple apps/packages, **naming the owner is more
durable than listing files** - prefer it:

* Owning app(s): `apps/web`, `apps/api`
* Owning package(s): `packages/core`

File-level pointers below are a courtesy only; nobody is obligated to keep them
perfect:

* `apps/<app>/.../file.ts` - [what this does for the feature]
* Route: `POST /api/example` defined in `apps/api/.../route.ts`

## Dependencies

* [Other features or external services this depends on]

## Notable decisions

[Anything non-obvious about how this is implemented. If it warrants a full ADR, link to one in `/spec/decisions` instead.]

*
