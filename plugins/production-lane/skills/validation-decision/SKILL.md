---
description: Auto-triggered when an engineer signals they're about to review a packaged prototype awaiting validation without typing /validate — "let's review PR #N", "I'll look at the handoff for X", "what's in the awaiting-validation queue", "is this a Keep or Refactor", "evaluate this prototype", "go through the bundle for Y", "the PO handed this off — let me look". Routes to the /validate gate so the engineer makes a Keep / Refactor / Redesign / Reject decision in minutes against the Spine, not a line-by-line read of throwaway prototype code.
---

An engineer is about to pick up a handed-off prototype. The PO already proved
it works — the preview URL is live, the Spine is written, the Handoff Bundle
is at `/.workflow/handoff.md`. The question is no longer "does it work" but
"is this architecture something we'll still want to own in a year?" Treat this
as if `/validate` had been called with the PR number or branch name.

## When to trigger

Trigger on phrasing like:

- "let's review PR #..." / "I'll validate ..." / "evaluate the handoff for ..."
- "is this Keep / Refactor / Redesign / Reject"
- "what's in the awaiting-validation queue"
- "go through the bundle for ..."
- "the PO handed this off — let me look"
- The user opens or asks about a `/.workflow/handoff.md` file whose branch
  has `handoff_status: ready` in `branch.yaml`.

## When NOT to trigger

- The user is starting fresh production work — route to `proposal-intake` →
  `/propose`.
- The user is still iterating on a prototype — route to `change-idea-intake`
  (prototype-lane) or stay in `/vibe`.
- The user is checking lifecycle state ("where's my X", "is X merged yet")
  rather than rendering a verdict — route to `/proposal-status`.
- `handoff_status` on the branch is not yet `ready` — the Prototype Ready
  Checklist (§9.2) hasn't been satisfied; refuse to validate and explain
  what's missing.
- The Handoff Bundle is missing sections 10 (do-not-reuse) or 11 (acceptance
  checks) — refuse cleanly (§9.3 enforcement); these are required fields.

## What happens next

Follow the `/validate` workflow:

1. Pull `/.workflow/branch.yaml`, `/.workflow/handoff.md`, and the Product
   Spine for the branch.
2. Surface the four signals the engineer needs to make a decision without
   reading the whole diff:
   - Novel patterns and plugin-pack violations
   - Dependency delta since `main`
   - Prototype shortcuts called out as **not to be reused** (Bundle §10)
   - Acceptance checks the PO will verify (Bundle §11)
3. Recommend one of **Keep / Refactor / Redesign / Reject** with a
   one-paragraph rationale, anchored to the Spine — not to prototype code
   style.
4. The engineer makes the call. Record the verdict as a review event on the
   PR so product approval and engineering approval are tracked separately
   (§9.4).
5. On Refactor or Redesign, hand off to `proposal-intake` → `/propose` with
   the Spine carried forward and the prototype code discarded as needed
   (§7.2 — the Spine travels, the code may not).

## What this skill is not

- Not a line-by-line code review of the prototype. Most of the diff will be
  discarded on Refactor or Redesign. Review the **spec**, not the chaos.
- Not a sign-off on production-readiness. That's the production-lane CI gate
  + scaled approval matrix (§9.4) after Refactor/Redesign work lands on
  `main`.
- Not the place to debate intent. Intent disputes go back to the PO via
  `proposal-status` / a Reject verdict — not relitigated inside `/validate`.

This skill is the on-ramp; `/validate` is the same flow when the engineer
already knows the PR number.
