# Fixture: adopt — extracted intents need PO validation

Workflow: `/e22-adopt`

## Given

- No secrets or critical security exposure.
- Two reverse-engineered `intent.md` files (`export`, `admin`) are written but not PO-accepted.
- Two `Proposed` ADRs await a decision.
- Adoption findings are not yet published.

## Expected highest-priority action

Ask the product owner to review and validate the extracted intents (`spec/features/export/intent.md`, `spec/features/admin/intent.md`).

## Expected category

Human decision required

## Expected suggested command

none — PO validation is a human action; no E22 command performs it.

## Must not recommend first

`/e22-issues publish-adoption`. Human product/architecture decisions (level 3) outrank publishing findings (level 5). The `Proposed` ADRs are also Human decision required but the intents gate the product meaning of everything downstream.
