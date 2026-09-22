---
type: llm
focus: last_message
weight: 2
---

The ask is to read code back to the user. No steer skill owns it: nothing here
touches a spec, an issue, a scaffold or the tracker, and the standards' own
routing rule is about mapping a goal to the skill that **owns** it, not about
finding the nearest one.

A passing response answers the question directly from the file - what `total()`
computes, and (fairly) that it ignores `quantity`, which is the defect planted
in this fixture. Noting that the defect could be filed or fixed is fine; doing
that instead of answering is not.

A closing handoff naming a steer skill is the standards' own contract, never a
failure - do not fail the response for it, and do not read it as evidence that
the response did nothing. A closing line pointing at `/steer:work` for the fix
is a suggestion about what comes next; judge the body above it.

Fail the response if it:

- starts a steer workflow instead of answering - an audit sweep, an issue
  triage, a spec or scaffold step, or an announce-then-act line that hands the
  ask to `/steer:<skill>`;
- withholds the answer pending a skill, a spec artifact, or a decision from the
  user; or
- answers something other than what the function does.
