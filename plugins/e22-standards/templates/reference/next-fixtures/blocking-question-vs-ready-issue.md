# Fixture: a blocking gate outranks starting ready work

Cross-workflow: an unresolved blocking question on feature A (spec/questions
territory) vs. a fully decomposed, ready-to-start issue B (work territory).

## Given

- No committed secrets.
- Feature `billing` intent is `draft` with `Q-003`: `status: open`,
  `impact: blocking`, `required_before: intent-approval`, `owner: product`.
- Unrelated issue #145 (`reporting`) is `ready-for-dev`, decomposed and
  actionable, on no branch yet.
- No PRs open.

## Expected highest-priority action

Resolve the blocking open question `Q-003` on `billing` before its intent can be
approved.

## Expected category

Blocking now

## Expected suggested command

`/e22-standards:e22-questions`

## Must not recommend first

`/e22-standards:e22-work start #145`. A failed required gate (level 2) outranks optional
follow-up / starting new ready work (level 6), even though #145 is unblocked —
the blocking question is the more critical workspace state.
