# `/steer-audit spec` — as-built vs intended spec conformance

Read this file when running `spec` mode or the `spec` half of `all`. The
read-only contract, polyrepo scope note, and coupling rules stay in `SKILL.md` —
they apply to both modes and are not repeated here.

A **manual, read-only conformance audit.** It compares the **as-built spec**
(the `/spec` spine `/steer-adopt` reverse-engineered from the code — a faithful
description of what the product *actually does*) against the **tracker spec**
(what it was *supposed* to do, exported from the issue tracker as markdown) and
surfaces every place the two diverge. Its outputs are a drift report and a
proposed Rule-5 resolution per finding; anything needing a human decision is
*proposed* as a `spec-drift` issue, which **`/steer-issues publish-drift` files
as a separate step** — this mode writes nothing itself. Resolving drift is in
turn a separate, approved step (see the spec-framework reference, Rule 5).

**Boundaries.** `/steer-adopt` is the one-time bootstrap for an un-specced repo
— it reverse-engineers the as-built `/spec` from the code; the `spec` audit is
steady-state conformance that **consumes** that spine and diffs it against the
tracker intent. **If there is no `/spec` spine yet, stop and run `/steer-adopt`
first** — there is no as-built spec to compare against.

## When to run

- After landing a batch of work that spanned several epics/stories/issues, to
  confirm the build matches the combined intent.
- Periodically, to catch drift that accumulated across many small PRs.
- Before a release or handoff, as a conformance check against the tracker.

## Inputs

1. **The as-built `/spec` spine** — `features/*/intent.md` + `contract.md`,
   `decisions/*`, `vision.md`, `glossary.md`, as produced by a prior
   `/steer-adopt` run. This stands in for the code: its `contract.md` sections were
   *derived from the real code*. A contract's `## Implementation pointers` section
   is **optional and explicitly not a maintained index** — it may name an owning
   app/package, a file, or nothing at all — so never depend on it being there. If
   the spine itself is absent, redirect to `/steer-adopt` and stop.
2. **The tracker spec export** — markdown files from any issue tracker (Jira,
   Linear, GitHub Issues, …), **one file per epic/issue or per story / task**. A
   coarse-grained file (epic, large issue) contains several sub-items with their
   own acceptance criteria; a story/task/sub-issue file is a single unit. The dev
   either **pastes them into the chat** or **points to a directory/path**. Ask
   which, if not given.

   **If the tracker is GitHub Issues, offer `/steer-tracker-sync pull` instead of
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
intent**. Cite the as-built evidence — **the `contract.md` section** that captures
the behavior, named or quoted. That section is the required evidence; never assert
a match from the tracker spec alone.

**Do not require a `path:line` pointer.** If the contract's optional
`## Implementation pointers` section happens to carry an owning app/package or a
file, add it as corroboration — but a verdict is fully evidenced without it. That
section is a hint and "not a maintained index" (`SPEC-FRAMEWORK.md` rule 2), no
skill writes or maintains `path:line` values into it, so demanding one would make
every verdict unevidenceable. Where you genuinely need code-level confirmation and
no pointer exists, search the repo and cite what you find.

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

**Tracker state gates whether Missing is a defect or just roadmap.** A `🔴 Missing`
verdict means different things depending on the unit's tracker status (captured in
Phase 1). Read the issue `steer:state` directly — it is the only lifecycle store,
and the spec's `Status:` cannot answer "was this built?" (crosswalk in
`ISSUE-WORKFLOW.md`). Then read the gate below:

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

**Fan out on large comparisons.** This diff parallelizes cleanly — one reviewer
per feature. When the comparison is large (roughly **more than ~10 intended-behavior
units**, or any sweep where diffing every feature inline would crowd this context),
delegate **each feature's diff to the `steer-reviewer` subagent** (one per feature,
explicitly), handing it the intended-behavior unit, the as-built `/spec` feature
that owns it, and the verdict scale above; then gather the per-feature verdicts.
`steer-reviewer` is read-only by construction (`Read`/`Grep`/`Glob` only) — the
tracker pull stays here in the lead. Below that size, diff the features inline.

## Output — report + propose only

1. **Drift report.** Print it: a coverage table (tracker unit → **tracker status**
   → as-built feature → verdict), then a per-feature findings table (verdict +
   as-built evidence + one-line note). Include the status column so a reader can
   tell Done-but-Missing (defect) from Backlog-but-Missing (roadmap) at a glance.
   Offer to also write it to `/spec/DRIFT-REPORT.md`
   **only if the dev wants it tracked** — it's a point-in-time artifact, not part
   of the durable spine. Write it to the working tree only: this skill cannot
   branch or commit (no git write verb is granted and `EnterWorktree` is
   disallowed), so say plainly that committing it is the dev's next step.

   **Optionally publish it as a shareable drift board** — where the `Artifact`
   tool is available, **offer** a board of verdict-chipped cards (Done-but-Missing
   and Diverged first, tracker status preserved so defect-vs-roadmap reads at a
   glance): every chip is the verdict this run assigned, with its as-built
   evidence, and denotes *kind*, not severity. Unlike the code dashboard, the
   drift board is **never fillable**: each drift finding needs a per-finding human
   decision (its decision-checklist issue), not a bulk selection. The write is
   post-confirmation, per the read-only note in `SKILL.md`, to the temp path
   `steer-audit-drift-<short-sha>.html`; all rendering mechanics live in rule
   `88-artifacts` / `/steer-reference artifacts`.
2. **Proposed resolution per finding**, following Rule 5 (spec-framework
   reference): reconcile the divergence by changing the code to match the tracker
   intent, **or** updating the spec/tracker to match the as-built reality (when
   the build is right and the tracker spec is stale). Note which path needs **PO**
   approval (user-facing behavior changed) vs. **dev** approval
   (internal/architectural).
3. **Nominate `spec-drift`-kind issues** for findings that need a human
   decision, so drift becomes a tracked item rather than a quiet failure — this
   mode nominates, `/steer-issues publish-drift` files. Scope these to
   *actual* drift — Diverged, Done-but-Missing, and genuine conflicts — **not**
   expected-Missing backlog (those are unbuilt roadmap, not a decision to track).
   Each issue uses the **decision-checklist** body
   (`https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/github/issue-bodies/spec-drift.md`): *Spec
   says* / *Implementation does* / *Evidence* / *Human decision required* (the
   checklist). The agent may propose a direction but **never resolves behavioural
   drift autonomously** — a PO or dev decides by ownership. On a GitHub tracker,
   hand this finding set to **`/steer-issues publish-drift`** (which routes through
   `/steer-tracker-sync`) to file them — idempotent, confirmed once — rather than
   opening them ad hoc; for other trackers, propose the issues for the dev to
   file.
4. **Make no code or spec edits, and don't commit.** This mode stops at the
   report and proposals. Ambiguities go to a proposed `## Open questions` entry
   in the owning feature's `intent.md` (or `vision.md` if cross-cutting), not a
   guess — run `/steer-questions` to drive them to answers.
5. **Recommend the next action.** Close with a `## Recommended next actions` block
   per `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/NEXT-ACTIONS.md`, scoped to this
   drift run's findings (locality rule).

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Behavioural drift needing a human call | Human decision required | PO/dev decides by ownership (no command) |
   | Drift findings not yet filed (GitHub) | Recommended | `/steer-issues publish-drift` |
   | Ambiguities surfaced | Required before next production release | Resolve them — `/steer-questions` |
   | No actual drift (only expected-Missing backlog) | Complete | `No action is currently required.` |

   Choose one `Current recommended action` by precedence. Read-only — proposes,
   never edits or commits.
