# Fixture: reconcile a just-merged lifecycle before starting new work

Cross-workflow: an unfinished lifecycle transition (a merged PR whose tracker
state is stale) vs. picking up an unrelated ready issue.

## Given

- No committed secrets, no open blocking questions.
- Issue #123's PR was merged to `main`, but the issue is still marked `validate`
  (`<!-- steer:state=validate -->`) — the tracker transition to `done` was never
  completed.
- Issue #160 is `ready-for-dev` and actionable, not started — even if a human set
  its **Priority** to `Urgent`, that does **not** change the outcome: Priority is a
  within-level tie-break, below the structural safety level, so it cannot lift #160
  above the level-4 transition on #123.

## Expected highest-priority action

Reconcile the stale tracker state for #123 to `done`.

## Expected category

Blocking now

## Expected suggested command

`/steer:work resume #123`

## Must not recommend first

`/steer:work start #160`, or claiming the workspace is `Complete`. Finishing the
current workflow's own next lifecycle transition (level 4) outranks starting
unrelated optional work (level 6); a merged-but-unreconciled issue is not
`Complete`.
