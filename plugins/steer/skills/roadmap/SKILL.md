---
name: roadmap
description: "Generate a release timeline for the /spec spine and make it viewable as a GitHub Projects v2 roadmap — turn intended-but-unshipped work into GitHub issues grouped under release milestones with due dates. A thin orchestrator over /steer:issues, /steer:audit spec, and /steer:tracker-sync; the issue + /spec stay canonical, the Project is a derived view, and it never fabricates dates."
when_to_use: >-
  Use to lay out where the product is going on a timeline — when asked for a
  roadmap, a release plan, or a Projects v2 timeline, or to turn target features
  or a spec-vs-implemented gap into milestone-grouped GitHub issues.
argument-hint: "[from-features | from-gap | sync]"
---
<!-- steer:modes from-features,from-gap,sync -->

# Generate a release-milestone roadmap for the /spec spine

`/steer:roadmap` turns **intended-but-unshipped work** into GitHub issues grouped
under release **Milestones**, so an existing GitHub Projects v2 roadmap/timeline
view can lay the work out by milestone. It is a **thin orchestrator above
`/steer:issues` and `/steer:audit spec`** — it sequences the timeline; it does not own
domain reasoning and never touches the GitHub API directly. Two invariants from
the issue-workflow reference hold throughout:

- **`/spec` is durable product truth; GitHub Issues is the work/decision layer; a
  Project is a derived view/overlay** (the compatibility boundary in
  `${CLAUDE_PLUGIN_ROOT}/templates/reference/ISSUE-SCHEMA.md`).
- **All reads/writes go through `/steer:tracker-sync`** (MCP-first → `gh` → manual
  floor); this skill never calls the GitHub API directly.

It writes **only native issue attributes** the Projects-v2 boundary already
sanctions — Milestone, parent/sub-issue links, labels, Type. **Priority, Effort,
and Start/Target date are native issue fields** (`ISSUE-SCHEMA.md`), not
Project-item fields — Priority is escalate-only auto-set by `/steer:issues triage`,
and this skill writes the **Start/Target date** fields onto issues (human-confirmed)
so a Projects v2 roadmap lays out per-issue Gantt bars with no Project-item
mirroring; only **Status, Iteration, and Size** remain Project-item-only and out of
scope here. It **never fabricates a date**: dates come from the human at
confirmation.

## First, every run

1. **Read `/spec/tracker.md`.** Confirm `system: github`. On a non-GitHub tracker,
   say so and stop — there is no GitHub roadmap path; the manual flows in
   `/steer:tracker-sync` apply. Never fabricate tracker state.
2. **Locate the spine.** If there is no `/spec`, redirect to `/steer:init`
   (greenfield) or `/steer:adopt` (existing code) and stop — there is no work-set
   to lay out yet.
3. **Detect capability via `/steer:tracker-sync`** (MCP vs `gh` vs manual) and say
   which path you took, so the user knows whether issues/milestones were touched.

## Modes

A no-argument run is a **read-only preview**: resolve the work-set, propose the
milestone plan (below), and stop without writing.

### `from-features` — target features → timeline (forward planning)

The work-set is every `spec/features/*/intent.md` whose `> Status:` is not yet
`live` (`draft | approved | implemented | validated`). For each feature:

- **Find-or-create a feature-level issue** via `/steer:issues materialize` /
  `/steer:tracker-sync find-or-create` (idempotent on `feature-id`+`kind` — a match
  updates, never a second issue). Write the ref into the intent's `> Tracker:` line.
- **Fan out implementation sub-issues only where allowed** — call
  `/steer:issues decompose` for a feature **only** when it already meets decompose's
  precondition (intent `approved` **and** contract readiness `ready`, the
  derivation in `SPEC-FRAMEWORK.md`). A feature below that bar appears on the
  roadmap as its single feature issue, not yet decomposed — never force it past the
  gate just to populate the timeline.

