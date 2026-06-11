---
description: Repeatable, read-only, whole-repo health audit of this E22 repo — sweep the code across the standards dimensions, vet each finding against the cited code, rank by leverage (impact ÷ effort × confidence), and route results into /spec + the tracker. Never edits code or spec, never commits. Defers correctness to /code-review and security to /security-review.
---

Audit this repo's health against E22 standards by following the `e22-audit` skill.

`/e22-audit` is the repeatable, steady-state counterpart to `/e22-adopt`: where
adopt builds the `/spec` for a repo that has none, audit runs again and again on
a repo that already has one. It is **whole-repo, multi-dimension, and
leverage-ranked**, and it does **not** re-run the focused review skills — it
defers correctness to `/code-review`, security to `/security-review`, and
mechanical cleanup to `/simplify`, naming them rather than duplicating them.

Phase 0: detect the stack from the repo and decide which dimensions apply; if
there's no `/spec` spine, mark the spec-coverage dimension not-run and redirect
to `/e22-adopt` for it (the code-health dimensions still run). Phase 1: review
each applicable dimension (spec coverage, architecture & boundaries, data layer,
input validation & config, error handling & escape hatches, testing, toolchain &
dependency health, design consistency, DX & docs), every finding carrying
`path:line` evidence and the standard it misses. Phase 2: **vet** — re-read the
cited code for each finding and drop false positives, already-conformant cases,
and duplicates. Phase 3: rank survivors by leverage (impact ÷ effort ×
confidence). Output a leverage-ordered report (noting skipped/not-run
dimensions), open `audit` issues for genuine code-health findings, propose ADRs
(`/e22-adr`) for architectural calls and `## Open questions` entries
(`/e22-questions`) for spec gaps, and offer `/spec/AUDIT-REPORT.md` only if the
dev wants it tracked. Make no code or spec edits and do not commit — this is
report + route only.
