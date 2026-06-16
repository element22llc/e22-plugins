# Fixture: work — PR opened, acceptance met, awaiting review

Workflow: `/e22-standards:e22-work #123`

## Given

- Issue #123 implemented; acceptance criteria met; validation/CI green.
- The PR is open and in `validate` state, awaiting human review.

## Expected highest-priority action

A reviewer reviews the PR for #123.

## Expected category

Human decision required

## Expected suggested command

none — PR review is a human action.

## Must not recommend first

`/e22-standards:e22-work finish #123` (already in `validate`) or `Complete`. The issue is not `done` until the PR merges, so the workflow is not `Complete`; the open PR is the current human gate.