### `from-gap` — spec-vs-implemented gap → timeline (the backlog you must still build)

Run `/steer:audit spec` (read-only) to diff the as-built `/spec` against the intended
spec, then take **only the expected-unbuilt units** — `🔴 Missing` / `🟠 Partial`
whose tracker status is Backlog/To-Do, the "unbuilt roadmap" bucket `/steer:audit spec`
already separates from **Done-but-Missing defects**. Do **not** put Done-but-Missing
or Diverged findings on the roadmap — those are drift to resolve via
`/steer:issues publish-drift`, not planned work. File the expected-unbuilt units the
same way `from-features` does — **find-or-create** via `/steer:issues materialize` /
`/steer:tracker-sync find-or-create` (idempotent on `feature-id`+`kind`; a match
updates, never a duplicate). These are planned **backlog**, so they are **not**
`spec-drift`-labelled — that label is reserved for actual drift (Diverged /
Done-but-Missing), per `/steer:audit` and `/steer:tracker-sync push`.

### `sync` — reconcile the plan with reality (idempotent re-run)

Re-resolve the work-set, verify its issues still exist and their milestone grouping
still matches the spine, and report every disagreement (issue gone, feature now
`live` but still milestoned as pending, milestone/date changed in the UI). Confirm
once before correcting. **Create-or-leave**: never overwrite a milestone title or
due date a human edited on GitHub — the human is canonical for the *when*.

## Propose the release plan (human-gated, no fabricated dates)

After resolving the work-set in any writing mode:

1. **Group** the work-set into release milestones, **ordered to respect
   `depends-on`/`blocks`** links recorded under issues' `Related issues` headings —
   an item may not land in a milestone earlier than something it depends on.
   Surface any dependency **cycle or `conflicts-with`** for a human; never
   auto-resolve it.
2. **Propose milestone titles + due dates** as a structure only. The skill chooses
   neither the dates nor the priority order beyond dependency constraints — those
   are human planning calls. **Ask the human to supply or confirm each milestone
   title and due date.**
3. **Take one confirmation** for the whole plan, then materialize via
   `/steer:tracker-sync`:
   - **`milestone-ensure <title> [--due <date>]`** — create each confirmed
     milestone if missing (it is confirmation-gated and never invents a date).
   - **`set-milestone #N <title>`** — attach each work-set issue to its milestone.
   - **`field-set #N "Target date" <date>`** (and `"Start date"` when the human
     gave one) — write the **human-confirmed** dates to the native date **issue
     fields**, so a Projects v2 roadmap can lay out per-issue Gantt bars without any
     Project-item mirroring. Use the same dates the human just confirmed — **never
     fabricate one**. Capability-degrades: if issue fields are unavailable, skip the
     date fields and rely on the Milestone grouping alone (say so).
4. **Report** the milestone set, the issue refs under each, and the org Project
   roadmap URL if `/spec/tracker.md` records one. Note that the Projects v2 timeline
   axis (group/lay-out by Milestone) is a **one-time view setup in the GitHub UI** —
   this skill produces the milestoned issues the view renders; it does not create
   or configure the Project (no per-repo board automation).

### Shareable timeline (Artifact, optional)

The GitHub Projects v2 roadmap is the canonical timeline view, but it needs a
GitHub login and the one-time view setup. For a **quick, shareable snapshot** — the
no-arg preview a PO can glance at, or a hand-off after a plan lands — **offer** to
render the milestone plan as a **Claude Artifact**: milestones as columns/bands,
each with its issues laid out as horizontal bars ordered by the same `depends-on`
constraints, blocking/dependency edges flagged. It is an **offer, on request** — a
derived preview of the Projects v2 view, never a replacement for it and never
auto-published.

Render by the shared discipline — `/steer:reference artifacts` (rule
`88-artifacts`); do not restate its mechanics. Roadmap specifics:

