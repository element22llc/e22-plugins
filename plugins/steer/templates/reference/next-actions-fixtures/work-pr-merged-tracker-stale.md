# Fixture: work — PR merged but issue state not reconciled

Workflow: `/steer:work #123`

## Given

- The PR for #123 has merged to `main`.
- The issue is still marked `validate` (lifecycle state not yet reconciled to `done`).

## Expected highest-priority action

**Propose** `done` for #123 once acceptance is confirmed — a merged PR is necessary, not sufficient.

## Expected category

Human decision required (`validate → done` is propose-only, PO-owned for features)

## Expected suggested command

`/steer:work resume #123` — `resume` owns post-merge reconciliation (it reconciles "a PR that merged/closed while away") and **proposes** the transition; it never performs it. `status` only reports the staleness read-only; `finish` transitions to `validate`, never `done`.

## Must not recommend first

Starting a new issue, or `Complete`. The unfinished lifecycle on the just-merged work outranks picking up unrelated work.

Nor **performing** the transition: this row is `Human decision required`, not `Blocking now` — an agent that reconciles #123 to `done` on its own has written a state only the PO owns.
