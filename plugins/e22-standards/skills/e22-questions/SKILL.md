---
name: e22-questions
description: Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec.
when_to_use: Use to work down accumulated open questions, before a release or PO→dev handoff, or when asked to resolve or review open questions.
---

# Resolve open questions (`/e22-questions`)

Open questions are the spine's quiet failure mode: they get written down once,
gated at PO acceptance, then left to rot. This skill is the **workflow that
answers them** — it gathers every open question across the `/spec` spine,
walks the PO/dev through each, and folds the decision back into the spec so the
question stops being open.

It gathers every open question, then resolves each **by tier**. Answers that
**make no new decision** — code-facts grounded from the code (step 4), and
decisions already made — are folded straight back into the spec in the same
change, with the **PR as the gate**; the skill does not stop to ask "shall I
apply this?" for those (rule `32-living-docs`: *applying a decision already made
is not a new decision*). A **genuine decision the human hasn't made** — a
product/policy/architecture call — is routed to them (step 5) and applied only
on a yes. It never *invents* a decision; an unanswerable one stays open rather
than being guessed.

## Where open questions live

There is **no `SPEC-QUESTIONS.md`** — questions live next to their context:

- **Per feature** → each `spec/features/*/intent.md` → `## Open questions`
  (the `- [ ]` items).
- **Product-level** (greenfield vision ambiguities, whole-repo adoption
  questions — anything not yet tied to one feature) → `spec/vision.md` →
  `## Open questions`.
- If present, `spec/PRODUCTIONIZATION.md` → `## Open questions` (dev-facing
  hardening ambiguities).

A fork from an older template revision (pre-1.25.0) may still carry the retired
standalone `spec/SPEC-QUESTIONS.md`. If it does, step 1 migrates its questions
into the locations above and removes it — so this skill also self-heals the
drift, not just consumes it.

## When to run

- Periodically, to work the backlog down before it accumulates.
- Before a **release** or a **PO→dev handoff**, as a "nothing unanswered left
  to rot" gate.
- Whenever a feature's `## Open questions` list has grown and nobody has
  circled back.

A SessionStart hook (`check-open-questions.sh`) counts outstanding open
questions and surfaces the backlog every session, so it can't quietly
accumulate — this skill is how you act on that nudge and clear it.

## Steps

1. **Heal a legacy `SPEC-QUESTIONS.md` first — migrate *and delete* before you
   answer anything.** Before gathering, check for the retired standalone file a
   pre-1.25.0 fork may still carry:

   ```sh
   test -f spec/SPEC-QUESTIONS.md && echo "legacy SPEC-QUESTIONS.md present — migrate it before gathering"
   ```

   If it exists, this migration is a **hard gate**: the file's questions move
   into the spine and `spec/SPEC-QUESTIONS.md` is **deleted as part of this
   step**, before the sweep touches them. Do not skip it because the spine's
   `## Open questions` sections look empty — empty/placeholder sections are
   exactly the pre-state this step fills. Migrate:
   - Read its `## Open` items. Route each to its context — a question tied to a
     specific feature → that feature's `spec/features/*/intent.md` →
     `## Open questions`; anything product-level → `spec/vision.md` →
     `## Open questions`. Preserve each item's Context / Options / Owner notes;
     create the `## Open questions` section in the destination if it's absent.
   - Read its `## Resolved` items. If the decision is already reflected in the
     owning `intent.md` / `contract.md`, drop it; otherwise fold the decision
     there first so it isn't lost.
   - This is a **move, not an answer** — never invent or resolve anything while
     migrating. Propose the migration (which items land where) **and the
     deletion together**, and on a yes apply it and **delete
     `spec/SPEC-QUESTIONS.md`**. Only the migrated copies in the spine survive;
     they flow into the normal sweep below, where you answer them.
   - **Never keep the file alive as a working store.** Do not "update
     `SPEC-QUESTIONS.md` in place," move its resolved items into a `## Resolved`
     section, leave its deferred items under `## Open`, or defer its retirement
     to "a later step." Once its content is preserved in the spine the file is
     deleted in this same step — its continued existence after this skill runs is
     a failure, not a deferral. The deletion is unconditional and does **not**
     wait on the questions being answered.

2. **Gather.** Collect every open question across the spine. A grep over the
   `## Open questions` sections finds them — for example:

   ```sh
   grep -rn -A20 '^## Open questions' spec/vision.md spec/features/*/intent.md \
     spec/PRODUCTIONIZATION.md 2>/dev/null | grep -E '^\S+:[0-9]+[:-]- \[ \]'
   ```

   The grep's `-A20` window is usually enough context — **don't read each owning
   file wholesale.** Open a file only for a specific bullet whose meaning the
   grep output didn't capture, and read just that `## Open questions` section.
   Skip items already resolved (`- [x]`) or annotated as a deliberate deferral.

3. **Present a worklist.** Print a consolidated table — **product-level
   (`vision.md`) first**, then per feature — with the source file and the
   question. If there are none, say so and stop. Don't bury the list; this is
   the artifact the PO/dev acts on.

