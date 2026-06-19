# Controlled vocabularies (enums)

Human-readable documentation of every controlled vocabulary the workflow
uses. The **machine-readable source of truth** is
[`enums.registry`](enums.registry); this file explains each value. CI
(`scripts/check_standards.py`) asserts the two **agree exactly** — if you change
one, change the other in the same commit, or the build fails.

Every `Status:` / state / `source:` / `required_before:` / next-action token that
appears in rules, skills, templates, and active fixtures must be a member of the
matching enum below (CI enforces this too).

## `feature_status` — a feature intent's lifecycle

`draft · approved · implemented · validated · live`

A materialized intent starts at **`draft`** (`/steer:issues
materialize` never approves). Only **`/steer:spec approve`** flips it
to **`approved`**. `implemented` / `validated` / `live` track its progress
through delivery and into production. (See `spec-framework.md`,
`ISSUE-WORKFLOW.md`.)

## `question_status` — an open question's state

`open · investigating · resolved · deferred · cancelled`

`open`, `investigating`, and `deferred` are the **unresolved** set that can block
a gate; `resolved` means the answer is folded into the spec's normative prose;
`cancelled` means the question no longer applies. (See the open-question format in
`spec-framework.md`.)

## `question_impact` — whether a question blocks

`blocking · non-blocking`

A `blocking` question whose `required_before` gate is reached, and whose status is
still unresolved, blocks that gate.

## `created` — when a question was raised (not an enum)

A `created:` field, when present, is a **date** in `YYYY-MM-DD` form — not an
enum. It is **optional**; stamp it with today's date when writing a new question
so the SessionStart open-questions hook can measure staleness and escalate a
`blocking` question still open after `STEER_QUESTION_STALE_DAYS` (14). When it is
absent the hook falls back to the line's `git blame` date. A malformed
`created:` fails `/steer:spec validate`.

## `required_before` — the gate a question must clear before

`intent-approval · contract-approval · implementation · non-prod-validation · production-release`

`/steer:spec approve` is blocked only by a `blocking` question with
`required_before: intent-approval`; later gates block their own transitions.

## `issue_kind` — the work shape (the `steer:kind` marker, not a label)

`feature · bug · task · finding · spec-question · spec-drift · audit-run`

Kind is the `steer:kind` marker + GitHub Issue Type, never a label. (See
`ISSUE-SCHEMA.md`.)

## `issue_state` — lifecycle state (the `steer:state` marker)

`inbox · exploring · ready-for-spec · ready-for-dev · in-progress · validate · blocked · done · cancelled`

The base source of truth; a Project `Status` field mirrors it when Projects are
enabled. `done` and `cancelled` are the two terminal states: **`done`** = closed
as completed; **`cancelled`** = closed for a non-completion reason
(`rejected`/`duplicate`/`obsolete`/`not-planned`/`superseded`). Closure *reason*,
not mere closure, decides which. (See `ISSUE-WORKFLOW.md` Completion rules.)

## `issue_source` — origin (the `steer:source` marker; the `source:*` label mirrors it)

`human · adoption · audit · security-review · code-review · ci · dependency · implementation · spec`

## `adr_status` — an ADR's state

`Proposed · Accepted · Superseded · Deprecated`

A `Proposed` ADR is a *Human decision required* next action (awaiting its
Deciders). (See `spec-framework.md` → Architecture Decision Records.)

## `next_action` — the `## Recommended next actions` categories

`Blocking now · Human decision required · Required before initial production · Required before next production release · Urgent live-system remediation · Recommended · Complete`

The categories every workflow's `## Recommended next actions` block draws from.
Release timing is **lifecycle-aware**: *Required before initial production*
(not-yet-launched) vs *Required before next production release* (already live) vs
*Urgent live-system remediation* (a live system actively at risk). (See
`NEXT-ACTIONS.md` for categories, precedence, and derivation.)
