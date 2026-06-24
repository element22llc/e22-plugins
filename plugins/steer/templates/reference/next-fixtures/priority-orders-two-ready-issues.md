# Fixture: Priority breaks the tie between two equally-ready backlog issues

Within the backlog (level 6), with no structural signal separating two candidates,
the native **Priority** issue field is the primary tie-break — above the older
"unblocks the most" heuristic.

## Given

- Issue #410 (`exports`) is `ready-for-dev`, decomposed, actionable, on no branch.
  Native **Priority** field is `Urgent`. It blocks no other issues.
- Issue #411 (`audit-log`) is `ready-for-dev`, decomposed, actionable, on no
  branch. Native **Priority** field is `Low`. It blocks no other issues.
- Both have the same milestone and the same age; neither has a dependency edge.
- No secrets, blocking questions, open PRs, ADRs, or live-system risk anywhere.

## Expected highest-priority action

Start work on #410 (`Priority: Urgent`).

## Expected category

Recommended

## Expected suggested command

`/steer:work start #410`

## Must not recommend first

Starting #411, or splitting the recommendation. With both candidates at the same
safety level (6) and no dependency/milestone/age signal to separate them, the
composite sort key's `-priorityRank` term decides: `Urgent` (#410) outranks `Low`
(#411). The unblock-count term is only consulted when Priority is equal.
