# [Feature Name] — Contract

> Owner: dev team
> Last updated: YYYY-MM-DD
> Implements: ./intent.md

## Behavior rules

[Concrete rules the implementation must satisfy. These should be testable.]

- Given X, when Y, then Z
- Validation: [field rules]
- Error states: [what happens when things go wrong]

## Data model

[Tables, fields, types. Only the parts that matter for this feature.]

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

A **hint** to where this feature lives — not a maintained index. Hand-kept file
lists go stale on every refactor, so keep this light. If it's absent or stale,
find the code by searching the repo.

For a feature spanning multiple apps/packages, **naming the owner is more
durable than listing files** — prefer it:

* Owning app(s): `apps/web`, `apps/api`
* Owning package(s): `packages/core`

File-level pointers below are a courtesy only; nobody is obligated to keep them
perfect:

* `apps/<app>/.../file.ts` — [what this does for the feature]
* Route: `POST /api/example` defined in `apps/api/.../route.ts`

## Dependencies

* [Other features or external services this depends on]

## Notable decisions

[Anything non-obvious about how this is implemented. If it warrants a full ADR, link to one in `/spec/decisions` instead.]

*
