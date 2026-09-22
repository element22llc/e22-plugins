---
type: llm
focus: last_message
weight: 2
---

The response must route this ask the way steer's standards route it: to
the guided product-owner build, not a developer bootstrap path.

A passing response has to do **both** of these:

1. **Be recognizably steer's guided build.** `/steer:build` named outright
   counts. Where it is not named - and this skill deliberately spares a
   non-technical owner the skill name - the flow must show instead, and two of
   its steps are what steer adds to any competent offer of help: a written
   plain-language spec the owner **approves before any code is written**, and a
   **developer review** before the app is used for real. Both must be there.
   Interviewing well and promising a plan is not the flow.
2. **Spend the body on that work** - starting the interview, or asking the
   question it needs answered first. Saying in a line what it could not carry
   out here is part of doing the work, not a substitute for it.

A closing handoff naming another skill is the standards' own contract, never a
failure: a `## Recommended next actions - /steer:<skill>` block or a `Suggested
command: /steer:...` line says what comes next. Do not fail the response for
carrying one, and do not read one as evidence that the response did nothing -
judge the body above it.

Fail the response if it:

- offers a competent interview or plan with neither the skill named nor those
  two gates - no owner approval before code, no developer review. That is the
  no-plugin answer this case exists to tell apart;
- does the **wrong** workflow's work instead - in particular `adopt`, which does
  not own this ask; or
- restates the ask back without identifying an owner or a next step.
