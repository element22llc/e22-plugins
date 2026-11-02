# Fixture: adopt - as-built intents need no PO approval

Workflow: `/steer:adopt`

## Given

- No secrets or critical security exposure.
- The app is deployed with real users; two reverse-engineered `intent.md` files (`export`, `admin`) are written `live`, `Approved by: as-built`, PO-acceptance boxes unchecked.
- Two `Proposed` ADRs await a decision.
- Adoption findings are not yet published.

## Expected highest-priority action

Decide the `Proposed` ADRs.

## Expected category

Human decision required

## Expected suggested command

`/steer:spec adr` - review each ADR and answer its ratification prompt.

## Must not recommend first

`/steer:spec approve` on `export` or `admin`: a `live` as-built intent describes behavior already released, so there is no scope left to approve, and `approve` refuses on `live`. Nor `/steer:work issues publish-adoption` - optional follow-up (level 6) never outranks a human decision (level 3).
