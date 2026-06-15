---
name: e22-issues
description: "High-level GitHub Issues lifecycle for the /spec spine — capture, triage, brainstorm, materialize, decompose, status, and bounded reconcile. A thin orchestrator: it delegates product/spec reasoning to /e22-spec, audit findings to /e22-audit, drift to /e22-drift, and question promotion to /e22-questions, and routes ALL GitHub reads/writes through /e22-tracker-sync (MCP-first, gh fallback, manual floor). Agent-authored issues follow the machine-readable contract (stable headings + hidden markers + managed blocks). /spec stays product truth; the issue is the work/decision layer."
when_to_use: Use to drive a PO idea from capture to a proposed spec to decomposed work without losing open questions or overwriting human content.
argument-hint: "[capture | triage | brainstorm | materialize | decompose | status | reconcile] [#issue | feature-id]"
---

# Drive the GitHub Issues lifecycle for the /spec spine

`/e22-issues` is the **PO-facing lifecycle workflow** above the low-level
`/e22-tracker-sync` gateway. It **orchestrates; it does not own domain
reasoning** — every step delegates to the skill that owns it and routes GitHub
I/O through `/e22-tracker-sync`. The two invariants from the issue-workflow
reference hold throughout:

- **`/spec` is durable product truth; GitHub Issues is the work/decision layer.**
- **All reads/writes go through `/e22-tracker-sync`** (MCP-first → `gh` → manual
  floor); this skill never calls the GitHub API directly.

Read the references before acting: the lifecycle, state model, and authority
table in `${CLAUDE_PLUGIN_ROOT}/templates/reference/ISSUE-WORKFLOW.md`; the issue
format (markers, headings, **managed blocks**, idempotency) in
`ISSUE-SCHEMA.md`; the open-question contract in `spec-framework.md`.

## First, every run

1. **Read `/spec/tracker.md`.** Confirm `system: github`. On a non-GitHub
   tracker, say so and stop — there is no GitHub path; the manual flows in
   `/e22-tracker-sync` apply. Never fabricate tracker state.
2. **Detect capability via `/e22-tracker-sync`** (MCP vs `gh` vs manual) and say
   which path you took, so the user knows whether issues were actually touched.

## Modes

### Delegating modes (the owning skill does the thinking)

- **`brainstorm #N`** — product discovery against an issue, *without* writing a
  spec. Read the issue + related specs, find overlapping features/issues, ask
  focused questions, and maintain **one** editable "AI synthesis" comment
  (proposed outcome + boundaries) rather than reposting summaries. The issue body
  stays human-owned. Discovery reasoning follows `/e22-spec`'s interview style.
