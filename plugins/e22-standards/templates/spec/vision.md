# Vision

> Replace this template after creating the repo. Drafted with Claude — by a dev, or by a PO via `/e22-standards:e22-build`; the PO reviews and approves.

## What this product is

[One paragraph. Plain language. What does this product do?]

## Who it serves

[One paragraph. Who are the users? What job are they hiring this product to do?]

## Why it exists

[One paragraph. What problem does it solve? Why is it worth building?]

## What success looks like

[3–5 bullets. Concrete signals that this product is working. Behavioral or qualitative is fine.]

-
-
-

## What this product is NOT

[Optional but valuable. What are we explicitly choosing not to do?]

-
-

## Open questions

Product-level ambiguities not yet tied to a single feature (greenfield vision
gaps, whole-repo decisions). Per-feature questions live in that feature's
`spec/features/*/intent.md`. Work these down with `/e22-standards:e22-questions`. Use the
structured format (stable `Q-NNN` IDs, `status`/`impact`/`owner`/
`required_before`/`tracker`) — see the spec-framework reference.

### Q-001 — [Anything ambiguous about the product the PO/dev still needs to decide]

- status: open            # open | investigating | resolved | deferred | cancelled
- impact: blocking        # blocking | non-blocking
- owner: product          # product | development | design | security | shared
- required_before: intent-approval   # intent-approval | contract-approval | implementation | non-prod-validation | production-release
- tracker:                # issue ref once promoted (e.g. #142), else empty

_Resolution:_ recorded here when answered, then folded into the normative
sections above.
