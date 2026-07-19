---
name: spec
description: "Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution WITHOUT writing any code; `clarify` sweeps the draft for gaps (edge cases, error paths, scope) before approval, `validate` checks the open-question contract plus intent/contract/tracker consistency. Ends at an approved intent, not a build."
when_to_use: >-
  Use to think a feature through before committing to implementation, shape
  acceptance criteria, or validate a spec's question state (/steer:spec
  validate). Works spec-only on an unmanaged repo (lite mode) — no bootstrap
  required.
argument-hint: "[feature-id | approve <feature-id> | clarify <feature-id> | validate [feature-id | --all]]"
---
<!-- steer:modes default,approve,clarify,validate -->

# Brainstorm a feature spec — no build

A **design-studio loop**: author and iterate a feature's spec and drive its open
questions to resolution, and **write no code at all**. This is the no-build
counterpart to `/steer:build` — it ends at an *approved intent*, not a running app.

It orchestrates the existing spec pieces behind one door: scaffold the spine
(`/steer:spec-scaffold` templates), brainstorm the intent, sweep open questions
(`/steer:questions` behavior), and optionally hand the result to
`/steer:tracker-sync` to file a tracker item — but it never crosses into
implementation.

## The defining guardrail — never builds

- **MUST NOT** create, edit, or delete anything under `/apps/**` or
  `/packages/**`, run build/test/dev tooling, or open a code PR. Writes are
  confined to `/spec/**` (the feature spine, `vision.md`, `decisions/`,
  `glossary.md`).
- If the user asks to "just build it" mid-session, **stop and point to
  `/steer:build` (PO-driven) or normal dev flow** — state the boundary out loud;
  don't silently comply. Brainstorming the spec and building it are separate
  sessions on purpose, so the intent can be reviewed before code exists.

## When to run

- Before committing to implementation, to think a feature through and pin its
  acceptance criteria.
- To refine an intent you plan to compare against the code later (`/steer:audit spec`).
- Whenever a feature needs design discussion but **not** code yet.

## Lite mode — an unmanaged repo is not a blocker

On a repo with **no `/spec` spine**, do **not** send the user through
`/steer:setup` first — thinking a feature through is the one activity
sanctioned without bootstrap. Proceed **spec-only**: run the steps below as
normal (`/steer:spec-scaffold` creates `spec/features/[id]/` and instantiates
the templates; no toolchain, scaffold, or full spine required), and say in one
line that you're working in lite mode. Two boundaries: product-level prose
that belongs in `vision.md` is parked in the feature's `## Open questions`
rather than scaffolding the spine ad hoc, and the never-builds guardrail is
unchanged. At close, surface **one** follow-up: `/steer:setup` graduates the
repo (spine, scaffold, toolchain) when the team is ready to build — a next
step, never a precondition for the spec work itself.

## Steps

1. **Identify the feature.** Ask for a short kebab-case `[id]` (e.g.
   `export-csv`, `user-login`). If `spec/features/[id]/` already exists,
   **resume** it — never clobber filled-in content; merge into it.
2. **Scaffold the feature.** Run `/steer:spec-scaffold [id]` — it instantiates
   `intent.md` (+ `contract.md`) from the bundled templates, copying them in for a
   new feature and reconciling additively against the current template for an
   existing one (its `template-reconcile.sh` branch), so nothing is hand-copied or
   clobbered. Whether `contract.md` earns its place is decided in step 6. For a
   design-originated feature, populate the `Design source` section per
   `/steer:reference design-sources`.
3. **Brainstorm the intent interactively.** Walk the PO/dev through, in plain
   user-facing language: the problem, who it's for, the user-visible outcome,
   and concrete **acceptance criteria**. Keep it stack-free — this is the *what
   and why*, not the *how*. Park anything unresolved under `## Open questions`;
   **never invent an answer**.
4. **Clarify — sweep the draft for gaps** (clarify mode, below) before
   presenting anything for approval: interrogate the draft against the gap
   classes and convert every real gap into a `Q-NNN` open question. This is
   where ambiguity becomes structured, answerable questions instead of
   surprises at implementation.
5. **Resolve open questions.** Run the `/steer:questions` read-then-propose loop on
   this feature: surface each question, propose options, fold the *confirmed*
   decision back into the spec, strike the question. Explicit deferral with a
   reason is a valid outcome. A question needing an external owner or scheduling
   → leave it open, to be filed as an issue via `/steer:issues` at step 7.
6. **Write `contract.md` only where it earns its place.** Add testable behavior
   rules / data / API surface **only** when they matter for behavior,
   integration, security, or future maintenance — not as ceremony. `intent.md`
   is the what/why (PO-facing); `contract.md` is the testable behavior + data/API
   surface (dev-owned).
