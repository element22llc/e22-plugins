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
| `design/` | Design-export home: `README.md`, product-level `source.md` provenance (greenfield), and the living global `architecture.md` diagram that the root `ARCHITECTURE.md` links to. |
| `sources/` | Versioned home for recurring PO source documents, maintained by [`/steer:intake`](../workflows/intake.md). |
| `reference/` | Catch-all home for durable **one-off** (non-versioned) source/research material feeding the spec — inventories, vendor metadata, schema/DDL dumps, discovery docs. Created on demand by [`/steer:tidy`](../workflows/index.md); a document sent once can stay here, but the moment it starts arriving in versions it belongs under `sources/`. |
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

## Decisions land in the spine, not in side-channels

A durable design decision — the stack, an auth model, a data model, a locked MVP
scope — belongs in the spine: a feature's `intent.md`, a `contract.md`, or an
ADR. Conversation, chat summaries, and assistant memory are working notes, not
the record; a decision that survives only there leaves the repo with no trace of
it, and a teammate cloning the repo inherits nothing.

This has a sharp edge on a **brand-new repo with no spine yet**. The scoping
dialogue that shapes a product is expected — but bootstrap is the *first move*,
not a closing step: run [`/steer:init`](../workflows/index.md) (greenfield) or
[`/steer:adopt`](../workflows/adopt.md) (existing code) before persisting any
decision, so the scoping folds into the setup interview and each choice lands as
an ADR or `vision.md` entry, reviewable in the bootstrap PR. Capturing decisions
to memory or prose *instead of* a spine that doesn't exist yet is the
single-source-of-truth break the always-on `31-decision-capture` rule exists to
prevent.

The same logic applies to **everything a working session surfaces**, not just
formal decisions. Claude Code's private session memory survives compaction, but
it is invisible to the repo, the PR, and every teammate — so steer does not offer
to "remember" a finding there. The always-on `26-context-hygiene` rule routes
each fact to its canonical on-disk home **by type** instead: a **bug fix** → a
regression test; an **operational or behavioral fact** → the app guide or
`/spec/HISTORY.md`; an **unresolved bug or follow-up** → a
[linked tracker issue](../workflows/issues.md); a **durable design decision** →
the spine. Each fact lands in exactly one home, and that capture is surfaced as
part of the work rather than offered as an optional "want me to remember this?".

## How the spine stays current

- [`/steer:audit spec`](../workflows/index.md) compares the as-built spine against the
  tracker's intent (read-only).
- [`/steer:sync`](../workflows/index.md) reconciles the materialized spine and
  scaffold against the current plugin templates after a release.

Next: how work moves through the [lifecycle](lifecycle.md).
