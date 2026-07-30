# Fixture: adopt — extracted intents need PO validation

Workflow: `/steer:adopt`

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

`/steer:spec approve` per feature — it offers the gate prompt. The *decision* stays the PO's, but an in-session PO approval **is** promptable and does carry a command; only an approval from a PO who is not in the session is command-less.

## Must not recommend first

`/steer:issues publish-adoption`. Human product/architecture decisions (level 3) outrank optional follow-up such as publishing findings (level 6). The `Proposed` ADRs are also Human decision required but the intents gate the product meaning of everything downstream.
