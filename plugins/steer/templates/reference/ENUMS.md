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
through delivery and into production. (See `SPEC-FRAMEWORK.md`,
`ISSUE-WORKFLOW.md`.)

## `question_status` — an open question's state

`open · investigating · resolved · deferred · cancelled`

`open`, `investigating`, and `deferred` are the **unresolved** set that can block
a gate; `resolved` means the answer is folded into the spec's normative prose;
`cancelled` means the question no longer applies. (See the open-question format in
`SPEC-FRAMEWORK.md`.)

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

`epic · feature · bug · task · finding · spec-question · spec-drift · audit-run`

Kind is the `steer:kind` marker + GitHub Issue Type, never a label. (See
`ISSUE-SCHEMA.md`.)

**`epic`** is the tier above `feature`: a parent tracking issue that groups child
features (and, transitively, their tasks/bugs) via native sub-issue links, so a
goal spanning several features is visible as one hierarchy. It is a *grouping*
construct owned by the tracker — it has **no `intent.md`** and is **not
materializable**; its "why" is the rollup of its child features (each of which has
its own intent), optionally pointing at a `vision.md` theme. Type=`Epic` is set
only when the org enables that issue type; otherwise the epic stays a normal issue
carrying `steer:kind=epic` with Type left unset (capability degradation in
`ISSUE-WORKFLOW.md`). Milestones remain release grouping — an orthogonal axis, not
the epic aggregator.

## `issue_state` — lifecycle state (the `steer:state` marker)

`inbox · exploring · ready-for-spec · ready-for-dev · in-progress · validate · blocked · done · cancelled`

The base source of truth; a Project `Status` field mirrors it when Projects are
enabled. `done` and `cancelled` are the two terminal states: **`done`** = closed
as completed; **`cancelled`** = closed for a non-completion reason
(`rejected`/`duplicate`/`obsolete`/`not-planned`/`superseded`). Closure *reason*,
not mere closure, decides which. (See `ISSUE-WORKFLOW.md` Completion rules.)

## `issue_source` — origin (the `steer:source` marker; the `source:*` label mirrors it)

`human · adoption · audit · security-review · code-review · ci · dependency · implementation · spec`

## `issue_relationship` — how one issue relates to another

`relates-to · depends-on · blocks · conflicts-with · supersedes · superseded-by`

The relationship vocabulary `/steer:issues` uses when it surfaces a connection
between issues during `brainstorm`/`capture` and records it (via
`/steer:tracker-sync link-related`) under the `Related issues` heading. GitHub has
**no native typed relationship** beyond parent/sub-issue, so the relationship word
is metadata the workflow owns; the **link itself** is an ordinary `#N`
cross-reference (GitHub auto-creates the backlink). Meanings:

- **`relates-to`** — a generic association worth a reader's attention; no ordering
  or exclusivity implied.
- **`depends-on`** — this issue cannot be completed until the other lands.
- **`blocks`** — the inverse: the other issue waits on this one.
- **`conflicts-with`** — the two cannot both proceed as written; a human must
  reconcile the decision (e.g. a Cognito-hosting issue vs. a `better-auth`
  migration issue). **Never auto-resolved** — it is surfaced, not decided.
- **`supersedes`** — this issue replaces the other (the other is a candidate for
  close-as-`superseded`).
- **`superseded-by`** — the inverse.

Parent/sub-issue links are **not** in this enum — they are native GitHub links via
`/steer:tracker-sync link-parent` (or the `steer:parent-issue` marker fallback).
Duplicates are handled by `triage` close-as-duplicate, not a relationship word.

## `issue_priority` — relative urgency (a native GitHub **issue field**, not a label)

`Urgent · High · Medium · Low`

The single-select **Priority** issue field (GitHub's default option set), read for
ranking and **escalate-only** auto-set. It lives on the issue as a native field
set via `/steer:tracker-sync field-set` — **never** a `priority:*` label and never
in the issue body (see `LABELS.md`, `ISSUE-SCHEMA.md` → native issue fields). The
ranking weight is `Urgent > High > Medium > Low`, with **unset = lowest** (never
fabricate a value). It orders the backlog *within* the shared safety precedence —
it never overrides it (see `NEXT-ACTIONS.md`).

`steer` auto-sets only a **floor**, never a ceiling, from mechanical signals
(`risk:security` → `Urgent`; an open `blocking` question gating this issue →
`High`; …) and never silently downgrades a human-set value. **Effort, Start date,
and Target date** are the other default issue fields; `steer` reads them and (for
dates) writes them under human confirmation via `/steer:roadmap`, but their option
sets are **org-defined** — read from the field definition, not pinned here. Where
the org has not enabled issue fields, ranking treats Priority as unset and the
field is omitted (capability degradation in `ISSUE-WORKFLOW.md`).

## `adr_status` — an ADR's state

`Proposed · Accepted · Superseded · Deprecated`

A `Proposed` ADR is a *Human decision required* next action (awaiting its
Deciders). (See `SPEC-FRAMEWORK.md` → Architecture Decision Records.)

## `next_action` — the `## Recommended next actions` categories

`Blocking now · Human decision required · Required before initial production · Required before next production release · Urgent live-system remediation · Recommended · Complete`

The categories every workflow's `## Recommended next actions` block draws from.
Release timing is **lifecycle-aware**: *Required before initial production*
(not-yet-launched) vs *Required before next production release* (already live) vs
*Urgent live-system remediation* (a live system actively at risk). (See
`NEXT-ACTIONS.md` for categories, precedence, and derivation.)
