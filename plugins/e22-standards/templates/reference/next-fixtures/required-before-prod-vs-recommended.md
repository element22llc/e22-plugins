# Fixture: a release obligation outranks optional bookkeeping

Cross-workflow: a non-blocking question that gates production (questions
territory) vs. publishing optional findings to the backlog (audit/issues
territory).

## Given

- No committed secrets, no open blocking questions, no PRs awaiting review, no
  stale tracker state.
- Feature `exports` has `Q-009`: `status: open`, `impact: non-blocking`,
  `required_before: production-release`, `owner: security`. It does not block any
  current workflow, but must be resolved before a production release.
- Three vetted audit findings are selected but not yet published as issues.

## Expected highest-priority action

Resolve the production-gating open question `Q-009` on `exports`.

## Expected category

Required before production

## Expected suggested command

`/e22-questions`

## Must not recommend first

`/e22-issues publish-audit` (publishing the findings). A downstream release
requirement (level 5) outranks optional backlog bookkeeping (level 6).
Publishing a finding is never itself the production requirement — *resolving*
`Q-009` is.
