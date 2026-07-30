# `/steer:issues` — backlog modes (`capture`, `triage`, `board`, `bootstrap-labels`)

Read this file when running `capture`, `triage`, `board`, or `bootstrap-labels`.
The guardrails, coupling rules, and the `## Recommended next actions` contract
stay in `SKILL.md` — they apply to every mode and are not repeated here.

## `capture`

Open an issue from the current conversation, prototype, screenshot, or design
source. Gather the same **semantic fields** the matching Issue Form asks for
(feature / bug / product-question / improvement) and **render them into the
machine-readable body** (markers + headings + managed block) — do **not** try to
submit a Form (it's human UI only). Default labels per kind (`source:human`,
`needs:triage`); enters **Inbox**.

**Before creating, search the corpus** via `/steer:tracker-sync search` (open +
closed) — this serves dedup (an exact match means update/skip, not a second
issue) *and* relationship-discovery. When the new issue **overlaps, depends on,
or conflicts with** an existing one, populate its `Related issues` heading and
propose the reciprocal `/steer:tracker-sync link-related`; flag a
`conflicts-with`/`supersedes` for human reconciliation rather than deciding it.

## `triage [#N|--all]`

Keep the backlog clean and correctly labelled. For each issue:

- **Deduplicate** — search by marker (`feature-id`+`kind`, `question-id`,
  `finding-key`) and title; flag duplicates and propose close-as-duplicate
  (link to the canonical issue), never silently merging human content.
- **Label correctness (esp. human-created issues)** — apply the right
  `source:*` (e.g. `source:human` for manually opened issues), `needs:*`, and
  `risk:*` labels from `templates/reference/LABELS.md`. When the kind is
  missing (issue opened without a Form or marker), infer it (feature / bug /
  product-question / improvement) from the content and set the `steer:kind`
  marker + GitHub Issue **Type**. Resolve conflicting labels (e.g. both
  `bug`-ish and `feature`-ish). Kind is never a plain label.
- **Missing required information** — bug without repro/expected-vs-actual,
  feature without acceptance criteria, etc. Post the request in **one** managed
  comment and apply `needs:triage` rather than guessing the content.
- **Cleanup signals** — report stale `needs:triage` issues, orphaned
  sub-issues (no parent link), and mislabelled items; propose fixes.
- **Priority (escalate-only auto-set) & field gaps** — set the native
  **Priority** field to the **mechanical floor** via `/steer:tracker-sync
  field-set`, escalate-only (`max(current, floor)`) under the ledger-based
  never-fight-a-human guard. The floor table, the provenance/suppression
  guard, the PO-directed-seeding distinction (a human value: no ledger, no
  `max()` guard), and the Projects-v2 trap (the native issue field is the
  only writable home) are all canonical in `ISSUE-SCHEMA.md` → *Native issue
  fields & the Projects v2 boundary* — apply them, don't restate them.
  Surface a *missing* Effort or a missing **Priority on a `ready-for-dev`**
  issue as a field gap; propose, never auto-fill (human-set only).
- **Routing** — suggest the next transition; propose Inbox → Exploring and
  **perform it only where the authority table in `ISSUE-WORKFLOW.md` allows**.

Scope: `#N` triages one issue; `--all` sweeps open issues, emits a summary
report, and takes **one** batch confirmation before any writes. All GitHub
reads/writes (labels, types, comments, closes) go through `/steer:tracker-sync`;
rewrites touch only the `steer:managed` block. Priority and effort are **native
issue fields, never labels** (`ISSUE-SCHEMA.md`) — never invent `priority:*` /
`effort:*` labels for them.

## `board [--all]`

A **read-only** backlog overview: the open issue set as one ranked,
relationship-aware, hygiene-flagged view. **Never writes.** Reads through
`/steer:tracker-sync` (`search`, `field-get`) and says which capability path it
took. Four sections:

- **Ranked** — issues ordered by the **composite sort key** in `NEXT-ACTIONS.md`
  (safety level → native **Priority** field → unblock-count → milestone proximity
  → lifecycle depth → created-at/#N). Show each issue's Priority and lifecycle
  state. The board **does not** re-derive the cross-workflow "single most critical
  thing" — that is `/steer:next`'s job (locality: a board ranks *issues*; it does
  not arbitrate ADRs, PR-review gates, or secrets). Where issue fields are
  unavailable, Priority shows as unset and the remaining terms order the list.
- **Relationships** — dependency clusters from native blocked-by edges (and the
  `Related issues` markers where native is unavailable): what blocks what, and any
  `conflicts-with`/`supersedes` pair surfaced for a human. Never auto-resolve.
  Also show **Epic → Feature → Task** parent/child clusters — these are native
  sub-issue links, so they render as a real hierarchy in a Projects v2 view by
  construction (markers only where native sub-issues are unavailable).
- **Dedup candidates** — likely duplicates by marker (`feature-id`+kind,
  `question-id`, `finding-key`, `dedupe-key`) and semantic title overlap; propose,
  don't merge (close-as-duplicate is a `triage` action).
- **Hygiene** — stale `needs:triage`, orphaned sub-issues (no parent), **orphaned
  epics** (an epic that claims `in-progress` or later with zero linked features),
  missing **Priority** on `ready-for-dev`, missing kind/Type, and mislabelled items
  — each with the `triage`/owning action that fixes it. The fix for a Priority/Effort
  gap is a **native issue-field** write via `/steer:tracker-sync field-set` (PO value)
  or the `triage` escalate-only floor (mechanical) — **never** the Projects API,
  whose same-named board column is a read-only projection (`ISSUE-SCHEMA.md`).
  Surfaces work; performs none.

`#N`/`feature-id` scopes to one item's neighborhood; `--all` (default) sweeps open
issues. It ends with the `## Recommended next actions` block (see `SKILL.md`).

## `bootstrap-labels`

Idempotently create/reconcile the supported label taxonomy so Issue Forms and
agent labels actually apply (GitHub silently drops a form label that doesn't
exist). Reconciles the exact `source:*` / `needs:*` / `risk:*` set in
`templates/reference/LABELS.md` (the canonical list; `source:*` mirrors the
`steer:source` enum) via `gh label create --force` (create-or-update; safe to
re-run). `/steer:init` and `/steer:adopt` call this during setup. Kind is
**not** a label (it's the `steer:kind` marker + Issue Type).
