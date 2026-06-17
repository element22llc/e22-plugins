# Fixture: deterministic inline fallback on incomplete delegation

Pins the rule that delegation is a best-effort optimization over a deterministic
inline default — anything short of a complete, contract-matching analyzer report
falls back to the inline reconstruction.

## Given

- `steer-analyzer` is absent, fails, exhausts its turns, returns only a mid-run
  preview, or returns a final report **missing a required section**.

## Accept only

- A complete response containing `## Observed state`, `## Candidate next actions`,
  `## Uncertainties`, and `## No-action finding` (the last omitted only when there
  is at least one candidate).

## Expected behavior

- The parent does the Phase 1 reconstruction **inline** itself.
- The parent **states that delegated analysis was unavailable**.
- Constraints, classification, and arbitration still run in the parent — the
  recommendation is unchanged in correctness, only its source differs.

## Must not

- Treat a partial / preview / "still running" response as if it were complete.
- Fabricate the analyzer's output or silently drop the recommendation.
