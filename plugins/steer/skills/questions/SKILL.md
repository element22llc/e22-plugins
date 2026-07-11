---
name: questions
description: Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec. In bundle mode, render the PO-answerable open questions across the whole spine as a shareable, fillable Claude Code Artifact (with a Markdown fallback) so a Product Owner with no repo or Claude Code access can answer them in a browser and send the result back through /steer:intake clarify.
when_to_use: Use to work down accumulated open questions, before a release or PO→dev handoff, or when asked to resolve or review open questions — including when a client clarification document ingested via /steer:intake clarify supplies answers to fold in. Use bundle mode when you need to hand a Product Owner the open questions to answer offline — it produces a fillable questionnaire (Artifact or Markdown) covering every feature at once.
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
> guarantee. Route on the argument at the very top; the **Read-only**
> invariant below is the authoritative list of what bundle must not write.

## Where open questions live

There is **no `SPEC-QUESTIONS.md`** — questions live next to their context:

- **Per feature** → each `spec/features/*/intent.md` → `## Open questions`
  (the `- [ ]` items).
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

## Steps

1. **Heal a legacy `spec/SPEC-QUESTIONS.md` first — before you answer
   anything.** Legacy format: a fork from an older template revision
   (pre-1.25.0) may still carry the retired standalone file; its heal is the
   **v1.25.0 migration entry** in
   [`MIGRATIONS.md`](../../templates/reference/MIGRATIONS.md), applied as a
   **hard gate** before gathering — migrate the questions into the spine and
   **delete the file in this same step** (a move, not an answer; the deletion
   never waits on answers), then sweep the migrated copies below.

2. **Gather.** Collect every open question across the spine. A grep over the
   `## Open questions` sections finds them — for example:

   ```sh
   grep -rn -A20 '^## Open questions' spec/vision.md spec/features/*/intent.md \
     spec/PRODUCTIONIZATION.md 2>/dev/null | grep -E '^\S+:[0-9]+[:-]- \[ \]'
   ```

   The grep's `-A20` window is usually enough context — **don't read each
   owning file wholesale**; open just the specific `## Open questions` section
   when a bullet needs more. Skip items already resolved (`- [x]`) or
   annotated as a deliberate deferral.

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
   - **Strike the question from its `## Open questions` list** — `- [x]` with
     the decision, or remove it once captured elsewhere in the spec.
   - **Code-fact answers** carry the grounding (`file:line`), marked
     **dev-sign-off** — confirmed at PR review, not decided now. User-facing
     answers reflect **PO** decisions, other technical answers **dev**
     decisions (spec-framework Rule 5); that sign-off is the PR.
   - **Doc-sourced answers** (from `/steer:intake clarify`) are folded with
     their **source-ref** and **exact quoted span** — as code-fact answers
     carry `file:line` — so a mis-mapped clarification is auditable and
     reversible at PR review, and struck like any other answered question.
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
   answered yet, keep the item but annotate **why** (and a revisit trigger) so
   it reads as a deliberate decision, not neglect — tracked, not rotting.

8. **Never guess a decision.** A human-decision the human can't answer stays
   open, unchanged — don't invent it. (Grounding a *code-fact* in the code is
   not guessing; that's step 4's cheap, correct move.)

## Done when

- A legacy `spec/SPEC-QUESTIONS.md` present at the start no longer exists (step 1).
- Every swept question is struck with its decision or left open with an
  explicit deferral reason — none silently dropped or guessed.

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

