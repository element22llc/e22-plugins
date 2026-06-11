---
name: e22-questions
description: Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec. Use to work down accumulated open questions, before a release or PO→dev handoff, or when asked to resolve / review open questions.
---

# Resolve open questions (`/e22-questions`)

Open questions are the spine's quiet failure mode: they get written down once,
gated at PO acceptance, then left to rot. This skill is the **workflow that
answers them** — it gathers every open question across the `/spec` spine,
walks the PO/dev through each, and folds the decision back into the spec so the
question stops being open.

It is a **read-then-propose** sweep, like `/e22-drift` and `/e22-tidy`: it gathers
and proposes resolutions, and only edits the spec on a yes. It never *invents* a
decision — but many open questions in a reverse-engineered spec are factual
"what does the code do?" questions, which it answers cheaply by reading the code
(step 4), not by asking the human. A genuine decision the human can't make stays
open rather than being guessed.

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

1. **Heal a legacy `SPEC-QUESTIONS.md` first.** Before gathering, check for the
   retired standalone file a pre-1.25.0 fork may still carry:

   ```sh
   test -f spec/SPEC-QUESTIONS.md && echo "legacy SPEC-QUESTIONS.md present — migrate it before gathering"
   ```

   If it exists, migrate it into the current model, then remove it:
   - Read its `## Open` items. Route each to its context — a question tied to a
     specific feature → that feature's `spec/features/*/intent.md` →
     `## Open questions`; anything product-level → `spec/vision.md` →
     `## Open questions`. Preserve each item's Context / Options / Owner notes;
     create the `## Open questions` section in the destination if it's absent.
   - Read its `## Resolved` items. If the decision is already reflected in the
     owning `intent.md` / `contract.md`, drop it; otherwise fold the decision
     there first so it isn't lost.
   - This is a **move, not an answer** — never invent or resolve anything while
     migrating. Propose the migration (which items land where), and on a yes
     apply it and **delete `spec/SPEC-QUESTIONS.md`** so the retired artifact is
     gone. The migrated questions then flow into the normal sweep below.

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

6. **Fold each answer back into the spec (report + propose).** Per E22 autonomy,
   **propose** the spec edit and apply it on a yes — never blind-write
   user-facing behavior. For each answered question:
   - Update the owning `intent.md` / `contract.md` (or `vision.md`) so the
     decision lives in the durable spec, not just the chat.
   - **Strike the question from its `## Open questions` list** — mark it `- [x]`
     with the decision, or remove it once the decision is captured elsewhere in
     the spec.
   - **Code-fact answers** carry the grounding (`file:line`) and are marked as
     **dev-sign-off** — the dev confirms the as-built reading rather than
     deciding. User-facing answers need **PO** approval; other internal/technical
     answers need **dev** approval (spec-framework Rule 5).
   - A hard-to-reverse or cross-cutting answer → record it via **`/e22-adr`**.

7. **Explicit deferral is a valid outcome.** If a question genuinely can't be
   answered yet, keep the item but annotate it with **why** it's deferred (and a
   revisit trigger if there is one) so it reads as a deliberate decision, not
   neglect. A deferred question is tracked, not rotting.

8. **Never guess a decision.** A human-decision the human can't answer stays
   open, unchanged — don't invent it. (Grounding a *code-fact* in the actual code
   is not guessing; that's the cheap, correct move from step 4.)

## Coupling rules

The spec ↔ code coupling rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — are canonical in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill
*drives questions to answers*; that reference governs how an answer is folded
into the spec.
