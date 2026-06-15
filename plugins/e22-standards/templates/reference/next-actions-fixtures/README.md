# Next-actions golden fixtures

Prose scenarios that pin the intended arbitration of the
[`NEXT-ACTIONS.md`](../NEXT-ACTIONS.md) handoff contract. They are **not
executable tests** — they make the decision logic reviewable and guard against
semantic drift as skills adopt the convention and as `/e22-next` is later built.

Each fixture states a `## Given` repository/spec/tracker state, the
`## Expected highest-priority action` and its `## Expected category`, the
`## Expected suggested command` (or `none`), and `## Must not recommend first`
(the trap the precedence must avoid). Walk a skill's domain table plus the shared
safety precedence by hand against each `Given` and confirm the outcome matches.
