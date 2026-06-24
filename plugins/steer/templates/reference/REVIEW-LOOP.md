# The review-gated execution loop

The protocol behind `/steer:work --reviewed`. The loop takes a task and produces
a **vetted** result instead of a first draft, by inserting two *independent*
review gates — one on the plan, one on the diff — and a bounded fix loop around
the implementation step that `/steer:work` already owns.

This file owns the **shared logic**: the three disciplines, the per-gate rubric,
the stopping rules, and how the loop relates to the other execution skills. The
`/steer:work` skill's `--reviewed` mode owns only the step-by-step it runs.

---

## 1. Why a loop at all

A single straight pass — read prompt, plan in your head, implement, ship —
carries every misread of the requirement and every blind spot of the implementing
context straight into the output. The loop's value is that an **independent**
context, scoring against an **explicit** rubric, catches what the implementer
cannot see in its own work. Caught at the plan stage a flaw is cheap; caught in
the diff it is dearer; caught after merge, dearest. The loop front-loads that
catch.

It is **opt-in**, not always-on. Running a multi-subagent review loop on every
session would contradict the output-discipline rule and waste tokens on trivial
work. Reach for it deliberately, on work where a wrong approach is costly to
unwind.

## 2. The three disciplines (non-negotiable)

The loop degrades into theater without all three.

1. **Independence.** Each gate is a *fresh subagent* that never saw the rationale
   for the choices it reviews. A context that produced an artifact is anchored to
   its own reasoning and will confirm it. This is why the gate is a `steer-reviewer`
   subagent (or `/code-review`), not "re-read your own work."
2. **Explicit rubric.** The reviewer scores against the **restated requirements**
   (what success means, spelled out) plus the **relevant steer rules** — not a
   vague "is this good?". A reviewer with no rubric emits generic feedback that
   never converges.
3. **Bounded exit.** Review loops have sharp diminishing returns: round 1 catches
   most, round 2 the tail, round 3+ is churn and sometimes introduces regressions.
   Cap the fix loop at **2 rounds**; exit as soon as a round surfaces no
   high-severity findings.

## 3. The two gates are different jobs

- **Plan gate** reviews the *approach*: does it satisfy the requirement, is it the
  right shape, what is missing, does it respect the repo's invariants. Highest
  return — a flawed plan is cheap to fix before code exists. The reviewer here is
  a **fresh independent subagent**, *not* `steer-reviewer`: that agent requires
  `path:line` evidence in existing code, which a prospective plan can't supply, so
  it would return nothing.
- **Code gate** reviews the *diff*: correctness bugs, regressions, and fidelity to
  the approved plan. This is `/code-review`'s job. `steer-reviewer` is `Read`/
  `Grep`/`Glob`-only and has no git access, so it can check the **on-disk result
  against standards** but never "the diff" — keep that split. The gate is
  pre-merge in PR flow; in solo-trunk mode the change is already on `main` by the
  time it runs, so its findings become immediate follow-up fixes, not a merge
  block.

## 4. Rubric shape per gate

Give the reviewer three things, every time:

- **Plan gate** — the plan text; the restated requirement; the steer rules the
  change touches (e.g. conventions, change-size, the relevant lifecycle rules).
  Ask for severity-ranked findings and an explicit "what is missing" pass (the
  plan is prospective, so the reviewer reasons about the approach rather than
  citing `path:line`s).
- **Code gate** — the diff (`/code-review`); for standards-sensitive repos, the
  set of changed files plus the standards they must honor (`steer-reviewer`).

Severity ranking is what makes the loop converge: fix every **high** finding,
weigh **medium**, treat **low** as optional. Only high-severity findings keep the
fix loop open.

## 5. Where the loop sits among the skills

- **`/steer:work`** owns governed implementation — branch, commits, tests, PR,
  tracker — in GitHub-adopted repos. Its `--reviewed` mode *is* this loop: step 4
  runs the same governed implementation path, with the gates added around it. In
  prototype/local mode (no tracker) there is no `/steer:work`; apply this protocol
  directly around implementation, exactly as `/steer:build` does in that mode.
- **`/steer:build`** is the PO-facing greenfield flow. In its governed mode it
  routes implementation through `/steer:work`; in its default prototype/local mode
  it implements directly.
- **`/code-review`** is the built-in diff reviewer the code gate invokes; the loop
  does not reinvent it.
- **`steer-reviewer`** is the shipped read-only subagent the code gate's optional
  standards check invokes explicitly (it cites `path:line` evidence in existing
  code, so it is *not* used for the plan gate) — the same explicit-invocation
  pattern `/steer:audit` and `/steer:drift` use. The plan gate uses a fresh
  general reviewer subagent instead.

## 6. Cost

Each gate spends tokens on top of the implementation. That is the price of a
vetted result, and the reason for the triage step (trivial tasks skip the loop)
and the 2-round cap. If a run stops at the cap with findings still open, say so
and name what was left — silent truncation reads as "all clear" when it was not.
