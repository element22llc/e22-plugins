# `/steer:spec` — the clarify, validate, and approve modes

Read this file when running `clarify`, `validate`, or `approve`. The defining
guardrail (this skill never builds), lite mode, the default brainstorm steps,
and the coupling rules stay in `SKILL.md` and apply to every mode here.

## Clarify mode — `/steer:spec clarify <feature-id>`

A structured de-ambiguation sweep over one feature's draft, run before the
intent is presented for approval (step 4 of the default flow) or on demand.
It interrogates the draft against the classic gap classes and converts every
**real** gap into a structured `Q-NNN` open question — never loose prose, and
never an invented answer. Read-only against decisions: it raises questions;
answering them stays with the PO/dev (`/steer:questions`).

Sweep these gap classes against `intent.md` (and `contract.md` where present):

- **Edge cases** — empty states, zero/one/many, duplicates, concurrency,
  maximums the UX or data model implies but never states.
- **Error paths** — what the user sees when a step fails (network, validation,
  permission denied); silent failure is a gap.
- **Permissions & visibility** — who can do/see this; what a signed-out,
  unauthorized, or other-tenant user experiences.
- **Data lifecycle** — creation defaults, mutation rules, and what "delete"
  means here (the `## Lifecycle expectations` section's questions, asked
  concretely against this feature).
- **Non-functional constraints** — latency, volume, offline, accessibility,
  localization — only where the feature's nature makes one load-bearing.
- **Out-of-scope boundary** — anything a reasonable reader might assume is
  included that the PO hasn't ruled in or out; propose it for
  `## What is out of scope` as a question, not a silent addition.

For each gap: check it isn't already answered by the draft or an existing
question (dedupe by meaning, not wording), then add a `Q-NNN` with `status:
open`, a sensible `impact:` / `required_before:` (a gap that would change the
UX or data model is `blocking` at `intent-approval`; polish-class gaps gate
later), and `owner:`. Close by summarizing what was raised vs. already covered
— a draft that survives the sweep with nothing raised is a *finding worth
stating*, not a failed run.

## Validate mode — `/steer:spec validate [feature-id|--all]`

A **local, GitHub-independent** structural check over the open-question contract
(`SPEC-FRAMEWORK.md`): the defense-in-depth floor that holds even when the
tracker is unreachable. It is read-only — it reports failures and (with a yes)
proposes fixes; it never invents a decision. Given a `[feature-id]` it checks one
feature; `--all` sweeps every `intent.md` + `vision.md` in the spine.

Flag each of these, citing the `Q-NNN` and file:

- ✗ an **approved** intent (`Status: approved` or `live`)
  that still contains an `open` `blocking` question with
  `required_before: intent-approval` (later gates — `contract-approval`,
  `implementation`, … — block their own gate, not the already-granted approval);
- ✗ a `deferred` question missing `owner` or `required_before`;
- ✗ a `resolved` question with no resolution folded into the spec's normative
  prose (only a `_Resolution:_` line, or nothing);
- ⚠ a question with a `tracker:` ref whose issue is **closed** but whose
  `status:` is still `open` — the closed-issue / stale-spec trap;
- ✗ a **promoted** question (an open `spec-question` issue references its
  `question-id`) with no `tracker:` ref back;
