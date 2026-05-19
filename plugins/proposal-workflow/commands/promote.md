---
description: Promote a feature flag to a higher rollout percentage.
argument-hint: <flag-name> <target-percentage>
---

# /promote

Promotes a feature flag for an existing `experimental` feature. This is the
human-gated transition from "merged to main" to "visible to users."

## Authorization

This command performs a state change visible to real users. Before doing anything:

1. Verify the invoking user is listed in `.github/PROMOTERS.yml` for the
   relevant product. If not, refuse and explain that promotion requires an
   authorized promoter.
2. Read the flag's current state from the feature-flag system (via the
   PostHog/LaunchDarkly MCP if configured).
3. Surface the current rollout percentage, the requested target, and the affected
   user count (estimate if exact is unavailable). Ask for explicit confirmation
   in the chat: "Promote `$FLAG` from X% to Y%? This affects ~Z users."

4. If the target is 100%, post a follow-up comment on the original PR with:
   - Sentry dashboard link filtered to this flag
   - Reminder of the production-graded gate conditions from the constitution
   - 24h timer reference — the human promoter (not Claude) should return to
     transition the label once conditions are met

## Workflow

1. Wait for explicit "yes" confirmation from the authorized user.
2. Apply the change via the feature flag MCP.
3. Post the change as a comment on the original `experimental`-labeled PR.
4. If the target is 100%, add a follow-up TODO comment: "Flag at 100%. Consider
   removing the flag and changing PR label to `production-graded` after
   observability confirms health (recommend 48h)."

## Things to avoid

- Never promote without explicit chat confirmation.
- Never promote past 10% in a single step for SOC2 in-scope products.
- Never promote a flag where the linked PR is still in `experimental` for less
  than 24 hours unless the user explicitly acknowledges the short bake time.
- Never delete a flag, even at 100% — that's a separate, human-driven cleanup.
