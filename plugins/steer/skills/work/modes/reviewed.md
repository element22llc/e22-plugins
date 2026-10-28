# `/steer:work --reviewed` - an independent plan gate

Read this file only when `--reviewed` was passed. The preconditions,
authorization scope, delivery mode, subcommands, and guardrails stay in
`SKILL.md` and apply unchanged.

`--reviewed` adds an **independent** plan gate and a human plan sign-off in
front of the `start`->`finish` flow, whose `finish` already runs the code gate,
so the approach is **vetted, not first-draft**.
The execution is the normal flow: the same claim, branch, implement, test, PR, and transition
steps run, with gates added around them. Full protocol, rubric structure, and
stopping rules: [`REVIEW-LOOP.md`](../../../templates/reference/REVIEW-LOOP.md).

- **Triage first.** If the task is trivial (typo, one-liner, rename), run it
  without the gates and say they were skipped - honesty over ceremony. The gates
  earn their cost only on non-trivial work.
- **Plan gate - independent.** Before implementing, draft the approach (what
  changes, where, why), then spawn a **fresh reviewer subagent** - a separate
  context, **not** `steer-reviewer` (that agent reviews existing on-disk code and
  needs `path:line` evidence a prospective plan can't supply). Give it the plan,
  the **restated requirements** (what success means, in your words), and the
  relevant **steer rules** as the rubric, plus any `spec/learnings/` files the
  `start` grep matched (frontmatter and body). Ask for severity-ranked findings
  plus a "what's missing" pass; a plan that ignores a matched learning is a
  finding. **Revise on every high-severity finding**; never review
  your own plan.
- **Human plan sign-off - answerable in-session.** Present the vetted plan before a
  significant change (`--reviewed` is the caller opting into gates; rule
  `00-router` § You are not the gate) as a three-option prompt - **Approve · Reject · Decide later**
  (rule `61-gates`; protocol `/steer:reference gates`). The prompt shows what
  changes and where, the **high-severity reviewer findings and how they were
  resolved**, and the residual risk - not just "approve the plan?". `Approve`
  proceeds straight into implementation in the same pass; `Decide later` stops here
  with the plan recorded. Never pre-select `Approve` or infer it from ambient
  agreement. This covers the **plan**; delivery then runs the normal autonomous
  `finish` - merge still waits for the reviewer.
- **A blocking `Proposed` ADR is answerable too.** If the issue is gated on an ADR
  awaiting its Deciders and a Decider is in the session, offer ratification via
  `/steer:spec adr` rather than stalling the issue - on Approve it flips through
  `/steer:spec adr accept <n>` and implementation continues in the same pass.
- **Implement** via the normal `start`->`finish` flow - do not stand up a second
  path.
- **Code gate and bounded fix loop - the ones `finish` already runs.** The flag
  adds nothing to them but the approved plan, which joins the restated
  requirement in the reviewer's rubric (`modes/subcommands.md` -> `finish`;
  `REVIEW-LOOP.md` §4). In spec/standards-sensitive repos additionally invoke
  `steer-reviewer` to check the on-disk result against the standards (read-only,
  no git access - it reviews state, not the diff).
- **Report.** One line per gate - what it checked and its verdict - plus any
  residual risk, then the `## Recommended next actions` block from `SKILL.md`.
  Resolved findings are not re-listed; the diff carries them.

In **prototype/local mode** there is no tracker and therefore no `/steer:work` to
run - apply the same `REVIEW-LOOP.md` protocol directly around `/steer:build`'s
implementation, which is the path that population uses.
