# Issue lifecycle — GitHub Issues as the work, decision, and collaboration layer

How a product idea travels from a PO's rough capture to validated, shipped work
**without losing open questions, overwriting human content, or letting the spec
and the tracker silently disagree**. This is the normative owner of the
lifecycle, its state model, label taxonomy, and authority rules. The issue
*format* lives in [`ISSUE-SCHEMA.md`](ISSUE-SCHEMA.md); the open-question format
lives in [`spec-framework.md`](spec-framework.md).

Two invariants underpin everything:

- **`/spec` is durable product truth; GitHub Issues is the work/decision layer.**
  An issue is the *workflow* for reaching a decision; the spec (or an ADR) is the
  durable *record* of it. Neither silently overwrites the other.
- **`/e22-standards:e22-issues` orchestrates backlog management; `/e22-standards:e22-work` owns execution.**
  Neither owns domain reasoning — they delegate to `/e22-standards:e22-spec`, `/e22-standards:e22-audit`,
  `/e22-standards:e22-drift`, `/e22-standards:e22-questions`. All **tracker-metadata** read/write flows
  through `/e22-standards:e22-tracker-sync` (MCP-first → `gh` → manual floor); git and
  pull-request **delivery** follows the repo's execution/autonomy rules — it is
  not a gateway operation (otherwise `git push` would violate the invariant).

## Operating model (local-first, issue-first)

1. **Local interactive Claude Code is the primary worker.** Unattended GitHub
   Actions execution is out of scope and would require a separate explicit signal.
2. **Every repository mutation has a GitHub issue first** — in a GitHub-adopted
   repo (`/spec/tracker.md` → `system: github`), reuse the issue the user names
   or create one before the first code/config/infra/behavior change.