- ✗ a `created:` field present but not a well-formed `YYYY-MM-DD` date (the
  staleness clock can't read it);
- ⚠ a `blocking` question open past the staleness threshold (14 days from
  `created:`) with no `tracker:` ref — not yet promoted. This **warns**, it does
  not block: it mirrors the SessionStart hook's escalation, nudging you to
  promote (assign its owner via the tracker.md map) or defer with a reason.

**Cross-artifact analyze checks** — the pre-implementation consistency pass
(intent ↔ contract ↔ tracker), run in the same sweep. All warnings (⚠): each
is a judgment call the human resolves, never a mechanical block:

- ⚠ an acceptance criterion with no corresponding `contract.md` behavior where
  a contract exists — the criterion can't be reviewed against anything
  testable;
- ⚠ a `contract.md` behavior no acceptance criterion asks for — scope arrived
  in the contract without the PO's intent naming it (drift at birth);
- ⚠ the linked tracker item (`> Tracker:` ref, read via `/steer:tracker-sync`
  when available) carries acceptance criteria or scope the intent doesn't —
  the copy-into-intent rule (`tracker.md` template) was skipped;
- ⚠ an acceptance criterion failing the quality bar in the intent template's
  `## Acceptance criteria` guidance — not **testable** (no yes/no outcome),
  not **observable** (phrased as implementation), or not **bounded** (silent
  on the edge behavior the feature obviously has). Cite the criterion and say
  which property fails.

The closed-issue check needs the tracker; when GitHub is unavailable, run the
GitHub-independent checks and **say** the tracker-coupled ones were skipped —
silence must never read as "passed." A failing check **blocks the relevant gate**
(approval, `/steer:issues materialize`, a spec-changing PR). `/steer:issues`
(`materialize`, `status`, `reconcile`) calls this before acting.

## Approve mode — `/steer:spec approve <feature-id>`

<!-- steer:transition-owner feature-status:draft->approved -->

Records a PO's intent approval as a **structural, mechanically-checkable**
transition — never a free-form "looks good." This mode is the **single owner and
only writer** of the `draft → approved` transition; `/steer:issues
materialize` deliberately stops at `draft`. Other workflows (notably
`/steer:build`) **delegate** here after an explicit PO approval —
they invoke this operation but **must not reproduce its field-editing logic**
(the `## PO acceptance` checkboxes, `> Approved by:` / `> Approved at:`, the
`Status:` flip, or the history entry). An explicit PO statement authorizes Claude
to run this operation; the PO never has to know or type the slash command.

**Allowed transition — `draft → approved` only.** This is the spec side of the
`ready-for-dev` row of the Status↔state crosswalk (`ISSUE-WORKFLOW.md`): the issue
is the single lifecycle store, and `Status:` records only the PO's scope approval —
which is exactly what this mode writes. Approving here is the gate that lets the
issue advance to `ready-for-dev`.

- Refuse on `live`: approval never downgrades or rewrites a released feature —
  report the current state and stop, appending nothing.
- **Delivery state is never a reason to refuse, and never a thing to write.**
  Whether the issue is `in-progress`, `validate`, or `done` does not gate this
  approval and does not appear in `Status:`; approving a feature already being
  built is legitimate (a late scope sign-off) and touches the spec only.
- **Idempotent on `approved`** — if the feature is already `approved`, report the
  existing `> Approved by:` / `> Approved at:` and append **no** duplicate
  history entry.

**Blocking-question gate (exact predicate).** Refuse the approval **iff** there
exists a question with **all** of:

- `impact: blocking`, **and**
- `required_before: intent-approval`, **and**
- `status` ∈ the unresolved set `{open, investigating, deferred}`.

A blocking-but-`deferred` question **still blocks** intent approval until its
`impact:` is explicitly reclassified `non-blocking` — deferral is not resolution.
Questions gated only at `contract-approval`, `implementation`,
`non-prod-validation`, or `production-release` do **not** block intent approval
(they block their own later gate). Run `validate` first so the closed-issue /
stale-spec checks fire too.

**Offer the approval in-session — don't end on a dead `draft`.** Once the
preconditions above hold (no refusal, no unresolved blocking question), present the
tradeoff to the PO and ask: **Approve · Reject · Decide later** (rule
`61-gate-prompts`; full protocol `/steer:reference gates`). The prompt shows the
**acceptance criteria**, the **locked scope — in and out**, and any non-blocking
open questions that survive approval. `Decide later` leaves the intent `draft`
exactly as today; `Reject` records the reason in `intent.md`. Never pre-select
`Approve`, and never read ambient agreement as approval.

**Order matters: preconditions first, prompt second.** If the blocking-question
gate above fails, do **not** show the prompt at all — route to `/steer:questions`.
Never present a gate the human cannot legitimately pass.

If the PO is not the person in the session, surface that and leave the state alone
— you may not record their approval for them.

**On a clean approval, in one change:**

1. Fill the intent header block — `> Approved by: @<po-handle>` and
   `> Approved at: <YYYY-MM-DD>` — and tick the `## PO acceptance` checkboxes (the
   human-facing mirror) with the `Approval comment/link:`. When the approval was
   given in-session rather than in an offline review, say so in the
   `Approval comment/link:` so the channel is part of the record.
2. Flip `> Status:` to `approved`.
3. Write **one** `/spec/history/` entry file (what / why / who-asked / refs) —
   in a member, to the workspace's ledger per rule `32-living-docs`.
4. Recommend the local next action — decompose into work
   (`/steer:issues decompose`, then execute each via
   `/steer:work`) or, for a PO-driven build,
   `/steer:build` (which delegates to `work` once governed) — per
   the `## Recommended next actions` block.

`approve` writes only under `/spec/**` (the intent header, PO-acceptance block,
and the history entry); it stays as code-free as the rest of this skill.
