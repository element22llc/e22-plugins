<!-- steer:schema=1 -->
<!-- steer:kind=audit-finding -->
<!-- steer:finding-key=data-layer:no-raw-sql:apps/api/reports.ts:exportCsv -->
<!-- steer:evidence=a1b2c3 -->
<!-- steer:audit-id=2026-06-10T12:00:00Z-deadbee -->
<!-- steer:audit-commit=deadbeef -->
<!-- steer:managed:start -->
## Finding

Raw SQL string interpolation in the reports export path.

## Evidence

- `apps/api/reports.ts:42-58` — string-built query.
<!-- steer:managed:end -->
