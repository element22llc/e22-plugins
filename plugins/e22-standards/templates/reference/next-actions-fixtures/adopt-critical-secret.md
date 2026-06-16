# Fixture: adopt — committed secret outranks everything

Workflow: `/e22-standards:e22-adopt`

## Given

- A live database credential is committed in the repo's history (confirmed, not suspected).
- Three productionization findings are selected but not yet published.
- The adoption PR has not been opened.

## Expected highest-priority action

Rotate and invalidate the exposed credential before any other adoption step.

## Expected category

Blocking now

## Expected suggested command

`/security-review` — offered only as the follow-up that validates remediation, **not** as the action that rotates the secret.

## Must not recommend first

`/e22-standards:e22-issues publish-adoption`, or opening the adoption PR. A committed secret is a shared-safety-precedence stop (level 1) and dominates the publish/PR steps.
