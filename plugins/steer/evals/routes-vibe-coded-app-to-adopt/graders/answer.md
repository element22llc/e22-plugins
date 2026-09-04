---
type: llm
focus: last_message
weight: 2
---

The response must route this ask the way steer's standards route it: to
adoption of existing code, whose spec must be reverse-engineered rather than authored fresh.

A passing response either runs that workflow or states plainly which steer skill
owns the ask and what it will do next. Naming the skill counts — when an ask needs
a decision from the user before work can start, asking is the correct move.

Judge what the response **did**, not what it recommends. A finished readout that
names another skill as the *next* action — a `Recommended next actions` handoff,
a `Suggested command: /steer:…` line, "first move when writable: …" — has not
started that workflow; that handoff is the standards' own closing contract.

Fail the response if it:

- starts the **wrong** workflow — in particular `init`, which does not own this ask;
- answers as a generic assistant — names no `/steer:*` skill at all. A competent
  plan, interview, or scaffold that never names the owning skill fails, however
  good it reads; or
- restates the ask back without identifying an owner or a next step.
