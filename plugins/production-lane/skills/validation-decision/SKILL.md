---
description: Auto-triggered when an engineer signals they're about to review a HANDOFF.md from a PO MVP without typing /validate — "let's review the handoff for X", "I'll evaluate the MVP", "is this Harden or Extract", "evaluate this prototype", "go through the HANDOFF for Y", "the PO handed this off — let me look". Routes to the /validate gate so the engineer makes a Harden / Extract / Rewrite / Reject / Continue exploring decision in minutes against the handoff packet, not a line-by-line read of disposable prototype code.
---

An engineer is about to pick up a handed-off MVP. The PO already proved
it works — the preview URL is live, any Spine is written, and HANDOFF.md is
at the workspace root. The question is no longer "does it work" but
"is this architecture something we'll still want to own in a year?" Treat this
as if `/validate` had been called with the PR number or branch name.

## When to trigger

Trigger on phrasing like:

- "let's review PR #..." / "I'll validate ..." / "evaluate the handoff for ..."
- "is this Harden / Extract / Rewrite / Reject / Continue exploring"
- "what's in the awaiting-validation queue"
- "go through the HANDOFF for ..."
- "the PO handed this off — let me look"
- The user opens or asks about a HANDOFF.md whose §14 has a suggested decision filled in.

## When NOT to trigger

- The user is starting fresh production work — route to `proposal-intake` →
  `/propose`.
- The user is still iterating on the MVP locally — the PO should keep exploring;
  respond conversationally without invoking /validate.
- The user is checking lifecycle state ("where's my X", "is X merged yet")
  rather than rendering a verdict — route to `/proposal-status`.
- HANDOFF.md is not present or §14 (suggested decision) is empty — the MVP
  Ready Checklist (§9.2) hasn't been satisfied; refuse to validate and explain
  what's missing.
- HANDOFF.md is missing sections 10 (do-not-reuse) or 11 (acceptance
  checks) — refuse cleanly (§9.3 enforcement); these are required fields.

## What happens next

Follow the `/validate` workflow:

1. Pull HANDOFF.md (at the workspace root or imported into the repo) and any
   Product Spine for the branch.
2. Surface the four signals the engineer needs to make a decision without
   reading the whole diff:
   - Novel patterns and plugin-pack violations
   - Dependency delta since `main`
   - MVP shortcuts called out as **not to be reused** (HANDOFF.md §10)
   - Acceptance checks the PO will verify (HANDOFF.md §11)
3. Recommend one of **Harden / Extract / Rewrite / Reject / Continue exploring** with a
   one-paragraph rationale, anchored to the Spine — not to prototype code
   style.
4. The engineer makes the call. Record the verdict as a review event on the
   PR so product approval and engineering approval are tracked separately
   (§9.4).
5. On Extract or Rewrite, hand off to `proposal-intake` → `/propose` with
   HANDOFF.md as the spec and the prototype source kept aside (the source may
   be discarded entirely on Rewrite).

## What this skill is not

- Not a line-by-line code review of the prototype. Most of the diff will be
  discarded on Extract or Rewrite. Review the **spec**, not the chaos.
- Not a sign-off on production-readiness. That's the governed-production CI gate
  + scaled approval matrix (§9.4) after Extract/Rewrite work lands on
  `main`.
- Not the place to debate intent. Intent disputes go back to the PO via
  `proposal-status` / a Reject verdict — not relitigated inside `/validate`.

This skill is the on-ramp; `/validate` is the same flow when the engineer
already knows the PR number.
