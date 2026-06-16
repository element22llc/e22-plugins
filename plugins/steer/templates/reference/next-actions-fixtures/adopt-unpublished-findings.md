# Fixture: adopt — clean decisions, findings ready to publish

Workflow: `/steer:adopt`

## Given

- No secrets or critical exposure.
- All extracted intents are PO-accepted; no `Proposed` ADRs pending.
- The adoption PR has been opened, reviewed, and merged.
- Selected productionization findings are not yet published as issues.

## Expected highest-priority action

Publish the selected adoption findings into the backlog.

## Expected category

Recommended

## Expected suggested command

`/steer:issues publish-adoption`

## Must not recommend first

Any `Blocking now` or `Human decision required` action — there are none, so backlog bookkeeping is correctly the top remaining step. Note: publishing is **Recommended**, not a production-readiness category (**Required before initial production** / **next production release**); the production requirement is *fixing or accepting* each finding, not filing it.
