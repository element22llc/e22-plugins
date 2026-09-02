# `/steer:work --reviewed` — independent plan and code review gates

Read this file only when `--reviewed` was passed. The preconditions,
authorization scope, delivery mode, subcommands, and guardrails stay in
`SKILL.md` and apply unchanged.

`--reviewed` wraps the `start`→`finish` flow in two **independent** review
gates plus a bounded fix loop, so the delivery is **vetted, not first-draft**.
This is the review-gated path formerly carried by the standalone `deliver` skill; the execution
itself is unchanged — the same claim, branch, implement, test, PR, and transition
steps run, with gates added around them. Full protocol, rubric structure, and
stopping rules: [`REVIEW-LOOP.md`](../../../templates/reference/REVIEW-LOOP.md).

- **Triage first.** If the task is trivial (typo, one-liner, rename), run it
  without the gates and say they were skipped — honesty over ceremony. The gates
  earn their cost only on non-trivial work.
- **Plan gate — independent.** Before implementing, draft the approach (what
  changes, where, why), then spawn a **fresh reviewer subagent** — a separate
  context, **not** `steer-reviewer` (that agent reviews existing on-disk code and
  needs `path:line` evidence a prospective plan can't supply). Give it the plan,
  the **restated requirements** (what success means, in your words), and the
  relevant **steer rules** as the rubric. Ask for severity-ranked findings plus a
  "what's missing" pass. **Revise on every high-severity finding**; never review
  your own plan.
- **Human plan sign-off — answerable in-session.** Present the vetted plan before a
  significant change (`--reviewed` is the caller opting into gates; rule
  `95-not-the-gate`) as a three-option prompt — **Approve · Reject · Decide later**
  (rule `61-gate-prompts`; protocol `/steer:reference gates`). The prompt shows what
  changes and where, the **high-severity reviewer findings and how they were
  resolved**, and the residual risk — not just "approve the plan?". `Approve`
  proceeds straight into implementation in the same pass; `Decide later` stops here
  with the plan recorded. Never pre-select `Approve` or infer it from ambient
  agreement. This covers the **plan**; delivery then runs the normal autonomous
  `finish` — merge still waits for the reviewer.
- **A blocking `Proposed` ADR is answerable too.** If the issue is gated on an ADR
  awaiting its Deciders and a Decider is in the session, offer ratification via
  `/steer:adr` rather than stalling the issue — on Approve it flips through
  `/steer:adr accept <n>` and implementation continues in the same pass.
- **Implement** via the normal `start`→`finish` flow — do not stand up a second
  path.
- **Code gate — independent.** After implementing, run `/code-review` on the diff
  for correctness bugs and fidelity to the approved plan; in
  spec/standards-sensitive repos additionally invoke `steer-reviewer` to check the
  on-disk result against the standards (read-only, no git access — it reviews
  state, not the diff). In **pr-flow** this gate runs **before** merge; in
  **solo-trunk** it reviews the trunk commit after the fact and its findings
  become immediate follow-up fixes — say so rather than implying it blocked a
  merge.
- **Bounded fix loop.** Apply fixes for confirmed findings, then re-review.
  **Cap at 2 rounds**; exit as soon as a round surfaces no high-severity findings.
  If you stop at the cap with findings still open, say what was left and why.
- **Report.** One line per gate — what it checked and its verdict — plus any
  residual risk, then the `## Recommended next actions` block from `SKILL.md`.
  Resolved findings are not re-listed; the diff carries them.

In **prototype/local mode** there is no tracker and therefore no `/steer:work` to
run — apply the same `REVIEW-LOOP.md` protocol directly around `/steer:build`'s
implementation, which is the path that population uses.
