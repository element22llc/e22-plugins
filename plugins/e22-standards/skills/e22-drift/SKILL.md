---
name: e22-drift
description: "Compare the as-built /spec (reverse-engineered from the code by /e22-adopt) against the intended spec exported from an issue tracker (Jira, Linear, GitHub Issues, … as markdown — one file per epic/issue or story/task) and surface every divergence. Read-only: reports findings and proposes Rule-5 resolutions, never edits."
when_to_use: Use when asked to check a built app against its tracker specs, audit spec drift, or confirm the code did what the tickets asked.
---

# Compare the as-built spec against the tracker spec (drift report)

A **manual, read-only conformance audit.** It compares two specs:

- the **as-built spec** — the `/spec` spine `/e22-adopt` reverse-engineered from
  the code, i.e. a faithful description of what the product *actually does*; and
- the **tracker spec** — what the product was *supposed* to do, exported from
  your issue tracker (Jira, Linear, GitHub Issues, …) as markdown, one file per
  epic/issue or per user story / task.

It surfaces every place the two diverge.

**It never edits code or spec.** Its outputs are a drift report, a proposed
Rule-5 resolution per finding, and `spec-drift` issues for anything needing a
human decision. Resolving drift is a separate, approved step (see the
spec-framework reference, Rule 5).

## Relationship to `/e22-adopt` — sequential, not inverse

`/e22-drift` **consumes** what `/e22-adopt` produces. `/e22-adopt` reverse-
engineers the as-built `/spec` from the code (reality). `/e22-drift` then diffs
that as-built spec against the tracker spec (intent). They are two stages of one
flow — adopt builds the picture of reality, drift checks it against what was
asked for — **not** opposites. (This supersedes the 1.24.0 framing of drift as
"the inverse of `/e22-adopt`.")

**If there is no `/spec` spine yet, stop and run `/e22-adopt` first** — there is
no as-built spec to compare against until the code has been reverse-engineered.

## When to run

- After landing a batch of work that spanned several epics/stories/issues, to
  confirm the build matches the combined intent.
- Periodically, to catch drift that accumulated across many small PRs.
- Before a release or handoff, as a conformance check against the tracker.

## Inputs

1. **The as-built `/spec` spine** — `features/*/intent.md` + `contract.md`,
   `decisions/*`, `vision.md`, `glossary.md`, as produced by a prior
   `/e22-adopt` run. This stands in for the code: its `contract.md` sections were
   *derived from the real code* and carry the `path:line` pointers. If it's
   absent, redirect to `/e22-adopt` and stop.
2. **The tracker spec export** — markdown files from any issue tracker (Jira,
   Linear, GitHub Issues, …), **one file per epic/issue or per story / task**. A
   coarse-grained file (epic, large issue) contains several sub-items with their
   own acceptance criteria; a story/task/sub-issue file is a single unit. The dev
   either **pastes them into the chat** or **points to a directory/path**. Ask
   which, if not given.

   **If the tracker is GitHub Issues, offer `/e22-tracker-sync pull` instead of
   pasting** — it materializes one markdown file per issue in exactly this shape
   (title, `#` key, labels, state, acceptance criteria) and hands the directory
   straight back here. For Jira/Linear/other, the paste/path export above stays
   the path.

## Phase 1 — Parse the tracker spec into intended-behavior units

The tracker export is the *intended* spec. Decompose it into comparable units.

1. **Read the export.** If pasted, use the chat text; if pointed to a path, read
   the markdown files there.
2. **Decompose each file by its grain.** A coarse-grained file (**epic**, large
   **issue**) fans out into its constituent stories/tasks/sub-issues, each with
   its acceptance criteria; a fine-grained file (**story / task / sub-issue**) is
   a single unit. Normalize each unit to a one-line *intended behavior* + its
   acceptance criteria, keeping the tracker key/title (e.g. `PROJ-123`, issue #)
   for traceability.
3. **Capture each unit's tracker status** (Backlog / To Do / In Progress / In
   Review / Done / …) alongside its key. Status is not cosmetic — it decides
   whether a "not built" finding is a *defect* or just *unbuilt roadmap* (see the
   status rule in Phase 2). A unit with no status is treated as unknown, not Done.
4. **Don't invent detail the tracker spec doesn't state** — where a unit is
   vague, flag it as Ambiguous rather than guessing what it meant.

## Phase 2 — Diff the as-built spec against the tracker spec

Map each intended-behavior unit to the as-built `/spec` feature
(`contract.md`/`intent.md`) that owns it, and classify the comparison. The
**as-built spec is reality** (it describes the code); the **tracker spec is
intent**. Cite the as-built evidence — the `contract.md` section and the
`path:line` pointer it already carries — never assert a match from the tracker
spec alone.

