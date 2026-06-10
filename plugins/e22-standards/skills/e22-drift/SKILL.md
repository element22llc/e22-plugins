---
name: e22-drift
description: Compare the as-built /spec (reverse-engineered from the code by /e22-adopt) against the intended spec exported from an issue tracker (Jira, Linear, GitHub Issues, … as markdown — one file per epic/issue or story/task) and surface every divergence. Use when asked to check a built app against its tracker specs, audit spec drift, or confirm the code did what the tickets asked. Read-only: reports findings and proposes Rule-5 resolutions, never edits.
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
3. **Don't invent detail the tracker spec doesn't state** — where a unit is
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
| 🔴 **Missing** | Tracker spec'd it, but the as-built spec (the code) has no such behavior — not built. |
| 🟡 **Unspecified** | As-built behavior with no backing tracker unit — built, but never asked for. |
| ❓ **Ambiguous** | One side too vague to judge; needs clarification. |

For many features this fans out cleanly (one reviewer per feature) — do that if
the comparison is large.

## Output — report + propose only

1. **Drift report.** Print it: a coverage table (tracker unit → as-built feature
   → verdict), then a per-feature findings table (verdict + as-built evidence +
   one-line note). Offer to also write it to `/spec/DRIFT-REPORT.md` on a
   `feat/e22-drift` branch **only if the dev wants it tracked** — it's a
   point-in-time artifact, not part of the durable spine.
2. **Proposed resolution per finding**, following Rule 5 (spec-framework
   reference): reconcile the divergence by changing the code to match the tracker
   intent, **or** updating the spec/tracker to match the as-built reality (when
   the build is right and the tracker spec is stale). Note which path needs **PO**
   approval (user-facing behavior changed) vs. **dev** approval
   (internal/architectural).
3. **Open `spec-drift`-labelled issues** for findings that need a human decision,
   so drift becomes a tracked item rather than a quiet failure.
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
