# Fixture: adopt — PR opened but not reviewed is the current gate

Workflow: `/e22-standards:e22-adopt`

## Given

- No secrets or critical exposure; intents PO-accepted; no `Proposed` ADRs.
- The adoption PR has been opened but no one has reviewed or approved it.
- Findings are not yet published (cannot proceed meaningfully until the adoption lands).

## Expected highest-priority action

A reviewer reviews and approves the adoption PR.

## Expected category

Human decision required

## Expected suggested command

none — PR review is a human action.

## Must not recommend first

`Complete`. An opened-but-unmerged PR is execution-complete, **not** lifecycle-integrated, so the workflow is not `Complete`; the open PR is the current human gate (level 3) ahead of publishing (level 5).
