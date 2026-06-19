# The product spine (`/spec`)

Every managed repo carries a **`/spec` spine** — the in-repo, version-controlled
source of product truth. Code is the implementation; `/spec` is the intent the
code is measured against. Skills read and write the spine; the issue tracker
references it.

## What lives in the spine

The spine is materialized from `plugins/steer/templates/spec/` and includes,
among others:

| Artifact | Role |
| --- | --- |
| `intent.md` (per feature) | The feature's purpose, acceptance criteria, tracker ref, and `## Open questions`. |
| `contract.md` | The feature's externally observable contract. |
| `vision.md`, `users.md`, `glossary.md` | Product-level framing shared across features. |
| `HISTORY.md` | Append-only log of what shipped, with tracker `Refs:`. |
| `tracker.md` | Declares the issue-tracking system and ref format. |
| ADRs | Ratified, hard-to-reverse decisions (see [Decisions](../decisions/index.md)). |
| `.version` | Stamps the plugin version the spine was reconciled against. |

## Spec vs tracker vs ADR

These three layers are deliberately distinct:

- **`/spec`** is the durable *record* of product truth.
- The **issue** is the *workflow* — where a decision or unit of work is driven.
- An **ADR** is the durable record of a hard-to-reverse *decision*.

A question stays in a spec's `## Open questions` (as `Q-NNN`) when it's local to
one feature; it is **promoted to an issue** when it needs a named owner, blocks
multiple features, needs stakeholder input, or could outlive the session. A
blocking question still open after 14 days has, by definition, outlived the
session: the SessionStart hook escalates it, and promotion assigns it to its
`owner:` role via the `owners:` map in `tracker.md`. So questions get *pushed*
at a named human rather than rotting in markdown — without every question
becoming an issue.

!!! warning "Reverse-engineering never invents decisions"
    `/steer:adopt` builds a spine from existing code, but it must **never infer a
    ratified ADR from code**. ADRs record human decisions; an as-built spine
    captures what *is*, not a decision that was never made.

## How the spine stays current

- [`/steer:drift`](../workflows/index.md) compares the as-built spine against the
  tracker's intent (read-only).
- [`/steer:sync`](../workflows/index.md) reconciles the materialized spine and
  scaffold against the current plugin templates after a release.

Next: how work moves through the [lifecycle](lifecycle.md).
