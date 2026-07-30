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
  above the level-3 decision on #123.

## Expected highest-priority action

**Propose** `done` for #123 once acceptance is confirmed — a merged PR is necessary, not sufficient.

## Expected category

Human decision required (`validate → done` is propose-only, PO-owned for features)

## Expected suggested command

`/steer:work resume #123`

## Must not recommend first

`/steer:work start #160`, or claiming the workspace is `Complete`. Routing the
unfinished lifecycle on #123 (level 3) outranks starting unrelated optional work
(level 6); a merged-but-unreconciled issue is not `Complete`.

Nor **performing** #123's transition: `validate → done` is propose-only, so the
navigator names the PO's decision and offers `resume` as the follow-up — it never
reconciles the state itself.
