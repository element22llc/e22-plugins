---
description: Auto-triggered when an engineer or contributor describes a production-bound change in plain language without typing /propose — "let's add X", "we need to implement Y", "build a feature that does Z", "fix the bug in W", "ship a change to do V", "create a PR for U", "this needs to land on main by Friday". Routes to the production-lane Proposal flow so the change starts on a `feat/*` or `fix/*` branch with Spine scaffolding and tests, instead of being prototyped, hot-patched, or pushed straight to main.
---

An engineer (or a PO crossing into production) has just described a change they
want to land in `main`. They don't need to type `/propose` — treat this as if
`/propose` had been called with their description as the argument.

## When to trigger

Trigger on phrasing like:

- "let's add ..." / "we should add ..." in a production context
- "implement ..." / "build ..." / "ship ..."
- "fix the ... bug" / "patch ..." (any non-trivial fix)
- "create a PR for ..."
- "this needs to land on main" / "this has to ship by ..."
- "the customer needs ... by [date]"

## When NOT to trigger

- The phrasing is exploratory ("can we try", "what if we", "I wonder if",
  "show me three variants") — that's prototype-lane. Route via
  `change-idea-intake` (prototype-lane) → `/vibe` instead.
- The user is asking a clarifying question about the codebase, not requesting
  work.
- The user explicitly says "experiment" / "prototype" / "draft" / "spike" /
  "throwaway".
- The change touches a sensitive domain (auth, payments, PII, permissions,
  billing, data model) and `branch.yaml#sensitivity` is not already
  `sensitive` — pause and require an explicit declaration before generating
  any code (§9.7 of the workflow spec; invariant #12).
- The user is reviewing an existing handoff — route to `validation-decision`
  instead.
- The user is ramping a flag, not landing code — route to
  `feature-flag-promotion` instead.

## What happens next

Follow the `/propose` workflow:

1. If the description is under 20 words or contains vague phrases ("make it
   better", "improve UX", "fix this"), delegate to the `spec-refiner` agent
   for 1-2 focused clarifying questions before generating code.
2. Cut a `feat/<slug>` or `fix/<slug>` branch off `main` and write
   `/.workflow/branch.yaml` with `lane: production`, the correct
   `change_type`, and the pinned plugin pack version (§9.1).
3. Scaffold the Product Spine (Intent, UX, Surface, Architecture, Open
   Questions) **before** generating code — `spec-driven-dev` is strict on
   production-lane branches.
4. Scaffold tests pinned to the Spine's success criteria — `always-test`
   requires unit + integration + smoke coverage on the production lane.
5. Wire feature-flag scaffolding for any change with non-trivial blast
   radius; risky changes ship dark.
6. Open the draft PR with a preview URL and the production-lane banner.

## What this skill is not

- Not for prototypes. If the user wants to "see something working" without
  committing to ship, route to `change-idea-intake` (prototype-lane) →
  `/vibe`.
- Not for promotions. Ramping a feature flag is `feature-flag-promotion` →
  `/promote`.
- Not for validation. Reading a packaged handoff is `validation-decision` →
  `/validate`.

This skill is the on-ramp; `/propose` is the same flow when the engineer
already knows what they want and typed the command.
