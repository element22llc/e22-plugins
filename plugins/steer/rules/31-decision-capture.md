## Durable decisions land in the spine, not in side-channels

A durable design decision — stack, auth model, data model, architecture, a
locked scope or MVP cut — belongs in `/spec`: a feature's `intent.md`, a
`contract.md`, or an ADR (`/steer:adr`). Scoping conversation, chat summaries,
and **assistant memory** are working notes, not the record — never let a decision
survive only there.

**No `/spec` spine yet? Bootstrap before you commit the decision, not after.**
Never let memory or prose stand in for the missing spine. Run `/steer:init` (greenfield) or `/steer:adopt` (existing code)
first, so the decision lands somewhere traceable and reviewable. The scoping
dialogue is fine and expected (`init`'s interview is where it belongs); only the
**durable capture** waits for the spine. See bootstrap precedence in the router
and Living documentation (`32-living-docs`). Record each decision with its
ratifier and date — see Answering a human gate.
