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
- **`/e22-issues` orchestrates; it never owns domain reasoning.** It delegates to
  `/e22-spec`, `/e22-audit`, `/e22-drift`, `/e22-questions`, and routes **all**
  GitHub read/write through `/e22-tracker-sync` (MCP-first → `gh` → manual floor).

## The lifecycle

1. **Capture** — a PO opens an issue from a form (feature / bug / product
   question / improvement). Incomplete ideas are fine. No `intent.md`, no
   feature-id, no architecture. Enters **Inbox**. (`/e22-issues capture` can also
   open one from a conversation, prototype, or screenshot.)
2. **Brainstorm** — `/e22-issues brainstorm #N` reads the issue and related
   specs, finds overlaps, asks focused questions, and maintains **one** editable
   "AI synthesis" comment (proposed outcome + boundaries). The issue body stays
   human-owned.
3. **Product validation** — the PO approves intent, answers questions, rejects
   assumptions, attaches design sources, in GitHub. Moves to **Ready for spec**.
4. **Materialize** — `/e22-issues materialize #N` writes/updates
   `spec/features/<id>/intent.md` with `Status: proposed`, links the issue, and
   requests PO approval. **Materialize never approves** — only an explicit
   `/e22-spec approve` flips `Status: approved`.
5. **Technical shaping** — `/e22-spec contract <id>`; large features become a
   parent feature issue with implementation sub-issues
   (`/e22-issues decompose #N`).
6. **Implementation & product validation** — PRs use closing refs
   (`Closes #131`, `Refs #123`, `Spec: …`). The parent closes only after
   **product** validation, not merely because the last code PR merged.

## State model (Project `Status` field)

`Inbox → Exploring → Ready for spec → Ready for dev → In progress → Validate → Done`

| Transition | Preconditions | Authority | AI may |
|---|---|---|---|
| Inbox → Exploring | Triaged, not a duplicate | PO | propose + perform |
| Exploring → Ready for spec | Product questions sufficiently answered | PO | propose only |
| Ready for spec → Ready for dev | Intent approved, **zero open blocking questions**, contract ready | PO + dev | propose only |
| Ready for dev → In progress | Work started | dev | propose + perform |
| In progress → Validate | Acceptance criteria implemented | dev | propose + perform |
| Validate → Done | Acceptance criteria **validated by PO** | PO | propose only |
| drift open → resolved | Spec or implementation intentionally reconciled | human (PO/dev per ownership) | propose only — **never auto-resolve** |

An AI may *perform* a transition only where the table says so; everywhere else it
proposes and waits for the named human.

## Labels (small, deliberate set — status/priority/effort live in the Project)

- **source:** `source:po` · `source:audit` · `source:spec-question` ·
  `source:spec-drift` · `source:operations`
- **needs:** `needs:triage` · `needs:product-decision` ·
  `needs:technical-decision` · `needs:spec` · `needs:validation`
- **risk:** `risk:high` · `risk:security` · `risk:data`

Issue **types** stay standard: Feature · Bug · Task. Do **not** encode status,
priority, effort, or release as labels — those are Project fields.

## Suggested Project (optional enrichment)

Projects are optional (org-level issue fields are public preview — don't depend
on them). When used, recommended fields: **Status** (the states above),
**Priority** (Urgent/High/Medium/Low), **Effort** (XS–XL), **Product area**,
**Spec state** (None/Proposed/Approved/Drifted), **Release**, **Owner type**
(Product/Development/Shared). Suggested views: PO inbox · Product exploration ·
Ready for specification · Developer-ready backlog · In progress · Awaiting PO
validation · Audit debt · Spec drift · High-risk changes. `/e22-issues` can
bootstrap these best-effort via `gh project`, degrading gracefully when absent.

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

- **Audit** (`/e22-audit` → `/e22-issues publish-audit`) uses a two-level model:
  one immutable **audit-run** record per run (`audit-id`) plus selected
  **finding** children keyed by a stable `finding-key` (the conceptual defect),
  with an `evidence` fingerprint tracking the *observed* lines separately. Re-runs
  reconcile: same key → update; gone → comment + close (auto-close only for
  `resolution_mode: deterministic`; judgment calls need a human yes); new →
  create; false positive → stays closed. Reconciling, never additive. See
  `ISSUE-SCHEMA.md` for the keys and `/e22-audit` for the full lifecycle.
- **Drift** (`/e22-drift` → `/e22-issues publish-drift`) files decision-checklist
  issues: `Spec says` / `Implementation does` / `Evidence` / `Human decision
  required`. The agent may propose a direction but **never resolves behavioural
  drift autonomously** — a PO or dev decides by ownership.
