# Fixture: two competing human decisions — deterministic tie-break

Cross-workflow: two level-3 human-decision candidates from different workflows —
a `Proposed` ADR (adr territory) and a drafted-but-unapproved intent (spec
territory). Same safety level; the tie-break must be deterministic.

## Given

- No committed secrets, no open blocking questions, no stale tracker state.
- ADR `0007-event-bus.md` is `Status: Proposed`, awaiting its Deciders. The
  `payments` feature's contract depends on this decision. The ADR's `Deciders`
  names the person in the session, so the decision is **answerable in-session**
  (rule `61-gate-prompts`).
- Feature `search` intent is `draft`, drafted but not yet PO-approved — it does
  **not** depend on the ADR.
- Neither candidate has a human-set **Priority** field (an ADR has no issue
  field; the `search` issue's Priority is unset), so the composite sort key's
  Priority term is equal — the tie falls through to the unblock-count term below.
- No PRs open.

## Expected highest-priority action

Have the Deciders ratify (or reject) ADR `0007-event-bus`, because it unblocks
the most downstream work (the `payments` contract) — the within-level tie-break
prefers the decision that unblocks more, and the navigator states the tie was
broken that way.

## Expected category

Human decision required

## Expected suggested command

`/steer:adr` — the decision stays the Deciders', but it is answerable in-session,
so the line names the skill that **collects and records** their answer (its
three-option prompt, then `/steer:adr accept 0007` on Approve). Contrast a PR
review, merge, or secret rotation, which remain command-less: no prompt
substitutes for those.

## Must not recommend first

Treating the two as interchangeable or surfacing PO approval of `search` first.
Both are level 3; arbitration must still resolve to **one** action by the
unblock-the-most tie-break (then by id if still tied), not present a menu.