7. **Approval gate — both exits stay code-free.** First **run `validate` on this
   feature** (below) — an approval **cannot proceed while a blocking question
   gated at `required_before: intent-approval` is unresolved** (the exact
   predicate lives in approve mode, below); resolve or explicitly reclassify it
   first. Then present the intent
   for PO approval. On PO approval, run **`approve <id>`** (below) to record the
   approval and flip `Status:` to `approved` in one change, then offer:
   - file it via `/steer:issues` (which routes through the tracker gateway) →
     create or refresh the tracker item from this intent, writing the ref back
     into the `> Tracker:` line.
   - hand off for implementation **in a separate session** — this skill stops
     here. In a GitHub-adopted repo (`tracker.md` → `system: github`),
     implementation runs through `/steer:work` (decompose via
     `/steer:issues` first); PO-driven builds go through
     `/steer:build` (which itself delegates to `work` once
     governed). Don't hand off to a "just implement it" path that skips the issue.
8. **Recommend the next action.** Close with a `## Recommended next actions` block
   per `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. Per the
   **locality rule**, consider only *this* feature's intent, open questions,
   contract, tracker state, and directly relevant ADRs — not the wider workspace.

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Open `impact: blocking` question on this feature | Blocking now | Resolve it — `/steer:questions` |
   | Intent drafted, not yet PO-approved | Human decision required | PO reviews & approves the intent (no command) |
   | Behavior demands a contract that isn't written | Required before initial production | Author `contract.md` |
   | Approved, tracker configured, not yet filed | Recommended | file it via `/steer:issues` |
   | Approved | Complete | Optional: implement in a separate session — `/steer:work` (after `/steer:issues decompose`) or `/steer:build` |

   Pick one `Current recommended action` by precedence; the block stays code-free,
   like the rest of this skill.

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

- ✗ an **approved** intent (`Status: approved`/`implemented`/`validated`/`live`)
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
(`materialize`, `status`, `reconcile`) and `/steer:audit spec` call this before acting.

## Approve mode — `/steer:spec approve <feature-id>`

<!-- steer:transition-owner feature-status:draft->approved -->

Records a PO's intent approval as a **structural, mechanically-checkable**
transition — never a free-form "looks good." This mode is the **single owner and
only writer** of the `draft → approved` transition; `/steer:issues
materialize` deliberately stops at `draft`. Other workflows (notably
`/steer:build`) **delegate** here after an explicit PO approval —
they invoke this operation but **must not reproduce its field-editing logic**
(the `## PO acceptance` checkboxes, `> Approved by:` / `> Approved at:`, the
`Status:` flip, or the HISTORY entry). An explicit PO statement authorizes Claude
to run this operation; the PO never has to know or type the slash command.

**Allowed transition — `draft → approved` only.** This is the spec side of the
`ready-for-dev` row of the Status↔state crosswalk (`ISSUE-WORKFLOW.md`): the
issue is the base source of truth and a feature's spec `Status:` is derived from
it. Approving here is the gate that lets the issue advance to `ready-for-dev`.

- Refuse on `implemented`, `validated`, or `live`: approval never downgrades or
  rewrites a feature past implementation — report the current state and stop,
  appending nothing.
- **Idempotent on `approved`** — if the feature is already `approved`, report the
  existing `> Approved by:` / `> Approved at:` and append **no** duplicate
  HISTORY entry.

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

**On a clean approval, in one change:**

1. Fill the intent header block — `> Approved by: @<po-handle>` and
   `> Approved at: <YYYY-MM-DD>` — and tick the `## PO acceptance` checkboxes (the
   human-facing mirror) with the `Approval comment/link:`.
2. Flip `> Status:` to `approved`.
3. Append **one** `/spec/HISTORY.md` entry (what / why / who-asked / refs).
4. Recommend the local next action — decompose into work
   (`/steer:issues decompose`, then execute each via
   `/steer:work`) or, for a PO-driven build,
   `/steer:build` (which delegates to `work` once governed) — per
   the `## Recommended next actions` block.

`approve` writes only under `/spec/**` (the intent header, PO-acceptance block,
and HISTORY); it stays as code-free as the rest of this skill.

## Relationship to neighbors

| Skill | Role |
|---|---|
| `/steer:spec` | author + iterate a feature spec, **no code** (this) |
| `/steer:spec-scaffold` | one-shot template instantiation (reused here) |
| `/steer:questions` | open-question sweep (behavior reused here) |
| `/steer:build` | spec **and** build, PO-driven, ends in a code PR |
| `/steer:tracker-sync` | file the intent as a tracker item (optional exit) |
| `/steer:audit spec` | *later*: compare this intent against the as-built code |

## Coupling rules

The canonical spec ↔ code rules — feature-organized specs, spec and code
changing together in the same PR, drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`. This skill stays
on the spec side of that boundary by design.
