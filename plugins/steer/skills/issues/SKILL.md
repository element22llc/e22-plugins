---
name: issues
description: "GitHub Issues lifecycle for the /spec spine — capture, triage, brainstorm, materialize, decompose, epics, status, a ranked relationship-aware board, and bounded reconcile. A thin orchestrator; /spec stays product truth, the issue is the work/decision layer."
when_to_use: >-
  Use to manage the backlog without implementing now — drive a PO idea from
  capture to a draft spec to decomposed work without losing open questions or
  overwriting human content.
argument-hint: "[capture | triage | brainstorm | materialize | decompose | epic | status | board | reconcile | publish-audit | publish-drift | publish-adoption | publish-findings | bootstrap-labels] [#issue | feature-id]"
allowed-tools:
  - Bash(git status *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
  - Bash(gh pr list *)
---
<!-- steer:modes capture,triage,brainstorm,materialize,decompose,epic,status,board,reconcile,publish-audit,publish-drift,publish-adoption,publish-findings,bootstrap-labels -->

# Drive the GitHub Issues lifecycle for the /spec spine

`/steer:issues` is the **PO-facing lifecycle workflow** above the low-level
`/steer:tracker-sync` gateway. It **orchestrates; it does not own domain
reasoning** — every step delegates to the skill that owns it and routes GitHub
I/O through `/steer:tracker-sync`. The two invariants from the issue-workflow
reference hold throughout:

- **`/spec` is durable product truth; GitHub Issues is the work/decision layer.**
- **All reads/writes go through `/steer:tracker-sync`** (MCP-first → `gh` → manual
  floor); this skill never calls the GitHub API directly — with one sanctioned
  exception, `bootstrap-labels`, which runs `gh label create --force` inline
  because label-taxonomy setup is a repo-level operation the issue-scoped
  `/steer:tracker-sync` gateway exposes no op for.

## Guardrails

These apply to **every** mode, for the whole run.

- **Orchestrate, don't duplicate.** Delegate to the owning skill; never restate
  its prose here. All GitHub I/O goes through `/steer:tracker-sync`.
- **Idempotent.** Find before create — search by marker (`feature-id`+`kind`,
  `question-id`, `finding-key`). A match means update, not create.
- **Managed blocks only.** Updating an issue rewrites **only** the
  `steer:managed` block; markers, human sections, and unknown content are
  preserved verbatim.
- **Authorization & confirmation.** Reads never confirm. When to act without
  asking vs confirm first (explicit request → no ask; bulk finding-publish → one
  batch confirmation; unsolicited idea → confirm before external publish;
  managed-block update in an active workflow → no repeat) and when a state
  transition may be *performed* vs only *proposed* are governed by the single
  **Authorization & confirmation** block + authority table in `ISSUE-WORKFLOW.md`.
  This skill does not restate them.
- **No code, no spec rewrites beyond pointers + materialized intent.** The spec
  edits this skill drives are the materialized `intent.md` (via `/steer:spec`) and
  `> Tracker:` / `tracker:` pointer lines. It never edits `/apps`, `/packages`,
  or `contract.md` behavior. **Execution from an issue — claim, branch,
  implement, test, open the PR, transition — belongs to `/steer:work`**, not here.

## Coupling rules

Lifecycle, state model, and authority are canonical in `ISSUE-WORKFLOW.md`; the
issue format in `ISSUE-SCHEMA.md`; the open-question + validate contract in
`SPEC-FRAMEWORK.md`; tracker conventions in rule `35-issue-tracker` and
`/steer:reference traceability`. GitHub I/O is `/steer:tracker-sync`'s job. This skill only
sequences those across the lifecycle.

## First, every run

1. **Read `/spec/tracker.md`.** Confirm `system: github`. On a non-GitHub
   tracker, say so and stop — there is no GitHub path; the manual flows in
   `/steer:tracker-sync` apply. Never fabricate tracker state.
2. **Detect capability via `/steer:tracker-sync`** (MCP vs `gh` vs manual) and say
   which path you took, so the user knows whether issues were actually touched.
3. **Polyrepo? The tracker and the specs are in the workspace.** In a member
   (`spec/PRODUCT.md`) there is no local `spec/tracker.md` and no
   `spec/features/**` — resolve the workspace first and read both from there
   (`/steer:reference polyrepo`); never file a product issue against the member's
   own repo to work around it. Two facts shape decomposition: **sub-issues do
   cross repositories** within an org (100 children per parent, 8 levels), so a
   workspace epic can parent member issues unmodified; **closing keywords do
   not**, so an issue in the workspace tracker never auto-closes from a member PR
   and must be closed explicitly after merge.

Read the references before acting: the lifecycle, state model, and authority
table in `${CLAUDE_PLUGIN_ROOT}/templates/reference/ISSUE-WORKFLOW.md`; the issue
format (markers, headings, **managed blocks**, idempotency) in
`ISSUE-SCHEMA.md`; the open-question contract in `SPEC-FRAMEWORK.md`.

## Question-reconciliation floor (safe from the first release)

Even before repo-wide reconcile, the per-feature lifecycle must guarantee — via
`/steer:spec validate` at every gate and `reconcile`:

- an **approved** intent contains **no `open` `blocking` question gated at
  `required_before: intent-approval`** (questions gated at later gates block
  their own gate, not the already-granted approval);
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

## Mode map — read only the procedure you need

Each mode's step-by-step procedure lives in a file under
`${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/`. **Read the one file for the mode
you are running; do not read the others.**

| Mode | What it does | Procedure |
|---|---|---|
| `brainstorm #N` | Product discovery against an issue, no spec written | [`delegating.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/delegating.md) |
| `materialize #N` | Approved intent → a draft `intent.md` via `/steer:spec` | [`delegating.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/delegating.md) |
| `publish-audit` | File `/steer:audit` findings as parent + children | [`delegating.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/delegating.md) |
| `publish-drift` | File `/steer:audit spec` drift as decision checklists | [`delegating.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/delegating.md) |
| `publish-adoption` | Reconcile `PRODUCTIONIZATION.md` gaps into findings | [`delegating.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/delegating.md) |
| `publish-findings` | File code-review / security-review findings | [`delegating.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/delegating.md) |
| `capture` | Open an issue from the conversation or a design source | [`backlog.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/backlog.md) |
| `triage [#N\|--all]` | Dedup, label, fill field gaps, route | [`backlog.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/backlog.md) |
| `board [--all]` | Read-only ranked, relationship-aware backlog view | [`backlog.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/backlog.md) |
| `bootstrap-labels` | Idempotently reconcile the label taxonomy | [`backlog.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/backlog.md) |
| `decompose #N` | Feature → implementation sub-issues (contract-gated) | [`hierarchy.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/hierarchy.md) |
| `epic` | The tier above features: group features under one parent | [`hierarchy.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/hierarchy.md) |
| `status [#N\|feature-id]` | Unified read-only issue + spec + readiness view | [`hierarchy.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/hierarchy.md) |
| `reconcile` | Verify issue ↔ spec pointers and lifecycle consistency | [`reconcile.md`](${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/reconcile.md) |

## Recommend the next action

After any mode, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. As an orchestrator,
recommend the **next valid lifecycle transition** for the issue(s) just touched
(locality rule), delegating the action to its owning skill.

| Issue lifecycle state | Category | Action / suggested command |
|---|---|---|
| `inbox`, not yet triaged | Recommended | `/steer:issues triage` |
| `exploring` (feature needs a spec) | Human decision required | Shape intent — `/steer:issues materialize` → `/steer:spec` |
| `ready-for-spec`, intent not approved | Human decision required | PO approves the intent — `/steer:spec approve` (offers the gate prompt) |
| `ready-for-dev`, decomposed and actionable | Recommended | Start it — `/steer:work start #N` |
| `in-progress` / `validate` | Human decision required | A reviewer reviews the open PR (no command) |
| Unresolved `blocking` question on the item | Blocking now | `/steer:questions` |
| Several `ready-for-dev` items to sequence into releases | Recommended | Lay them on a timeline — `/steer:roadmap` |
| `epic` in `exploring`, child features identified | Recommended | Link them — `/steer:issues epic #E --add …` |
| `epic` whose child features are all terminal (≥1 `done`) | Human decision required | PO confirms the epic outcome (no command) |
| Nothing queued | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence. Read-only and idempotent —
it recommends the transition; it does not perform unapproved writes.