`/steer:questions bundle [<feature-id>]` renders the open questions **a Product
Owner can answer** as a shareable, fillable questionnaire — the **outbound**
half of the PO clarification loop. The loop, the machine-keyed return document
the page exports, and how `/steer:intake clarify` ingests the filled export are
canonical in
[`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md).
**By default it bundles the whole spine — every feature at once** plus
product-level questions; `bundle <feature-id>` narrows to one feature.

### Read-only — a hard invariant (not tool-enforced here, so honor it in prose)

This mode lives in a skill whose default path *writes and deletes* spec files,
so — unlike frontmatter-read-only `/steer:explain` — its tools can't be locked
down; the read-only guarantee is **behavioral, and you must uphold it**. Bundle
**writes nothing under the repo tree**: no legacy heal/delete (step 1), no
`created:` stamping (step 3), no `git add`/commit, no edit to any spec file.
Its **one** write is the Artifact's HTML source, to a **system temp
directory**, never a path under the working tree; it runs **no shell** and
touches the tracker not at all — gathering uses read-only `Glob` / `Read` /
`Grep` only.

### Flow

1. **Locate the spine.** No `/spec` → redirect to `/steer:setup` (or
   `/steer:init` / `/steer:adopt`) and **stop**. No argument = the **whole
   spine, every feature**; an unknown or ambiguous `<feature-id>` → list the
   features under `spec/features/*/` and ask which, never guess.

2. **Gather.** Collect the **same open questions the default flow's
   [step-2 sweep](#steps) identifies** — using the read-only `Grep`/`Read`
   tools only (step 2's `grep | grep` pipeline is an illustration; reproduce
   its result without running shell). Read each item's **structured fields** —
   `status`, `impact`, `owner` — not just the `- [ ]` line. A legacy
   `spec/SPEC-QUESTIONS.md` (step 1) is included **read-only**, never silently
   omitted: `Read` its `## Open` items into the gather scoped `[product]`,
   never migrate or delete it here, and add a notice to run the default
   `/steer:questions` first so it gets healed.

3. **Filter to what the PO can answer.** A bundle carries the questions a
   **Product Owner** can decide — not pure dev/technical work:
   - **Audience.** Include what the PO owns or co-owns: `owner:` **`product`**
     and **`shared`** (the PO owns a half), plus **`design`** / **`security`**
     questions that are product / policy / scope / UX calls. **Exclude**
     *code-fact* questions (the [step-4 triage](#steps) — asking a PO what
     their own code does is a wasted turn) and questions owned solely by
     **`development`**. Report the excluded count, split code-fact vs dev, so
     nothing looks silently dropped and a `shared`/`design`/`security`
     question is never miscounted as "dev-only".
   - **Status.** Solicit only `open` / `investigating`; **exclude `deferred`**
     — re-soliciting a deliberate parking (step 7) re-opens a closed decision.
     Show deferred items read-only "for context" at most, never as a fillable
     field.
   - **Blocking first.** Order `impact: blocking` first and flag it; surface
     any the hook escalated as **stale** — exactly what to push to the PO.
   - **Nothing to ask** → say so, name the excluded / deferred counts, and
     **stop**. Don't render an empty form.

4. **Render — Artifact when available.** Render by the **shared Artifact
   discipline** — rule `88-artifacts`, mechanics in `/steer:reference artifacts`
   ([`ARTIFACTS.md`](../../templates/reference/ARTIFACTS.md)), including the
   **copy-out floor** a fillable page must uphold and its
   progressive-enhancement copy/download controls — do not restate them here.
   The temp path is `<tempdir>/steer-questions-bundle[-<feature-id>].html`.
   The page carries one labelled **`<textarea>` per question**, grouped
   **product-level first, then per feature**, blocking questions visibly
   flagged; each carries its **feature-scoped key `[<feature-id>] Q-NNN`** and
   the question's context, verbatim from the spec.

5. **Markdown fallback.** Where the Artifact tool is unavailable, print the
   **same fillable return-document Markdown inline** — never to a file under
   the repo — per `ARTIFACTS.md`'s fallback rules, saying plainly why the
   hosted artifact isn't available so it isn't mistaken for a failure.

The copy-box, the "Download .md" export, and the Markdown fallback all emit the
**same machine-keyed return document**; its exact shape, the
`[<feature-id>] Q-NNN` key rules, and stale-key handling are the
return-document contract in
[`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md).

### Recommended next action

Close with a `## Recommended next actions` block: the one best step is to
**send the questionnaire to the PO** and, when the filled document returns,
**absorb it with `/steer:intake clarify <filled-doc>`**, which maps each answer
back to its `Q-NNN` and routes it here to fold in. Bundle itself changes
nothing in the spec.

## Coupling rules

The spec ↔ code coupling rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — are canonical in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`; that reference
governs how an answer this skill drives to a decision is folded into the spec.
