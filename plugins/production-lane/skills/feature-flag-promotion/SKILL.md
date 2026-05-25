---
description: Auto-triggered when someone signals they want to ramp a feature flag from one rollout percentage to another without typing /promote — "promote X to 50%", "roll out feature Y to all users", "ramp up the flag for Z", "increase exposure on W", "let's graduate X from experimental to production-graded", "flip the flag on V", "the experiment looks good, widen it". Routes to /promote so the change goes through the gated promotion path (SOC2 step caps, CODEOWNERS, audit-as-PR) instead of an ad-hoc flag flip.
---

A merged change is sitting behind a feature flag at some percentage and
someone wants to widen exposure. Promotion is the human-gated transition from
"merged to main" to "visible to users." Treat this as if `/promote <flag>
<target%>` had been called.

## When to trigger

Trigger on phrasing like:

- "promote ... to ...%" / "ramp ... to ...%"
- "roll out ... to all users" / "graduate ... from experimental"
- "increase the rollout on ..."
- "flip the flag on ..." (when said by someone authorized)
- "the experiment looks good, let's widen it"
- "this is ready for production-graded"

## When NOT to trigger

- The user is asking about flag *state* ("what's at 50% right now"), not
  requesting a change — answer directly; do not invoke `/promote`.
- The flag belongs to a SOC2-in-scope product and the requested jump exceeds
  10% in a single step — refuse cleanly and explain the gate. SOC2
  promotions are capped at 10%/step by the constitution.
- The user is not listed in CODEOWNERS for the promotion path — refuse
  cleanly and point them at the right approver.
- The change is still on a prototype branch or has never been validated —
  route to `validation-decision` → `/validate` first; promotion only applies
  to code already on `main`.
- The flag does not yet exist — route to `proposal-intake` → `/propose` so
  the change ships dark first.

## What happens next

Follow the `/promote` workflow:

1. Read the flag's current state from the flag system via the GitHub
   connector (or the configured flag provider).
2. Confirm the requested target percentage. Verify SOC2 step caps and any
   domain-specific gates (sensitive domains follow §9.7 + §9.4).
3. Open the promotion as its own PR so it is auditable — never an
   out-of-band flag flip. The PR records who promoted, from what %, to
   what %, against what flag, with what justification.
4. Notify the champion (the PO who owns the underlying change) that the
   flag is being widened, so they can verify the acceptance checks from the
   original Handoff Bundle §11 still hold under wider exposure.
5. On merge, the promotion takes effect; rollback is "flag off, then revert
   PR" (Lane Comparison table, §5.1).

## What this skill is not

- Not a way to ship unmerged code. `/promote` only operates on flags whose
  code is already on `main`.
- Not a way to bypass approval. SOC2 step caps, CODEOWNERS, and the §9.4
  scaled-approval matrix still apply to the promotion PR.
- Not a way to change *what* the flag gates. Behavior changes go through
  `proposal-intake` → `/propose` and a new PR; `/promote` only changes
  exposure %.

This skill is the on-ramp; `/promote` is the same flow when the contributor
already knows the flag name and target percentage.