- **`materialize #N`** — turn approved product intent into a spec. Hand to
  `/e22-spec` to write/update `spec/features/<id>/intent.md`, **set `Status:
  proposed`** (never `approved` — that's a later explicit `/e22-spec approve`),
  link the issue in `> Tracker:`, run `/e22-spec validate` on the feature, and
  present the diff / open a PR. Comment back on the issue with the exact spec
  path + commit/PR.
- **`publish-audit [report]`** — take an `/e22-audit` finding set and create/update
  the audit-run parent + selected finding children (see `/e22-audit`); file via
  `/e22-tracker-sync`.
- **`publish-drift [report]`** — take an `/e22-drift` finding set and file
  decision-checklist `spec-drift` issues (see `/e22-drift`); never auto-resolve.

### Net-new modes (logic lives here)

- **`capture`** — open an issue from the current conversation, prototype,
  screenshot, or design source. Gather the same **semantic fields** the matching
  Issue Form asks for (feature / bug / product-question / improvement) and
  **render them into the machine-readable body** (markers + headings + managed
  block) — do **not** try to submit a Form (it's human UI only). Default labels
  per kind (`source:po`, `needs:triage`); enters **Inbox**.
- **`triage [#N|--all]`** — for each issue: detect duplicates (search by marker /
  title / feature-id), classify (type + `source:`/`needs:`/`risk:` labels),
  identify missing information, and suggest routing + the next transition. Propose
  Inbox → Exploring; perform it only where the authority table allows.
- **`decompose #N`** — create implementation sub-issues from a parent feature.
  **Preconditions:** the feature's `intent.md` exists, `Status: approved`, no
  blocking question `required_before: contract-approval`, and a `contract.md`
  exists (or shaping is explicitly in scope). Use native GitHub parent/sub-issue
  links when available; else fall back to `Parent: #N` + `<!-- e22:parent-issue=N -->`
  and a generated checklist in the parent. Each child uses the `technical-task`
  body. `--prototype` is the **only** way to decompose before approval, and those
  tasks are clearly marked non-production.
- **`status [#N|feature-id]`** — a unified read-only view: issue state + intent
  status + contract status + sub-issue progress + blockers. Runs `/e22-spec
  validate` and surfaces any failures. Example shape:
  ```
  Feature customer-export
  Issue: #123 — Validate
  Intent: approved   Contract: approved
  Implementation: 3/4 sub-issues closed
  Preview: available
  Blocking: #134 telemetry
  ```
- **`project [bootstrap|sync]`** — **optional** GitHub Project enrichment, gated
  on `project.enabled: true` + a `project.number` in `tracker.md`. `bootstrap`
  creates the recommended fields + views (see `ISSUE-WORKFLOW.md`) via
  `gh project` (field-create / view); `sync` sets an issue's field values
  (`Status`, `Priority`, …) from `tracker.md`'s `fields:` mapping. **Degrade
  gracefully:** org-level issue fields are public preview and may be
  unavailable — when a `gh project` call isn't supported, **skip that field, say
  so, and continue**; labels + the base lifecycle never depend on Projects.
  Never block the lifecycle on a missing Project.
- **`reconcile #N | feature-id | --all`** — verify issue ↔ spec pointers agree
  and the lifecycle is internally consistent; update only the managed block of
  any issue it touches; **never auto-resolve behavioural drift or a product
  decision** — route those to a human. Two scopes:
  - **bounded** (`#N` / `feature-id`) — one issue or feature. Enforce the
    question-reconciliation floor below.
  - **repo-wide** (`--all`) — sweep the spine + tracker and report every
    disagreement: referenced issues that no longer exist; closed features whose
    issues are still open (or vice versa); approved specs missing a tracker ref
    (`require_tracker_ref_for_features`); open `spec-drift` issues that no longer
    reproduce; sub-issues with no parent link; merged PRs that left a stale
    `Status`; promoted questions whose issue is closed but whose `Q-NNN` is still
    `open`. Output is a reconciliation report + proposed actions, confirmed once
    before any write. `--all` is read-heavy — route all fetches through
    `/e22-tracker-sync` and say so.

## Question-reconciliation floor (safe from the first release)

Even before repo-wide reconcile, the per-feature lifecycle must guarantee — via
`/e22-spec validate` at every gate and `reconcile`:

- an **approved** intent contains **no `open` `blocking` question**;
- a `deferred` question has `owner` + `required_before`;
- a **promoted** question carries a `tracker:` ref (and the issue carries its
  `question-id`);
- a question whose issue is **closed** cannot stay silently `open` — it surfaces
  as a failure that blocks the relevant gate;
- **resolving** a question means folding the answer into the spec's normative
  prose, not leaving it only on the issue or in `_Resolution:_`.

This is the trap the whole layer exists to prevent: a question promoted to an
issue, answered, and never returned to the spec, with implementation proceeding
on stale intent.

## Guardrails

- **Orchestrate, don't duplicate.** Delegate to the owning skill; never restate
  its prose here. All GitHub I/O goes through `/e22-tracker-sync`.
- **Idempotent.** Find before create — search by marker (`feature-id`+`kind`,
  `question-id`, `finding-key`). A match means update, not create.
- **Managed blocks only.** Updating an issue rewrites **only** the
  `e22:managed` block; markers, human sections, and unknown content are
  preserved verbatim.
- **Confirm before creating.** Issue creation is outward-facing — present the
  full batch and get **one** yes before the first create. Reads need no
  confirmation.
- **Authority.** Perform a state transition only where the authority table in
  `ISSUE-WORKFLOW.md` permits; everywhere else propose and wait for the named
  human. Never resolve behavioural drift or a product/policy decision
  autonomously.
- **No code, no spec rewrites beyond pointers + materialized intent.** The spec
  edits this skill drives are the materialized `intent.md` (via `/e22-spec`) and
  `> Tracker:` / `tracker:` pointer lines. It never edits `/apps`, `/packages`,
  or `contract.md` behavior.

## Coupling rules

Lifecycle, state model, and authority are canonical in `ISSUE-WORKFLOW.md`; the
issue format in `ISSUE-SCHEMA.md`; the open-question + validate contract in
`spec-framework.md`; tracker conventions in rule `35-issue-tracker` and
`/e22-traceability`. GitHub I/O is `/e22-tracker-sync`'s job. This skill only
sequences those across the lifecycle.
