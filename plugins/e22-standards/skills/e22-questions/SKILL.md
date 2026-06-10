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
and proposes resolutions, and only edits the spec on a yes. It never invents an
answer — an unanswered question stays open rather than being guessed.

## Where open questions live

There is **no `SPEC-QUESTIONS.md`** — questions live next to their context:

- **Per feature** → each `spec/features/*/intent.md` → `## Open questions`
  (the `- [ ]` items).
- **Product-level** (greenfield vision ambiguities, whole-repo adoption
  questions — anything not yet tied to one feature) → `spec/vision.md` →
  `## Open questions`.
- If present, `spec/PRODUCTIONIZATION.md` → `## Open questions` (dev-facing
  hardening ambiguities).

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

1. **Gather.** Collect every open question across the spine. A grep over the
   `## Open questions` sections finds them — for example:

   ```sh
   grep -rn -A20 '^## Open questions' spec/vision.md spec/features/*/intent.md \
     spec/PRODUCTIONIZATION.md 2>/dev/null | grep -E '^\S+:[0-9]+[:-]- \[ \]'
   ```

   Read the surrounding section for context — a bare bullet is rarely
   self-explanatory. Skip items already resolved (`- [x]`) or already annotated
   as a deliberate deferral.

2. **Present a worklist.** Print a consolidated table — **product-level
   (`vision.md`) first**, then per feature — with the source file and the
   question. If there are none, say so and stop. Don't bury the list; this is
   the artifact the PO/dev acts on.

3. **Route each question to its owner.** Reuse the standard PO-vs-dev split:
   - **Product / behavior** ambiguities ("what should delete mean?", "which
     users see this?") → ask the **PO** in plain language.
   - **Technical / architectural** ambiguities (data model shape, integration
     boundary, library choice) → ask the **dev**.

   Ask, don't invent. Work through them oldest/most-blocking first.

4. **Fold each answer back into the spec (report + propose).** Per E22 autonomy,
   **propose** the spec edit and apply it on a yes — never blind-write
   user-facing behavior. For each answered question:
   - Update the owning `intent.md` / `contract.md` (or `vision.md`) so the
     decision lives in the durable spec, not just the chat.
   - **Strike the question from its `## Open questions` list** — mark it `- [x]`
     with the decision, or remove it once the decision is captured elsewhere in
     the spec.
   - User-facing answers need **PO** approval; internal/technical answers need
     **dev** approval (spec-framework Rule 5).
   - A hard-to-reverse or cross-cutting answer → record it via **`/e22-adr`**.

5. **Explicit deferral is a valid outcome.** If a question genuinely can't be
   answered yet, keep the item but annotate it with **why** it's deferred (and a
   revisit trigger if there is one) so it reads as a deliberate decision, not
   neglect. A deferred question is tracked, not rotting.

6. **Never guess.** Anything the human can't answer stays open, unchanged. Don't
   resolve a question by inventing the answer.

## Coupling rules

The spec ↔ code coupling rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — are canonical in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill
*drives questions to answers*; that reference governs how an answer is folded
into the spec.
