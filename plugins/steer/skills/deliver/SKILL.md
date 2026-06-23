---
name: deliver
description: Run a task through a review-gated execution loop — plan, an independent plan-gate review, your sign-off, implementation (delegated to /steer:work in GitHub-adopted repos, direct in prototype/local mode), an independent code-review gate, and a bounded fix loop — so the output is vetted, not first-draft. Orchestrates and reviews; delegates governed implementation rather than owning a second path.
when_to_use: >-
  Use when you want a non-trivial task carried out with review built in rather
  than in one straight pass — "deliver X carefully", "do this with review", or
  any change where a wrong approach would be costly to unwind. For routine issue
  execution without the extra gates, use /steer:work directly; for trivial edits,
  just make them.
argument-hint: "[task description]"
---

# Deliver a task through review gates

Produce a **vetted** result for a task, not a first draft. The lift comes from
inserting two *independent* review gates — one on the plan, one on the diff — and
a bounded fix loop, around the implementation step. This skill orchestrates and
reviews; in GitHub-adopted repos it delegates **governed implementation** to
`/steer:work` (the sole owner of that path) rather than standing up a second one.
In prototype/local mode — no tracker, hence no `/steer:work`, the same case
`/steer:build` handles — it implements directly.

Full protocol, rubric structure, and stopping rules:
[`REVIEW-LOOP.md`](../../templates/reference/REVIEW-LOOP.md).

## The loop

**0. Triage.** If the task is trivial (typo, one-liner, rename), just do it and
say the gates were skipped — honesty over ceremony. The gates earn their cost only
on non-trivial work.

**1. Plan.** Draft the approach: what changes, where, and why. For
multi-file/architectural work, plan it as you would before any significant change.

**2. Plan gate — independent.** Spawn a **fresh reviewer subagent** — a separate
context, **not** `steer-reviewer` (that agent reviews existing code against
standards and requires `path:line` evidence a prospective plan can't supply, so it
would return nothing). Give it:
- the **plan**,
- the **restated requirements** (what success means, in your words), and
- the **relevant steer rules** as the rubric.

Ask for severity-ranked findings plus an explicit "what's missing" pass. **Revise
the plan on every high-severity finding.** Never review your own plan — the
independence is the whole point; a context that wrote the plan rubber-stamps it.

**3. Human gate.** Present the vetted plan for sign-off before implementing a
significant change (Rules `45-commit-autonomy`, `95-not-the-gate`). This sign-off
covers the **plan**; `/steer:work`'s own push/PR autonomy gates (step 4) still
apply at delivery.

**4. Implement.** Route through the repo's normal implementation path — do not
stand up a second one:
- **GitHub-adopted repos** → delegate to **`/steer:work`**, which owns the issue,
  branch, commits, tests, and PR (push/PR stay prompt-gated per Rule 45). It is the
  sole owner of governed implementation; creating or routing an issue is its job,
  not this skill's.
- **Prototype / local mode** (no GitHub tracker — the population `/steer:build`
  serves) → implement directly here, as `build` does in that mode. There is no
  `/steer:work` to delegate to, so direct implementation is the normal path, not a
  second one.

**5. Code gate — independent.** Run `/code-review` on the resulting diff for
correctness bugs and fidelity to the approved plan. In spec/standards-sensitive
repos, additionally invoke `steer-reviewer` to check the **on-disk result against
the standards** (it is read-only with no git access, so it reviews state, not the
diff — `/code-review` owns the diff; this is squarely its audit-style job).
In PR flow this gate runs **before** merge. In **solo-trunk** delivery mode
`/steer:work` commits straight to `main`, so the gate reviews the trunk commit
after the fact and its findings become immediate follow-up fixes — say so rather
than implying it blocked a merge.

**6. Bounded fix loop.** Apply fixes for confirmed findings, then re-review.
**Cap at 2 rounds**; exit as soon as a round surfaces no high-severity findings.
If you stop at the cap with findings still open, say what was left and why — never
loop open-endedly.

**7. Report.** Summarize what was checked at each gate, which findings were
resolved, and any residual risk. Close with a `## Recommended next actions` block
(see [`NEXT-ACTIONS.md`](../../templates/reference/NEXT-ACTIONS.md) for the exact
category tokens).

## Why each discipline is non-negotiable

- **Independence** — the reviewer must be a separate context. Self-review anchors
  to its own reasoning and confirms it.
- **Explicit rubric** — score against restated requirements + steer rules, not a
  vague "is this good?", or feedback never converges.
- **Bounded exit** — review loops have sharp diminishing returns; round 1 catches
  most, round 2 the tail, round 3+ is churn. Stop on a clean round or at 2.
