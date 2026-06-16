# Fixture: spec — a blocking open question gates approval

Workflow: `/steer:spec customer-export`

## Given

- `spec/features/customer-export/intent.md` is in `Status: draft`.
- One open question has `impact: blocking`, `required_before: intent-approval`, and is unanswered.
- The contract is not yet written (behavior is still undecided pending the question).

## Expected highest-priority action

Resolve the blocking open question for `customer-export` before seeking intent approval.

## Expected category

Blocking now

## Expected suggested command

`/steer:questions` — the command that drives open questions to resolution.

## Must not recommend first

Presenting the intent for PO approval, or `/steer:tracker-sync push`. A blocking question (`required_before: intent-approval`) is a failed required gate (level 2) and must clear before the approval transition (level 4). Per the locality rule, only this feature's questions are considered.
