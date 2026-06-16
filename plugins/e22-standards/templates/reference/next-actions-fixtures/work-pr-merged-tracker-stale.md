# Fixture: work — PR merged but issue state not reconciled

Workflow: `/e22-standards:e22-work #123`

## Given

- The PR for #123 has merged to `main`.
- The issue is still marked `validate` (lifecycle state not yet reconciled to `done`).

## Expected highest-priority action

Reconcile the stale tracker state for #123 to `done`.

## Expected category

Blocking now (the current workflow's own lifecycle transition is unfinished)

## Expected suggested command

`/e22-standards:e22-work resume #123` — `resume` owns post-merge reconciliation (it reconciles "a PR that merged/closed while away"). `status` only reports the staleness read-only; `finish` transitions to `validate`, never `done`.

## Must not recommend first

Starting a new issue, or `Complete`. Reconciling the just-merged work outranks picking up unrelated work.