- **Derived, never fabricated** (mirror the Guardrails below): every bar encodes a
  real milestoned issue and a **human-confirmed** date — no invented date, priority,
  or ordering beyond declared dependencies. A milestone with no confirmed date shows
  as *"date not set"*, never a guessed one.
- Write the HTML to `<tempdir>/steer-roadmap-timeline.html` (a system temp dir,
  never under the repo tree); do **not** persist the page URL in `/spec` or the
  tracker. Where the Artifact tool is unavailable, print the timeline as an inline
  Markdown table (milestone → issues → dates) and say why.

## Guardrails

- **Orchestrate, don't duplicate.** Delegate to the owning skill; never restate its
  prose. All GitHub I/O goes through `/steer:tracker-sync`.
- **Idempotent.** Find before create (`feature-id`+`kind` / `finding-key`); a match
  is an update. Re-running a mode must not double-file issues or milestones.
- **Native attributes only.** Writes are Milestone, links, labels, Type, and the
  native Start/Target **date** issue fields — never a Project-*item* planning field
  (Status/Iteration/Size), never mirrored into an issue body.
- **Milestone = release, not epic.** An epic (a `kind=epic` parent grouping features
  by goal) is an **orthogonal axis** to the release Milestone (when work ships). This
  skill groups by Milestone exactly as above; it may *display* epic membership but
  **never repurposes the Milestone as the epic aggregator** — epic grouping is owned
  by `/steer:issues epic`.
- **No fabricated planning data.** Never invent a date, priority, or effort. Dates
  are human-supplied; ordering follows declared dependencies only. The optional
  timeline Artifact is bound by the same rule — a derived, temp-only view (rule
  `88-artifacts`); its URL is never persisted in `/spec` or the tracker.
- **Authorization & confirmation.** Reads (preview) never confirm. The full plan
  takes **one** confirmation before any milestone/issue write; an explicit
  per-feature/per-finding request follows the intent rules in `ISSUE-WORKFLOW.md`.
  This skill restates none of that authority model.
- **No code, no spec rewrites beyond pointers.** The only spec edit is an intent's
  `> Tracker:` line (via the delegated skills). It never edits `/apps`, `/packages`,
  or `contract.md` behavior, and never resolves drift or a product decision.

## Recommended next actions

After any mode, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, scoped to this run
(locality rule), recommending the next valid step and delegating it to its owner.

When the user is the PO — see rule 05 (Who you are working with) — render this
readout in plain product language (no safety-level codes, no milestone/ADR/CI
jargon); keep the technical detail for devs.

| Observed state | Category | Action / suggested command |
|---|---|---|
| Dependency cycle / `conflicts-with` among work-set items | Human decision required | Resolve the ordering (no command) |
| Milestone plan proposed, awaiting dates/approval | Human decision required | PO/dev confirm titles + due dates (no command) |
| Plan confirmed; issues not yet milestoned | Recommended | Materialize — `/steer:roadmap from-features` / `from-gap` |
| `ready-for-dev` issue on the next milestone | Recommended | Start it — `/steer:work start #N` |
| Feature now `live` but still milestoned as pending | Recommended | Reconcile — `/steer:roadmap sync` |
| Done-but-Missing / Diverged drift surfaced | Required before next production release | File it — `/steer:issues publish-drift` |
| Roadmap current, nothing queued | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence. Read-only in preview; in a
writing mode it recommends the next transition, it does not perform unapproved
writes.

## Coupling rules

The Projects-v2 compatibility boundary and issue format are canonical in
`ISSUE-SCHEMA.md`; lifecycle/state/authority in `ISSUE-WORKFLOW.md`; the spec-gap
verdict model in `/steer:audit spec`; contract readiness + the open-question contract in
`SPEC-FRAMEWORK.md`; milestone conventions in `/spec/tracker.md` and rule
`35-issue-tracker`. GitHub I/O is `/steer:tracker-sync`'s job. This skill only
sequences those into a release timeline.
