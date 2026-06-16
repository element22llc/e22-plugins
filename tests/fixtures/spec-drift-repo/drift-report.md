# Drift report — customer-export

Read-only comparison of the as-built `/spec` against the tracker-exported intent.

## Findings

- The code exports an extra `phone` column the tracker intent does not mention.
- The tracker intent requires CSV; the code also emits XLSX (undocumented).

## Recommended next actions

### Human decision required

A human decides whether the undocumented `phone` column and XLSX output are
intended (update the spec) or accidental (open spec-drift issues).

## Expected category

Human decision required

### Current recommended action

PO/dev rules on the two drift findings for `customer-export`.
Suggested command: `/steer:issues`
