# Fixture: a human Priority:Urgent backlog item does not outrank a PR awaiting review

Cross-workflow: a high-Priority but merely-queued backlog feature (work territory)
vs. a finished PR awaiting review (work territory). Pins that the native
**Priority** issue field is a *within-level* tie-break and never crosses the
structural safety precedence.

## Given

- Feature `bulk-import` has issue #320 in `ready-for-dev`: decomposed, actionable,
  on no branch yet. A human set its native **Priority** field to `Urgent`.
- Feature `customer-export` has issue #210 in `validate`: its PR is open, CI is
  green, and it awaits a reviewer. Its Priority is unset.
- No secrets, no blocking questions, no live-system risk.

## Expected highest-priority action

A reviewer reviews the open #210 PR.

## Expected category

Human decision required

## Expected suggested command

`none` — a human reviews; no command advances it.

## Must not recommend first

Starting work on #320 because it is `Priority: Urgent`. Priority orders the
backlog *within* a safety level; it cannot lift a `ready-for-dev` item (level 6)
above a PR-review gate (level 3). The composite sort key compares `safetyLevel`
first and `-priorityRank` only second, so the level-3 review wins regardless of
the Urgent flag on the level-6 item.