3. **Explicit capture/implementation requests create issues without confirmation**
   ("create an issue for…", "add to the backlog", "fix this bug", "implement
   #123"). Ambiguous conversation that did not request capture does **not**
   auto-create; a large inferred batch of unrelated issues takes one confirmation;
   security-sensitive public disclosure takes human review.
4. **A CLI implement request authorizes a bounded action set** — read/search,
   create-or-reuse issue, claim, branch, local edits, run tests. Commit, push,
   PR open/update follow existing commit/PR-autonomy rules; **merge and deploy
   are never implied.**
5. **Base lifecycle state is the `e22:state` marker** (see State model); a
   Project field mirrors it when Projects are enabled. Projects are optional
   visualization, never a dependency.
6. **Taxonomy is three orthogonal axes** — GitHub Issue **Type** × `e22:kind`
   (work shape) × `source:*` (origin). The `e22:source` marker is canonical; the
   label is derived. See the table in [`ISSUE-SCHEMA.md`](ISSUE-SCHEMA.md).
7. **Original human Issue-Form content is immutable** — agents append a managed
   block, never rewrite form responses (see `ISSUE-SCHEMA.md`).

### Authorization & confirmation

The **single authority** for *when an agent acts without asking* vs *when it
confirms first*. Skills and hooks **reference this block; none restates it.**

- **Explicit implement / capture request → no extra confirmation.** "fix #123",
  "implement this", "create an issue for…" authorize find-or-create plus the
  bounded action set (principle 4) with no second ask.
- **Bulk publish of audit / drift / adoption findings → one batch confirmation.**
  Filing many issues from one report (`publish-audit` / `publish-drift` /
  `publish-adoption`) takes a single confirmation for the whole batch, then
  proceeds.
- **Unsolicited idea / capture-only language → confirm before any external
  publish.** "we should eventually…" is captured deliberately, never inferred
  into issues; security-sensitive public disclosure takes human review.
- **Managed-block update inside an already-authorized workflow → no repeated
  confirmation.** Rewriting the `e22:managed` block (progress, state) needs no
  further ask; human content stays immutable (principle 7).
- **State transitions** obey the authority table below; wherever it does not
  permit *perform*, the agent **proposes and waits** for the named human, and
  never resolves behavioural drift or a product/policy decision autonomously.

## The lifecycle

1. **Capture** — a PO opens an issue from a form (feature / bug / product
   question / improvement). Incomplete ideas are fine. No `intent.md`, no
   feature-id, no architecture. Enters `inbox`. (`/e22-standards:e22-issues capture` can also
   open one from a conversation, prototype, or screenshot.)
2. **Brainstorm** — `/e22-standards:e22-issues brainstorm #N` reads the issue and related
   specs, finds overlaps, asks focused questions, and maintains **one** editable
   "AI synthesis" comment (proposed outcome + boundaries). The issue body stays
   human-owned.
3. **Product validation** — the PO approves intent, answers questions, rejects
   assumptions, attaches design sources, in GitHub. Moves to `ready-for-spec`.
4. **Materialize** — `/e22-standards:e22-issues materialize #N` writes/updates
   `spec/features/<id>/intent.md` with `Status: draft`, links the issue, and
   requests PO approval. **Materialize never approves** — only an explicit
   `/e22-standards:e22-spec approve` flips `Status: approved`.
5. **Technical shaping** — `/e22-standards:e22-spec` authors the feature's
   `contract.md` where behavior demands it; large features become a
   parent feature issue with implementation sub-issues
   (`/e22-standards:e22-issues decompose #N`).
6. **Implementation & product validation** — PRs use closing refs
   (`Closes #131`, `Refs #123`, `Spec: …`). The parent closes only after
   **product** validation, not merely because the last code PR merged.

## State model (base = `e22:state` marker)

The **base source of truth is the `e22:state` issue-body marker**; a Project
`Status` field *mirrors* it when Projects are enabled (never the other way). The
closed enum (no standalone `ready`):

`inbox · exploring · ready-for-spec · ready-for-dev · in-progress · validate · blocked · done · cancelled`

`done` and `cancelled` are the two terminal states, and **which one a closed
issue lands in is decided by its closure reason, not by the mere fact of
closure** (see Completion rules).

Readiness and transitions differ **by kind** — the feature flow is the long
path; smaller work skips the spec gates:

- **Feature:** `inbox → exploring → ready-for-spec → ready-for-dev → in-progress → validate → done`
- **Bug / task:** `inbox → ready-for-dev → in-progress → validate → done` — allowed
  to start directly when expected behavior is clear, evidence/repro exists, the
  user requested implementation, and no unresolved product decision exists.
- **Deterministic finding** (audit/adoption): `inbox → ready-for-dev → in-progress → validate → done`
  — auto-advance to `ready-for-dev` only when remediation is deterministic and
  does not change product intent.
- **Question / drift:** `inbox → exploring → ready-for-spec → [human decision] → ready-for-dev → …`
  — cannot become implementation-ready until a human resolves the intended behavior.

| Transition | Preconditions | Authority | AI may |
|---|---|---|---|
| inbox → exploring | Triaged, not a duplicate (feature path) | PO | propose + perform |
| exploring → ready-for-spec | Product questions sufficiently answered | PO | propose only |
| ready-for-spec → ready-for-dev | Intent approved, **zero open blocking questions**, contract ready | PO + dev | propose only |
| inbox → ready-for-dev | Bug/task/deterministic finding meets its readiness rule above | dev | propose + perform |
| ready-for-dev → in-progress | Work claimed and started | dev | propose + perform |
| in-progress → validate | Acceptance criteria implemented; **PR opened** | dev | propose + perform |
| validate → done | Acceptance criteria **validated** AND closure reason = `completed` (PR merged & accepted) | PO/dev per kind | propose only (features: PO) |
| any state → cancelled | Closed for a non-completion reason (`rejected` / `duplicate` / `obsolete` / `not-planned` / `superseded`) | PO/dev per kind | propose + perform |
| any non-terminal → blocked | Work cannot proceed | dev | propose + perform |
| blocked → previous | Blocker resolved | dev | propose + perform (returns to the prior meaningful state) |
| drift open → resolved | Spec or implementation intentionally reconciled | human (PO/dev) | propose only — **never auto-resolve** |

Completion rules: **opening a PR moves the issue to `validate`, never `done`.**
**Closure reason — not the mere fact of closure — decides the terminal state:**

- Closed as **`completed`** (the work was delivered: PR merged & the acceptance
  criteria accepted) → `done`.
- Closed as **`rejected` / `duplicate` / `obsolete` / `not-planned` /
  `superseded`** → **`cancelled`**, never `done`. Record a replacement pointer
  where one applies (a `duplicate`/`superseded` issue points at its replacement).
  `cancelled` work was **not** delivered, so it must never count toward
  done/throughput or read as a satisfied acceptance.

A PR closed without merge returns the issue to `in-progress` or `blocked` (the
issue itself is not closed). A reopened issue moves `done|cancelled →
inbox|exploring|ready-for-dev` after reassessment. `/e22-standards:e22-work status|resume|finish`
reconciles stale markers on the next interaction — and **inspects the closure
reason before transitioning a closed issue**, keeping merge state as independent
evidence. An AI may *perform* a transition only where the table says so;
everywhere else it proposes and waits for the named human.

## Labels (small, deliberate set — status/priority/effort live in the Project)

- **source:** mirrors the canonical `e22:source` marker (label is *derived*) —
  `source:human` · `source:adoption` · `source:audit` · `source:security-review`
  · `source:code-review` · `source:ci` · `source:dependency` ·
  `source:implementation` · `source:spec`.
- **needs:** `needs:triage` · `needs:product-decision` ·
  `needs:technical-decision` · `needs:spec` · `needs:validation`
- **risk:** `risk:high` · `risk:security` · `risk:data`

Do **not** encode status, priority, effort, release, or **kind** as labels —
state is the `e22:state` marker (mirrored by the Project), priority/effort are
Project fields, and kind is the `e22:kind` marker + GitHub Issue Type.

**Issue Types — capability-degrading.** The standard org Types are
`Feature · Bug · Task`, but Issue Types are an **org-level** feature whose
defaults can be renamed, disabled, or deleted, and Issue Forms remain a GitHub
public preview. So:

- **Type available** → set the configured Type (per the Type×kind×source table in
  `ISSUE-SCHEMA.md`) **and** keep `e22:kind` as the E22 contract.
- **Type unavailable/unknown** → continue on `e22:kind` alone, emit a
  non-blocking capability warning, and **do not** reintroduce duplicate
  `bug`/`feature` labels to compensate.

## CI failures — when to file

Not every red build is an issue. To avoid both lost signal and duplicate noise:

- **Transient failure** (flake on retry, infra blip) → no issue.
- **Reproducible failure on the default branch** → create/reconcile a `bug` with
  `source:ci` (stable `finding-key` so repeat failures reconcile, not duplicate).
- **Recurring flaky test** → one issue keyed by a stable `finding-key`; reconcile
  each recurrence rather than opening a new one.
- **PR-specific failure** → comment on the PR; only file an issue if it outlives
  that PR (lands on the default branch).

## Suggested Project (optional enrichment)

Projects are optional (org-level issue fields are public preview — don't depend
on them). When used, the **Status** field *mirrors* the `e22:state` marker (the
marker is the base source of truth, never the reverse). Other recommended
fields: **Priority** (Urgent/High/Medium/Low), **Effort** (XS–XL), **Product
area**, **Spec state** (None/Proposed/Approved/Drifted), **Release**, **Owner
type** (Product/Development/Shared). Suggested views: PO inbox · Product
exploration · Ready for specification · Developer-ready backlog · In progress ·
Awaiting PO validation · Audit debt · Spec drift · High-risk changes.
`/e22-standards:e22-issues project bootstrap` can create/reconcile **fields and options**
best-effort via `gh project`, degrading gracefully when absent — but `gh`
exposes **no API to create saved views**, so it outputs manual view-creation
instructions rather than claiming to have made them.

## Spec questions — keep vs promote

A question stays in the spec's `## Open questions` (structured `Q-NNN`, see
[`spec-framework.md`](spec-framework.md)) when it is local to one feature,
answerable during active specification, not separately scheduled, and not blocked
on an external party. **Promote it to a `source:spec-question` issue** when it
needs a named owner, blocks multiple features, requires stakeholder consultation
or research, must be prioritized independently, or could outlive the current
session. On resolution: update the canonical spec, record the decision on the
issue, close it, and record an ADR **only** when the decision is architectural or
hard to reverse. The issue is the decision *workflow*; the spec/ADR is the
durable *record*.

## Audit & drift (reconciling, not additive)

- **Audit** (`/e22-standards:e22-audit` → `/e22-standards:e22-issues publish-audit`) uses a two-level model:
  one immutable **audit-run** record per run (`audit-id`) plus selected
  **finding** children keyed by a stable `finding-key` (the conceptual defect),
  with an `evidence` fingerprint tracking the *observed* lines separately. Re-runs
  reconcile: same key → update; gone → comment + close (auto-close only for
  `resolution_mode: deterministic`; judgment calls need a human yes); new →
  create; false positive → stays closed. Reconciling, never additive. See
  `ISSUE-SCHEMA.md` for the keys and `/e22-standards:e22-audit` for the full lifecycle.
- **Drift** (`/e22-standards:e22-drift` → `/e22-standards:e22-issues publish-drift`) files decision-checklist
  issues: `Spec says` / `Implementation does` / `Evidence` / `Human decision
  required`. The agent may propose a direction but **never resolves behavioural
  drift autonomously** — a PO or dev decides by ownership.
