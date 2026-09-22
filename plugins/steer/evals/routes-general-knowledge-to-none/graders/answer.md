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

Judge what the response **did**, not what it recommends. A closing pointer at a
steer skill is a suggestion, not a workflow the response started - do not fail
it for that.

Fail the response if it:

- starts a steer workflow instead of answering - in particular a conventions or
  reference load, a repo sweep, or an announce-then-act line handing the ask to
  `/steer:<skill>`;
- withholds the answer pending a skill or a decision from the user; or
- answers about this repo's history rather than the question asked.
