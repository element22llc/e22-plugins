---
type: llm
focus: last_message
weight: 2
---

The response must route this ask the way steer's standards route it: an OpenSpec
repo whose steer surface is behind is a **sync** case - reconcile the scaffold
and steer's own artifacts, leaving the `openspec/` spine to OpenSpec.

A passing response has to do **both** of these:

1. **Name the owning skill.** `/steer:sync`, or its front door `/steer:setup`,
   appears somewhere in the response - an announce line, the body, or the
   closing handoff heading. Where it appears does not matter.
2. **Spend the body on that skill's work** - running it, carrying it as far as a
   read-only session allows, or asking the question the skill needs answered
   before it can start. Saying in a line what it could not carry out here is
   part of doing the work, not a substitute for it.

A closing handoff naming another skill is the standards' own contract, never a
failure: a `## Recommended next actions - /steer:<skill>` block, a `Suggested
command: /steer:...` line or a "first move when writable: ..." note says what
comes next. Do not fail the response for carrying one, and do not read one as
evidence that the response did nothing - judge the body above it.

Fail the response if it:

- names no `/steer:*` skill at all - a competent plan, readout, interview or
  scaffold that never names one fails, however good it reads. That is the
  no-plugin answer this case exists to tell apart;
- does the **wrong** workflow's work instead - in particular `init` or
  `adopt`, which would lay a second, competing `spec/` spine beside
  `openspec/`;
- **dead-ends**: reports that this repo is not a sync case, that its spine
  state is unsupported, or sends the reader from `sync` back to `setup` (or
  in a circle between them) instead of naming work to do. The repo carries
  pre-fold steer artifacts in `spec/`, so there is real work here;
- restates the ask back without identifying an owner or a next step.
