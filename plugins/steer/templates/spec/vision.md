# Vision

> Replace this template after creating the repo. Drafted with Claude — by a dev, or by a PO via `/steer:build`; the PO reviews and approves.

## What this product is

[Replace with one paragraph, plain language: what does this product do?]

## Who it serves

[Replace with one paragraph: who are the users, and what job are they hiring
this product to do?]

## Why it exists

[Replace with one paragraph: what problem does it solve, and why is it worth
building?]

## What success looks like

[Replace with 3–5 bullets: concrete signals that this product is working.
Behavioral or qualitative is fine.]

-
-
-

## What this product is NOT

[Replace with what we are explicitly choosing not to do — optional but
valuable.]

-
-

## Open questions

Product-level ambiguities not yet tied to a single feature (greenfield vision
gaps, whole-repo decisions). Per-feature questions live in that feature's
`spec/features/*/intent.md`. Work these down with `/steer:questions`. Use the
structured format (stable `Q-NNN` IDs, `status`/`impact`/`owner`/
`required_before`/`tracker`) — see the spec-framework reference. The seed block
below is marked `<!-- steer:placeholder -->` so the SessionStart open-questions hook
ignores it on a fresh scaffold — **delete the marker** (and the bracketed title)
when you fill in a real question.

### Q-001 — [Anything ambiguous about the product the PO/dev still needs to decide] <!-- steer:placeholder -->

- created:                # YYYY-MM-DD this question was raised (optional; drives staleness)
- status: open            # open | investigating | resolved | deferred | cancelled
- impact: blocking        # blocking | non-blocking
- owner: product          # product | development | design | security | shared
- required_before: intent-approval   # intent-approval | contract-approval | implementation | non-prod-validation | production-release
- tracker:                # issue ref once promoted (e.g. #142), else empty

_Resolution:_ recorded here when answered, then folded into the normative
sections above.
