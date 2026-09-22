---
type: llm
focus: last_message
weight: 2
---

The ask is a general question about two git commands. It is tied to no artifact
in this repo, so no steer skill owns it: the standards' routing rule maps a goal
to the skill that **owns** it, and there is none to find here.

A passing response explains the difference - merge preserves the branch's
history and adds a merge commit; rebase replays the commits onto a new base and
rewrites them - in a couple of sentences. Mentioning what the repo's own
conventions prefer is fine as an aside.

A closing handoff naming a steer skill is the standards' own contract, never a
failure - do not fail the response for it, and do not read it as evidence that
the response did nothing. A closing pointer at a steer skill is a suggestion
about what comes next; judge the body above it.

Fail the response if it:

- starts a steer workflow instead of answering - in particular a conventions or
  reference load, a repo sweep, or an announce-then-act line handing the ask to
  `/steer:<skill>`;
- withholds the answer pending a skill or a decision from the user; or
- answers about this repo's history rather than the question asked.