4. **Triage: code-fact vs human-decision (do this before any investigation).**
   In a reverse-engineered spec (`/e22-adopt`), most open questions are *factual
   questions about what the code already does* — "is `X` dead code?", "does the
   client or server enforce this rule?", "what roles exist?" — **not** decisions.
   These are not for the human: asking the PO/dev what their own code does wastes
   a turn. Split the worklist into two buckets:
   - **Code-fact** — answerable by reading the code the question names. Ground it
     and propose a dev-sign-off answer (step 6).
   - **Human-decision** — genuine product / policy / roadmap / architecture calls
     (retention windows, pricing, consent, lifecycle intent). Route to a human
     (step 5).

   **Cost guardrail — this is where the skill gets expensive if you let it.**
   Ground code-facts the *cheap* way: targeted, inline reads of the specific
   file/symbol each question names, batched into one pass. Each question usually
   needs one or two `grep`/`Read` calls, not a search of the repo.
   - Do **not** spawn an investigation agent per question or per subsystem — a
     fan-out of Explore agents over a 20-feature spec can burn hundreds of
     thousands of tokens to answer questions a handful of greps would settle.
   - Escalate to **at most one** bounded subagent for the *entire* batch, and
     only if several questions genuinely need a broad cross-file search you can't
     do inline. Give it the explicit question list and tell it to return answers,
     not a codebase tour.
   - If grounding a particular question would cost more than the answer is worth,
     leave it open and say so — an honest "unverified, needs a look" beats an
     expensive sweep.

5. **Route each human-decision to its owner.** Reuse the standard PO-vs-dev split:
   - **Product / behavior** ambiguities ("what should delete mean?", "which
     users see this?") → ask the **PO** in plain language.
   - **Technical / architectural** ambiguities (data model shape, integration
     boundary, library choice) → ask the **dev**.

   Ask, don't invent. Work through them oldest/most-blocking first.

6. **Fold each answer back into the spec — by tier** (rule `32-living-docs`:
   *applying a decision already made is not a new decision*).
   - **Auto-apply, no per-edit yes** — answers that decide nothing new: a
     **code-fact** grounded from the code (step 4), or a human-decision the
     PO/dev *just made* in this session. Write the spec edit (and any docs that
     must stay consistent with it — a `CLAUDE.md` one-liner, a superseding ADR)
     in the same change and let the **PR be the gate** (rule `95-not-the-gate`).
     This is the friction this skill exists to remove — don't stop to ask
     "shall I apply this?".
   - **Ask first** — a genuine product/policy/architecture decision *not yet
     made*, or anything under **High-risk areas** (rule `60-high-risk`): never
     blind-write it. Route it (step 5) and apply only once the human answers.
     Never invent a decision (step 8).

   For each answered question:
   - Update the owning `intent.md` / `contract.md` (or `vision.md`) so the
     decision lives in the durable spec, not just the chat.
   - **Strike the question from its `## Open questions` list** — mark it `- [x]`
     with the decision, or remove it once the decision is captured elsewhere in
     the spec.
   - **Code-fact answers** carry the grounding (`file:line`) and are marked
     **dev-sign-off** — the dev confirms the as-built reading at PR review
     rather than deciding now. User-facing answers reflect **PO** decisions,
     other internal/technical answers reflect **dev** decisions (spec-framework
     Rule 5); that sign-off is the PR, not a per-edit yes.
   - A hard-to-reverse or cross-cutting answer → record it via **`/e22-adr`**;
     propagating a decision *already made* into a new or superseding ADR is
     itself auto-apply, not a fresh ask.
   - A question that needs a **named owner, blocks multiple features, needs
     stakeholder/research input, or could outlive the session** → promote it to a
     tracker item (the keep-vs-promote test is in `ISSUE-WORKFLOW.md`). Keep the
     structured `Q-NNN` in the spec and set its `tracker:` field to the ref —
     don't delete the question; the issue carries the same id via
     `<!-- e22:question-id=Q-NNN -->`. On a GitHub tracker, **`/e22-issues`**
     (routing through `/e22-tracker-sync`) opens the `spec-question` issue; on
     other trackers, file it per `/spec/tracker.md` and write the ref back.
     **Reconciliation floor:** a promoted question must carry its ref, and once
     its issue is answered/closed the decision must be folded into the spec's
     normative prose — a closed issue with a still-`open` question is a
     validation failure (`/e22-spec validate`).

7. **Explicit deferral is a valid outcome.** If a question genuinely can't be
   answered yet, keep the item but annotate it with **why** it's deferred (and a
   revisit trigger if there is one) so it reads as a deliberate decision, not
   neglect. A deferred question is tracked, not rotting.

8. **Never guess a decision.** A human-decision the human can't answer stays
   open, unchanged — don't invent it. (Grounding a *code-fact* in the actual code
   is not guessing; that's the cheap, correct move from step 4.)

## Done when

- `spec/SPEC-QUESTIONS.md` does **not** exist if it did at the start — its
  questions were migrated into the spine (step 1) and the file deleted in that
  same step. A run that leaves the legacy file behind — answered, partially
  migrated, or "to retire later" — is **not** done.
- Every swept question is either struck with its decision or left open with an
  explicit deferral reason. None were silently dropped or guessed.

## Recommend the next action

End with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, scoped to the
questions just swept (locality rule).

| Observed state | Category | Action / suggested command |
|---|---|---|
| Open question still `impact: blocking` | Blocking now | Route to its `owner` (product/dev/design/security) for a decision (no command) |
| Genuine unmade product/architecture decision left open | Human decision required | The owning human decides (no command) |
| All blocking questions resolved | Recommended | Re-check the spec gate — `/e22-spec validate` |
| Only non-blocking deferrals remain | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence; an unanswerable question
stays open rather than being guessed.

## Coupling rules

The spec ↔ code coupling rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — are canonical in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill
*drives questions to answers*; that reference governs how an answer is folded
into the spec.
