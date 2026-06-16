---
name: e22-next
description: "Read-only workspace navigator — reconstructs the whole E22 workspace state cold (branch/PR, /spec feature status, open questions, Proposed ADRs, tracker issues, work claims, version drift) and arbitrates the single best next action across all workflows using the shared categories + safety precedence. Never edits, commits, publishes, merges, or advances state; defers how to resolve each state to the owning skill."
when_to_use: Use when picking a repo up cold or mid-stream and asking "what should I do next?" across the whole workspace — when work spans more than one feature/issue/workflow and you need the one action that matters most right now, not a per-skill handoff.
---

# Navigate the workspace to the single best next action (read-only)

`/e22-standards:e22-next` reconstructs the **entire workspace state** as it stands right now —
independent of session memory — and arbitrates the **one action that matters
most** across *all* workflows. It is the cross-workflow counterpart to the
per-skill `## Recommended next actions` blocks: where each workflow skill is
**locality-bound** (it recommends only from its own invocation), `/e22-standards:e22-next` is
the only tool that sweeps unrelated workspace state and picks a single winner.

It changes **nothing**. It reconstructs, classifies, arbitrates, and recommends —
it never edits, commits, publishes, accepts an ADR, claims work, pushes a branch,
merges, or creates a PR. It also never *resolves* a state itself: it names the
owning skill (`/e22-standards:e22-work`, `/e22-standards:e22-spec`, `/e22-standards:e22-questions`, …) as the place that
does.

## The contract it reuses — do not restate it

The categories, two-level precedence, derivation rule, and read-only/locality
rules live in `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. Read
it first. This skill is the **cross-workflow arbitrator** that the locality rule
defers to; it owns one thing the per-skill blocks intentionally do not: a
workspace-wide reconstruction plus arbitration across *unrelated* state. It uses
the same categories and the same shared safety precedence — it does not fork
them, and it does not duplicate each skill's domain table.

## Relationship to the workflow skills — it routes, it doesn't run them

`/e22-standards:e22-next` recommends; the owning skill executes. It surfaces *that* a blocking
question gates feature A and names `/e22-standards:e22-questions`; it does not answer the
question. It flags a stale tracker state and names `/e22-standards:e22-work resume #N`; it does
not reconcile it. If the single best action is itself running a skill, say so as
a `Suggested command` — but the human still triggers it.

## When to run

- Resuming a repo cold (new session, new day) and unsure where things stand.
- Work spans several features/issues and you need to triage which to touch first.
- After a batch of merges, to find what the workspace now needs.
- Before a handoff, to surface the most urgent unresolved item across everything.

## Phase 0 — Locate the spine

If there is no `/spec` spine, there is nothing to reconstruct: the single
recommended action is to **bootstrap** — `/e22-standards:e22-init` (greenfield) or `/e22-standards:e22-adopt`
(existing "vibe-coded" code). Say which and stop. Don't run the rest.

## Phase 1 — Reconstruct workspace state (read-only)

Sweep each dimension and record what you find. Reuse the existing E22 state
vocabulary — never invent a parallel one. Read tools and `git`/`gh` reads only.

- **Git / branch / PR** — current branch (`feat/*`, `fix/*`, `main`), open PRs and
  their review state, CI status, and merge status (`git`, `gh pr`/`gh run` —
  read-only). Note a `main` checkout with no active branch.
- **Spec features** — for each `spec/features/<id>/intent.md`, read the
  frontmatter `> Status: draft | approved | implemented | validated | live`, and
  whether `contract.md` exists where behavior demands one.
- **Open questions** — sweep every `intent.md` and `spec/vision.md`
  `## Open questions` for `### Q-NNN` entries: `status:`,
  `impact: blocking | non-blocking`, `required_before:`
  (`intent-approval | contract-approval | implementation | non-prod-validation |
  production-release`), and `owner:`.
- **Proposed ADRs** — `spec/decisions/NNNN-*.md` with
  `- **Status:** Proposed` (awaiting ratification by its Deciders).
- **Tracker issues** — read `spec/tracker.md` `system:`. If `github`, query issue
  lifecycle state via `/e22-standards:e22-tracker-sync` (MCP-first, `gh` fallback): the
  `<!-- e22:state=... -->` marker
  (`inbox · exploring · ready-for-spec · ready-for-dev · in-progress · validate ·
  blocked · done · cancelled`). If `none-yet`/manual, reconstruct from spec + git only and
  **say so** — never invent tracker state.
- **Work claims** — detect in-progress work from `e22:state=in-progress` plus an
  `e22:branch=` / `e22:claimed-by=` marker, cross-checked against the live branch
  and PR. Flag the **merged-PR-but-stale-tracker** case (PR merged to `main`, issue
  still `validate`) — an unfinished lifecycle transition, not new work.
