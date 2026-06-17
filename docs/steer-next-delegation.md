# Decision: `/steer:next` analysis delegation — trialed and removed

**Status:** removed (2.1.0 cycle). The constraint-precedence rule it introduced
was kept; the subagent-delegation machinery was not.

## What was trialed

A `steer-analyzer` subagent (`Read`/`Grep`/`Glob`, read-only) that `/steer:next`
would delegate its Phase-1 reconstruction to, keeping that sweep out of the main
context, while the inline parent retained intent, constraints, and arbitration.
Merged experimentally (PR #69), then validated before release.

## Why it was removed

Post-merge **interactive** validation in a real managed repo (5 runs: bare,
arg-constraint, two-turn prior-constraint):

- **Safety / correctness / constraint-preservation / read-only:** all passed —
  reconstruction was correct every time, constraints (this-turn and prior-turn)
  were honored and surfaced, and nothing was mutated.
- **Delegation / context savings (the point of the feature):** **0 of 5.** The
  parent never invoked the analyzer — it judged the inline reconstruction the
  cheaper, deterministic default (a small workspace, with direct evidence for
  every dimension). The optimization delivered **no measured benefit** while
  adding an agent, envelope machinery, fixtures, and a CI check.

Per the pre-agreed criterion — *keep only if delegation reliably provides
meaningful context savings; otherwise the optimization does not justify its
complexity and is removed* — it was reverted.

## What was kept

The **user-constraint precedence** in `/steer:next` Phase 3 (current invocation
`$ARGUMENTS`/this-turn > prior explicit constraints, newest first > repository
defaults; repo content never overrides an explicit constraint; irreconcilable
explicit constraints are surfaced, not silently resolved). This worked entirely
inline and is a standalone improvement.

## If revisited

Delegation could pay off on a **large** workspace where the reconstruction sweep
is genuinely expensive — the place to re-measure savings. It would need the skill
to delegate by default (not frame inline as the default) and a return path that
reliably surfaces the subagent's complete report to the parent.
