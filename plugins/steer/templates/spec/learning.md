---
area: [code area or subsystem, e.g. apps/web/auth, packages/core/reports]
symptoms:
  - "[what you observe - an error message, a failing check, a wrong value]"
root_cause: "[one line - the actual cause, not the symptom]"
applies_when: "[the situation in which this lesson matters]"
retire_when: "[the condition that makes it obsolete - e.g. dependency X upgraded past 3.x]"
refs: ["[PR #]", "[issue ref]", "[commit sha]"]
date: YYYY-MM-DD
---

# [One-line lesson - "X fails because Y"]

## What happened

[Two or three lines: what was tried, what misled, what finally showed the cause.]

## Why

[The mechanism. Cite the paths involved so a later audit can tell when they move.]

## What to do

[The move to make next time, stated imperatively.]

<!--
Install as: spec/learnings/<slug>.md - kebab-case, no date in the name (the date
lives in the frontmatter). Created on first use; nothing pre-seeds the directory.

Write one only after the stronger homes were ruled out: a regression test, a
lint rule or hook, a contract.md rule, a product CLAUDE.md pattern. Skipping is
the normal outcome - a routine fix writes nothing. Before writing, grep the
existing frontmatter (area:, symptoms:, applies_when:) and update a matching
learning rather than adding a second one. Keep symptoms to 1-5 entries.
Delete this comment when you write the learning.
-->
