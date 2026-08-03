---
name: questions
description: "Sweep the /spec spine's open questions, walk the PO/dev through each, fold decisions into the spec, promote what outlives the session to an issue, delete a legacy SPEC-QUESTIONS.md. bundle renders the PO-answerable ones as a fillable Artifact questionnaire (Markdown fallback)."
when_to_use: >-
  Use to work down accumulated open questions, before a release or PO-to-dev
  handoff, or to fold in answers ingested via /steer:intake clarify; use bundle
  mode to hand a Product Owner the open questions across every feature at once.
argument-hint: "[bundle [<feature-id>]]"
---

<!-- steer:modes default,bundle -->

# Resolve open questions (`/steer:questions`)

Open questions are the spine's quiet failure mode: written down once, gated at
PO acceptance, then left to rot. This skill gathers every open question across
the `/spec` spine, walks the PO/dev through each, and folds the decision back
into the spec — resolved **by tier** (step 6): an answer that **makes no new
decision** is folded straight back with the **PR as the gate**; a **genuine
decision the human hasn't made** — a product/policy/architecture call — is
routed to them (step 5) and applied only on a yes. It never *invents* a
decision; an unanswerable one stays open rather than being guessed.

## Modes

`default` (no argument): the **resolve** workflow — the steps below; a
**write** path. `bundle` (`bundle [<feature-id>]`): the **outbound** path —
render the PO-answerable open questions as a shareable, fillable questionnaire
for a Product Owner to answer offline; see [Bundle mode](#bundle-mode-bundle).

> **Dispatch `bundle` first — before step 1.** A `bundle` invocation renders
> and **stops** — it must **not** fall through into the default resolve flow,
> whose step-1 unconditional legacy delete would violate the read-only
> guarantee. Route on the argument at the very top; the **Read-only — a hard
> invariant** section in `BUNDLE.md` is the authoritative list of what bundle
> must not write.

## Where open questions live

There is **no `SPEC-QUESTIONS.md`** — questions live next to their context:

- **Per feature** → each `spec/features/*/intent.md` → `## Open questions`
  (the structured `### Q-NNN` blocks — `status` / `impact` / `owner` /
  `required_before` / `created` / `tracker`; the canonical format is in
  [`SPEC-FRAMEWORK.md`](../../templates/reference/SPEC-FRAMEWORK.md)).
- **Product-level** (anything not yet tied to one feature) → `spec/vision.md`
  → `## Open questions`.
- If present, `spec/PRODUCTIONIZATION.md` → `## Open questions` (dev-facing
  hardening ambiguities). **Honor its `> Lifecycle:` field:** when it is
  `published-snapshot`, the adoption-progress / gap-analysis **checkboxes are
  now tracked as issues** — historical evidence, not open work; only its
  `## Open questions` are still live here.

## When to run

Run it periodically to work the backlog down; before a **release** or a
**PO→dev handoff**, as a "nothing unanswered left to rot" gate; or whenever
a feature's `## Open questions` list has grown and nobody circled back.

A SessionStart hook (`check-open-questions.sh`) surfaces the backlog every
session so it can't quietly accumulate — this skill is how you clear that
nudge. The hook also **escalates a blocking question still open after 14 days**
(from its `created:` date, or the heading's `git blame` date when absent) with
its own loud line — the cue to promote it (step 6) or defer it (step 7).

That hook is **Claude Code only** — no other surface has a SessionStart channel
that can reach you, so nothing announces either the backlog or the 14-day
escalation there. Apply both yourself instead: read each feature's `## Open
questions` list, and age every blocking entry from its `created:` date (or the
heading's `git blame` date). Wherever a step below says "hook-escalated", read it
as "stale by that same test".

## Steps

1. **Heal a legacy `spec/SPEC-QUESTIONS.md` first — before you answer
   anything.** If that file exists (a fork from a pre-1.25.0 template revision),
   healing it is a **hard gate before gathering**: read
   [`LEGACY.md`](${CLAUDE_PLUGIN_ROOT}/skills/questions/LEGACY.md) §1 and apply
   it, then sweep the migrated copies below.

2. **Gather.** Collect every open question across the spine. Questions live in
   structured `### Q-NNN` blocks under `## Open questions` — sweep those, not
   checkboxes:

   ```sh
   grep -rn -A8 '^### Q-' spec/vision.md spec/features/*/intent.md \
     spec/PRODUCTIONIZATION.md 2>/dev/null
   ```

   The `-A8` window carries the whole field block — **don't read each owning
   file wholesale**; open just the specific `## Open questions` section when a
   block needs more. **In scope** are `status: open` and `status: investigating`;
   skip anything already `resolved` / `deferred` / `cancelled`, and skip any
   block still marked `<!-- steer:placeholder -->` (an unfilled scaffold seed —
   `check-open-questions.sh` ignores it for the same reason).

   **Legacy `- [ ]` checkboxes.** A spec predating the structured format may
   still carry plain `- [ ]` items inside `## Open questions`; those are in
   scope, but sweeping them safely has its own rules — and a `- [ ]` line
   **outside** that section is a **PO gate** that converting or resolving would
   destroy. The moment you see any, read
   [`LEGACY.md`](${CLAUDE_PLUGIN_ROOT}/skills/questions/LEGACY.md) §2 before
   touching them.

   **In a polyrepo member** (`spec/PRODUCT.md` present) all three of those paths
   are absent by design, so the grep returns nothing — that is **not** a clean
   sweep. Resolve the workspace (`workspace.path`, else the GitHub gateway) and
   run the sweep against its spine, reporting which repo you covered; if it is
   unreachable, say the spine is unreachable rather than reporting zero open
   questions (`/steer:reference polyrepo`).

3. **Present a worklist.** Print a consolidated table — **product-level
   (`vision.md`) first**, then per feature — with the source file and the
   question. Hook-escalated **stale** questions (blocking, open >14 days) jump
   the queue: promote (step 6) or defer (step 7). If there are none, say so
   and stop. Don't bury the list; this is the artifact the PO/dev acts on.

   **Stamp `created:` as you go.** Any question you newly raise gets
   `created: <today>`. A pre-existing question missing `created:` is left
   blank, *not* back-stamped to today — back-stamping would reset its clock
   and hide the rot; the hook ages it from `git blame` instead.

4. **Triage: code-fact vs human-decision (do this before any investigation).**
   In a reverse-engineered spec (`/steer:adopt`), most open questions are
   *factual questions about what the code already does* ("is `X` dead code?",
   "what roles exist?") — **not** decisions; asking the PO/dev what their own
   code does wastes a turn. Split the worklist into two buckets:
   - **Code-fact** — answerable by reading the code the question names. Ground
     it and propose a dev-sign-off answer (step 6).
   - **Human-decision** — genuine product / policy / roadmap / architecture
     calls (retention windows, pricing, consent). Route to a human (step 5).

   **Cost guardrail — this is where the skill gets expensive if you let it.**
   Ground code-facts the *cheap* way: targeted, inline reads of the file/symbol
   each question names, batched into one pass — one or two `grep`/`Read` calls
   per question, not a repo search.
   - Do **not** spawn an investigation agent per question or per subsystem — a
     fan-out of Explore agents over a 20-feature spec can burn hundreds of
     thousands of tokens to answer questions a handful of greps would settle.
   - Escalate to **at most one** bounded subagent for the *entire* batch, only
     if several questions genuinely need a broad cross-file search you can't do
     inline; give it the question list and have it return answers, not a tour.
   - If grounding a question would cost more than the answer is worth, leave it
     open and say so — an honest "unverified, needs a look" beats an expensive
     sweep.

5. **Route each human-decision to its owner.** Reuse the standard PO-vs-dev
   split: **product / behavior** ambiguities ("what should delete mean?") →
   ask the **PO** in plain language; **technical / architectural** ambiguities
   (data model, integration boundary, library choice) → ask the **dev**. Ask,
   don't invent; work through them oldest/most-blocking first.

6. **Fold each answer back into the spec — by tier** (rule `32-living-docs`:
   *applying a decision already made is not a new decision*).
   - **Auto-apply, no per-edit yes** — answers that decide nothing new: a
     **code-fact** grounded from the code (step 4), or a human-decision the
     PO/dev *just made* this session. Write the spec edit (plus any docs that
     must stay consistent — a `CLAUDE.md` one-liner, a superseding ADR) in the
     same change; the **PR is the gate** (rule `95-not-the-gate`).
   - **Ask first** — a genuine product/policy/architecture decision *not yet
     made*, or anything under **High-risk areas** (rule `60-high-risk`): never
     blind-write it; route it (step 5) and apply only once the human answers.
   - **Answer sourced from an ingested clarification doc** — a `Q-NNN` may
     carry a **`pending /steer:questions fold`** annotation from
     `/steer:intake clarify` (proposed answer + source-ref + quoted span — see
     [`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md)).
     The sweep surfaces it like any other open question; treat it as **the
     human's answer** under the **same tier gate above** — no lighter gate for
     arriving as a document. Intake records the annotation; only this skill
     writes the resolution.

   For each answered question:
   - Update the owning `intent.md` / `contract.md` (or `vision.md`) so the
     decision lives in the durable spec, not just the chat.
   - **Close the question in its `## Open questions` block** — set
     `status: resolved` and record the decision in its `_Resolution:_` line
     (the block stays, so its `Q-NNN` id keeps resolving from anything that
     cites it — a promoted issue, an ADR, a `pending fold` annotation). A
     legacy checkbox item is converted to a resolved `Q-NNN` block (step 2)
     rather than merely ticked.
   - **Code-fact answers** carry the grounding (`file:line`), marked
     **dev-sign-off** — confirmed at PR review, not decided now. User-facing
     answers reflect **PO** decisions, other technical answers **dev**
     decisions (spec-framework Rule 5); that sign-off is the PR.
   - **Doc-sourced answers** (from `/steer:intake clarify`) are folded with
     their **source-ref** and **exact quoted span** — as code-fact answers
     carry `file:line` — so a mis-mapped clarification is auditable and
     reversible at PR review, and closed like any other answered question.
   - A hard-to-reverse or cross-cutting answer → **`/steer:adr`**; propagating
     a decision *already made* into a superseding ADR is itself auto-apply.
   - A question that needs a **named owner, blocks multiple features, needs
     stakeholder/research input, or could outlive the session** → promote it to
     a tracker item (keep-vs-promote test: `ISSUE-WORKFLOW.md`). **A blocking
     question the hook flagged as stale (open >14 days) has, by that fact,
     outlived the session — promote it now.** Keep the structured `Q-NNN` in
     the spec and set its `tracker:` field to the ref — don't delete it; the
     issue carries the same id via `<!-- steer:question-id=Q-NNN -->`. On a
     GitHub tracker, **`/steer:issues`** (via `/steer:tracker-sync`) opens the
     `spec-question` issue; on other trackers, file per `/spec/tracker.md` and
     write the ref back. **Assign the owner** via the `owners:` map in
     `/spec/tracker.md` — the role→login rules (`shared` → both, blank →
     unassigned + `needs:triage`, never fabricate a login) are in
     `ISSUE-WORKFLOW.md`. **Reconciliation floor:** the promoted question
     carries its ref, and once its issue is answered/closed the decision is
     folded into the spec's normative prose — a closed issue with a
     still-`open` question is a validation failure (`/steer:spec validate`).

7. **Explicit deferral is a valid outcome.** If a question genuinely can't be
   answered yet, set its `status: deferred` and annotate **why** (and a revisit
   trigger) so it reads as a deliberate decision, not neglect — tracked, not
   rotting. `deferred` also drops it out of the next sweep and out of the
   SessionStart count, which is the point: a deferral you must re-triage every
   session is not a decision.

8. **Never guess a decision.** A human-decision the human can't answer stays
   open, unchanged — don't invent it. (Grounding a *code-fact* in the code is
   not guessing; that's step 4's cheap, correct move.)

## Done when

- A legacy `spec/SPEC-QUESTIONS.md` present at the start no longer exists (step 1).
- Every swept question ends in one of exactly three states — `status: resolved`
  with its decision recorded, `status: deferred` with an explicit reason and a
  revisit trigger, or **still `open`** because the human who owns it could not
  answer it yet (step 8). None silently dropped, none guessed.
  **Never stamp `deferred` on a question merely to close the sweep:** `deferred`
  drops out of the SessionStart count, so mislabelling an unanswered blocking
  question hides it from the one mechanism built to resurface it — while
  `/steer:spec approve` still refuses it. Leaving it `open` is the honest outcome.
- No legacy `- [ ]` item you resolved this run is left as a checkbox — it is a
  `### Q-NNN` block now (step 2).

## Recommend the next action

End with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, scoped to the
questions just swept (locality rule).

| Observed state | Category | Action / suggested command |
|---|---|---|
| Blocking question stale (open >14d), not promoted | Blocking now | Promote it — `/steer:issues` opens a `spec-question` issue assigned to its `owner` via the tracker.md map |
| Open question still `impact: blocking` | Blocking now | Route to its `owner` (product/dev/design/security) for a decision (no command) |
| Genuine unmade product/architecture decision left open | Human decision required | The owning human decides (no command) |
| All blocking questions resolved | Recommended | Re-check the spec gate — `/steer:spec validate` |
| Only non-blocking deferrals remain | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence.

## Bundle mode (`bundle`)

Renders every PO-answerable open question across the spine as one fillable
questionnaire (a Claude Artifact, Markdown fallback) so a Product Owner can
answer them offline in a single pass. Bundle itself **changes nothing in the
spec** — the filled return leg comes back through
`/steer:intake clarify <filled-doc>`, which maps each answer to its `Q-NNN`.
Read the procedure only when running this mode:
[`BUNDLE.md`](${CLAUDE_PLUGIN_ROOT}/skills/questions/BUNDLE.md).

## Coupling rules

The spec ↔ code coupling rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — are canonical in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`; that reference
governs how an answer this skill drives to a decision is folded into the spec.
