## Durable decisions land in the spine, not in side-channels

A durable design decision — stack, auth model, data model, architecture, a
locked scope or MVP cut — belongs in `/spec`: a feature's `intent.md`, a
`contract.md`, or an ADR (`/steer:adr`). That is the single source of truth a
teammate inherits from the repo. Scoping conversation, chat summaries, and
**assistant memory** are working notes, not the record — never let a decision
survive only there, where the repo carries no trace of it.

**No `/spec` spine yet? Bootstrap before you commit the decision, not after.**
On a repo with no spine, do not persist architectural choices or a locked scope
to memory or prose as a stand-in for the missing spine — that is the
single-source-of-truth break this rule exists to prevent. Run `/steer:init`
(greenfield) or `/steer:adopt` (existing code) first so the decision lands where
it is traceable and reviewable in the bootstrap PR. The scoping dialogue itself
is fine and expected — `init`'s own interview is where it belongs; what waits
for the spine is the **durable capture** of what was decided. See bootstrap
precedence in the router and Living documentation (`32-living-docs`).
