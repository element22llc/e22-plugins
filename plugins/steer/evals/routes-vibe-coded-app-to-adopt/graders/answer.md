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

Fail the response if it:

- starts the **wrong** workflow — in particular `init`, which does not own this ask;
- answers as a generic assistant, with no sign the org standards were in play; or
- restates the ask back without identifying an owner or a next step.
