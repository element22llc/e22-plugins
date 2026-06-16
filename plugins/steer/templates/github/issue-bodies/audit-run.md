<!-- steer:schema=2 -->
<!-- steer:kind=audit-run -->
<!-- steer:state=done -->
<!-- steer:source=audit -->
<!-- steer:audit-id=AUDIT_ID -->
<!-- steer:audit-commit=COMMIT_SHA -->
<!-- steer:managed:start -->
## Scope

[What was audited — paths, packages, or "whole repo". Dimensions run; dimensions
skipped (not applicable) or not run (no /spec), so silence never reads as clean.]

## Run metadata

- **Plugin version:** [steer vX.Y.Z]
- **Audited commit:** `COMMIT_SHA`
- **Dimensions run:** [architecture, data layer, validation, …]
- **Dimensions skipped / not run:** [with reason]

## Summary

[Counts by dimension and severity; the top findings. One audit-run record per
run — this issue is immutable history, never re-edited on the next audit.]

## Report

[Path to the full report or attached artifact, e.g. `spec/AUDIT-REPORT.md` on a
`feat/audit` branch — if the dev chose to track it.]

Findings are filed as separate child issues keyed by `finding-key` and reconciled
across runs (see the issue-schema reference).
<!-- steer:managed:end -->
