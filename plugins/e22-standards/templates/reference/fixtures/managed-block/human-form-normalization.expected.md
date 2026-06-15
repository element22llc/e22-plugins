<!-- e22:schema=2 -->
<!-- e22:kind=bug -->
<!-- e22:state=inbox -->
<!-- e22:source=human -->
<!-- e22:dedupe-key=export:csv:duplicate-header -->
### What's the problem?

CSV export repeats the header row for every page.

### Steps to reproduce

1. Export any report with more than one page.
2. Open the CSV.

### Expected

One header row at the top.

<!-- e22:managed:start -->
## AI synthesis

### Problem

CSV export emits the header row once per page instead of once per file.

### Acceptance criteria

- [ ] Exported CSV contains exactly one header row.
- [ ] Regression test added.
<!-- e22:managed:end -->
