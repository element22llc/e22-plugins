# Fixture: two competing human decisions — deterministic tie-break

Cross-workflow: two level-3 human-decision candidates from different workflows —
a `Proposed` ADR (adr territory) and a drafted-but-unapproved intent (spec
territory). Same safety level; the tie-break must be deterministic.

## Given

- No committed secrets, no open blocking questions, no stale tracker state.
- ADR `0007-event-bus.md` is `Status: Proposed`, awaiting its Deciders. The
  `payments` feature's contract depends on this decision.
- Feature `search` intent is `draft`, drafted but not yet PO-approved — it does
  **not** depend on the ADR.
- No PRs open.

## Expected highest-priority action

Have the Deciders ratify (or reject) ADR `0007-event-bus`, because it unblocks
the most downstream work (the `payments` contract) — the within-level tie-break
prefers the decision that unblocks more, and the navigator states the tie was
broken that way.

## Expected category

Human decision required

## Expected suggested command

none — ratifying an ADR and approving an intent are both human decisions; no
command performs either.

## Must not recommend first

Treating the two as interchangeable or surfacing PO approval of `search` first.
Both are level 3; arbitration must still resolve to **one** action by the
unblock-the-most tie-break (then by id if still tied), not present a menu.