- **Version drift** — compare `spec/.version` against the current plugin version;
  a stale spine routes to `/e22-standards:e22-sync`.
- **Adoption brief** — if `spec/PRODUCTIONIZATION.md` exists, read its
  `> Lifecycle:`. `active-adoption` means an adoption is mid-flight (resume it);
  `published-snapshot` means its findings already live as issues (counted under
  the tracker dimension) — its checkboxes are **historical, not separate work**,
  so don't double-count them.
- **Recent context** — skim `spec/HISTORY.md` (newest first) only to orient; it is
  informational, not a source of actions.

State a dimension as **clean** or **not applicable** explicitly so silence never
reads as "nothing there."

## Phase 2 — Classify each observed state

Map every reconstructed state to exactly one of the categories using this
workspace-level table — `/e22-standards:e22-next`'s own domain (cross-workflow arbitration),
keyed by reconstruction dimension, derived from the same vocabulary. The
parenthetical is the shared safety-precedence level (NEXT-ACTIONS.md §2).

| Reconstructed state | Category (safety level) | Routes to |
|---|---|---|
| Committed secret / destructive-risk exposure observed | Blocking now (L1) | Rotate & invalidate; then `/security-review` (no command rotates it) |
| Live, deployed feature actively exposing data / breaching users / losing integrity | Urgent live-system remediation (L1) | Remediate the live system now; then `/security-review` (no command remediates it) |
| Open `impact: blocking` question gating its `required_before` gate | Blocking now (L2) | `/e22-standards:e22-questions` |
| Proposed ADR awaiting ratification | Human decision required (L3) | The Deciders ratify/reject (no command) |
| Intent `draft`, drafted but not PO-approved | Human decision required (L3) | PO approves (no command) |
| PR open, awaiting review / in `validate` | Human decision required (L3) | A reviewer reviews (no command) |
| Claimed issue mid-lifecycle (`in-progress` + branch), not yet at a PR | Blocking now — next transition (L4) | `/e22-standards:e22-work resume #N` |
| PR merged but issue still `validate` (stale tracker) | Blocking now — next transition (L4) | `/e22-standards:e22-work resume #N` |
| Spine bootstrapped, next lifecycle step ready (e.g. open a PR) | Blocking now — next transition (L4) | owning skill |
| Open question `required_before: production-release`, feature not yet live (non-blocking now) | Required before initial production (L5) | `/e22-standards:e22-questions` |
| Open question `required_before: production-release`, feature already `live` (non-blocking now) | Required before next production release (L5) | `/e22-standards:e22-questions` |
| `ready-for-dev` issue queued; optional findings to publish/shape; `.version` stale | Recommended (L6) | `/e22-standards:e22-work start #N`, `/e22-standards:e22-issues …`, `/e22-standards:e22-sync` |
| Every workflow settled across all dimensions | Complete — no action required (L7) | — |

When the same state could plausibly fit two categories, the **derivation rule**
decides: a question's `impact:` and `required_before:` separate *Blocking now*
from the release-timing categories, and the feature's `Status` (live vs not)
chooses between *Required before initial production* and *Required before next
production release*; an unmerged PR is *Human decision required*, never
*Complete*.

## Phase 3 — Arbitrate to one action

Collect every candidate from Phase 2 and apply the **shared safety precedence**
across all of them — regardless of which workflow each came from. Lower level
wins: a committed secret (L1) in one feature outranks a PR awaiting review (L3)
in another, which outranks a `ready-for-dev` issue (L6). Within a single level,
prefer the candidate that unblocks the most downstream work; if still tied,
order by feature/issue id for determinism and say a tie was broken. The result
is exactly one `Current recommended action`, or `No action is currently
required.`

## Phase 4 — Output

Emit, in order:

1. **State reconstruction summary** — a short, dimension-by-dimension readout of
   what you found (this is the navigator's value: it shows the basis for the
   recommendation). Mark clean / not-applicable dimensions explicitly.
2. **`## Recommended next actions`** — the standard block per NEXT-ACTIONS.md §5:
   the `###` category sections (omit empties), then `### Current recommended action`
   naming the single arbitrated action, with a `Suggested command:` line **only**
   when a real command performs it (human gates — PR review, PO approval, secret
   rotation, ADR ratification — get no command). Aggregate candidates across the
   whole workspace; each entry names its feature/issue so the source is clear.

Read-only coda: the block recommends; it does not act. `/e22-standards:e22-next` never edits,
commits, publishes, merges, or advances any workflow's state.

## Golden fixtures

`${CLAUDE_PLUGIN_ROOT}/templates/reference/next-fixtures/` pins the intended
**cross-workflow** arbitration as prose scenarios (not executable tests) — each
gives a multi-workflow `## Given` state and the single `## Expected
highest-priority action`. Walk the table above plus the shared safety precedence
by hand against each fixture to confirm the winner.
