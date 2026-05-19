---
description: Auto-triggered when a non-engineering contributor describes a change they'd like to see ("I wish X did Y", "could we make X different", "we should change Y", "X is annoying because…"). Walks them through producing a structured proposal brief without requiring them to know about /draft-proposal.
---

A contributor has just described something they'd like to change in an Element 22 product. They probably don't know about the formal proposal workflow yet, and asking them to invoke `/draft-proposal` would be friction.

Treat this as if `/draft-proposal` had been called with their description as the argument. Follow the same workflow:

1. Refine the description if it's fuzzy (delegate to `intake-clarifier` if needed).
2. Gather product, motivation, success criteria, urgency, and champion via AskUserQuestion (one question per turn).
3. Produce a markdown brief and save it to the outputs folder.
4. Offer GitHub-issue or direct-handoff routing.
5. Confirm and close out with a single chat message.

**Important:** Before launching into the intake flow, briefly acknowledge what you heard and confirm they want to file this as a proposal. Sometimes people are just venting or thinking out loud. Example:

> "Sounds like you'd like to change how checkout handles failed payments. Want me to turn this into a proposal brief that an engineer can pick up? It takes about three questions."

If they say no, stop. If they say yes, proceed.

This skill is the on-ramp; `/draft-proposal` is the same flow when they already know what they want.
