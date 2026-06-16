# /steer:next golden fixtures

Prose scenarios that pin the intended **cross-workflow** arbitration of
[`/steer:next`](../../../skills/next/SKILL.md) against the shared
[`NEXT-ACTIONS.md`](../NEXT-ACTIONS.md) contract. They are **not executable
tests** — they make the navigator's decision logic reviewable and guard against
semantic drift.

These differ from the per-skill
[`next-actions-fixtures/`](../next-actions-fixtures/): there, every candidate
comes from **one** workflow's locality-bound block. Here, candidates come from
**different, unrelated** workflows at once — that cross-workflow arbitration is
exactly what `/steer:next` owns and the per-skill blocks deliberately don't.

Each fixture states a multi-workflow `## Given` repository/spec/tracker state,
the `## Expected highest-priority action` and its `## Expected category`, the
`## Expected suggested command` (or `none`), and `## Must not recommend first`
(the trap the precedence must avoid). Walk the `/steer:next` dimension table plus
the shared safety precedence (NEXT-ACTIONS.md §2) by hand against each `Given`
and confirm the single arbitrated winner matches.
