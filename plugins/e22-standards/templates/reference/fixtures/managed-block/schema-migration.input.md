<!-- e22:schema=1 -->
<!-- e22:kind=audit-finding -->
<!-- e22:finding-key=data-layer:no-raw-sql:apps/api/reports.ts:exportCsv -->
<!-- e22:evidence=a1b2c3 -->
<!-- e22:audit-id=2026-06-10T12:00:00Z-deadbee -->
<!-- e22:audit-commit=deadbeef -->
<!-- e22:managed:start -->
## Finding

Raw SQL string interpolation in the reports export path.

## Evidence

- `apps/api/reports.ts:42-58` — string-built query.
<!-- e22:managed:end -->
