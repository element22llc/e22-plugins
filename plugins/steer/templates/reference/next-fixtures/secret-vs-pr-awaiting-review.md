# Fixture: security stop outranks a PR awaiting review

Cross-workflow: a committed secret (adopt/audit territory) vs. a delivery PR
awaiting review (work territory).

## Given

- A live API key is committed in the repo's history (confirmed during the state
  sweep, not suspected).
- Feature `customer-export` has issue #210 in `validate`: its PR is open, CI is
  green, and it awaits a reviewer.
- No other blocking state.

## Expected highest-priority action

Rotate and invalidate the exposed API key before any other workspace step.

## Expected category

Blocking now

## Expected suggested command

`/security-review` — offered only as the follow-up that validates remediation,
**not** as the action that rotates the secret.

## Must not recommend first

Asking a reviewer to review the #210 PR. A committed secret is a shared-safety
stop (level 1) and dominates a human-decision review gate (level 3), even though
the PR belongs to an unrelated, otherwise-ready feature.