| Verdict | Meaning |
|---|---|
| ✅ **Matches** | The as-built spec captures the tracker-specified behavior. |
| ⚠️ **Diverged** | The as-built behavior differs from what the tracker spec asked for. |
| 🟠 **Partial** | The unit's acceptance criteria are split — some met by the as-built spec, others Missing or Diverged. Name which criteria fall on each side; don't let one verdict hide the gap. |
| 🔴 **Missing** | Tracker spec'd it, but the as-built spec (the code) has no such behavior — not built. |
| 🟡 **Unspecified** | As-built behavior with no backing tracker unit — built, but never asked for. |
| ❓ **Ambiguous** | One side too vague to judge; needs clarification. |

**Assign a verdict per unit, not per epic.** An epic is a *rollup* of units with
mixed verdicts — never collapse it to a single verdict (and never invent a
compound like "Partial / Missing" at epic grain). If you summarize at epic grain,
report the **verdict spread** across its child units; the single-verdict cell
belongs to the units. `🟠 Partial` is the one verdict that *is* legitimate for a
single unit — when that one story's acceptance criteria are themselves split.

**Status gates whether Missing is a defect or just roadmap.** A `🔴 Missing`
verdict means different things depending on the unit's tracker status (captured
in Phase 1):

- **Done (or no longer open) but Missing → true drift / defect.** The tracker
  says this shipped, yet the as-built spec has no such behavior. This is a real
  conformance failure and the priority signal of the audit.
- **Backlog / To Do / In Progress but Missing → unbuilt roadmap, expected, not
  drift.** The tracker hasn't claimed it exists yet. Report it as planned-not-yet-
  built, not as a failure — and don't file a `spec-drift` issue for it (it's
  normal backlog, belongs in feature speccing once any blocking decisions land).

Lead the report with the Done-but-Missing and Diverged findings; a tracker that
is mostly open work will be mostly expected-Missing, so don't let that volume
bury the few findings that are actual drift.

**The verdict emoji denotes *kind*, not *severity*.** Don't reuse `🔴` to flag a
"critical" Diverged finding — that collides with Missing. Convey severity in a
separate marker (e.g. a `[blocker]` tag or a severity column) so kind and
severity stay independent.

For many features this fans out cleanly (one reviewer per feature) — do that if
the comparison is large.

## Output — report + propose only

1. **Drift report.** Print it: a coverage table (tracker unit → **tracker status**
   → as-built feature → verdict), then a per-feature findings table (verdict +
   as-built evidence + one-line note). Include the status column so a reader can
   tell Done-but-Missing (defect) from Backlog-but-Missing (roadmap) at a glance.
   Offer to also write it to `/spec/DRIFT-REPORT.md` on a `feat/e22-drift` branch
   **only if the dev wants it tracked** — it's a point-in-time artifact, not part
   of the durable spine.
2. **Proposed resolution per finding**, following Rule 5 (spec-framework
   reference): reconcile the divergence by changing the code to match the tracker
   intent, **or** updating the spec/tracker to match the as-built reality (when
   the build is right and the tracker spec is stale). Note which path needs **PO**
   approval (user-facing behavior changed) vs. **dev** approval
   (internal/architectural).
3. **Open `spec-drift`-labelled issues** for findings that need a human decision,
   so drift becomes a tracked item rather than a quiet failure. Scope these to
   *actual* drift — Diverged, Done-but-Missing, and genuine conflicts — **not**
   expected-Missing backlog (those are unbuilt roadmap, not a decision to track).
   Each issue uses the **decision-checklist** body
   (`${CLAUDE_PLUGIN_ROOT}/templates/github/issue-bodies/spec-drift.md`): *Spec
   says* / *Implementation does* / *Evidence* / *Human decision required* (the
   checklist). The agent may propose a direction but **never resolves behavioural
   drift autonomously** — a PO or dev decides by ownership. On a GitHub tracker,
   hand this finding set to **`/e22-issues publish-drift`** (which routes through
   `/e22-tracker-sync`) to file them — idempotent, confirmed once — rather than
   opening them ad hoc; for other trackers, propose the issues for the dev to
   file.
4. **Make no code or spec edits, and don't commit.** This skill stops at the
   report and proposals. Ambiguities go to a proposed `## Open questions` entry
   in the owning feature's `intent.md` (or `vision.md` if cross-cutting), not a
   guess — run `/e22-questions` to drive them to answers.

## Coupling rules

The canonical spec ↔ code rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance, naming — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. Read it for the
full rules. This skill *detects and reports* drift; that reference governs how
it gets *resolved*.
