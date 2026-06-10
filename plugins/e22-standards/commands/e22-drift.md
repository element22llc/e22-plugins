---
description: Compare the as-built /spec (reverse-engineered by /e22-adopt) against the intended spec exported from an issue tracker (Jira, Linear, GitHub Issues, … as markdown, one file per epic/issue or story/task) to expose drift. Read-only — reports findings and proposes Rule-5 resolutions, opens spec-drift issues, and never edits code or spec.
---

Audit this product for spec drift by following the `e22-drift` skill.

`/e22-drift` consumes what `/e22-adopt` produced: it compares the **as-built
`/spec`** (reverse-engineered from the code) against the **tracker spec**
(intent — exported from any issue tracker: Jira, Linear, GitHub Issues, …). If
there is no `/spec` spine yet, stop and run `/e22-adopt` first — there's nothing
to compare against until the code has been reverse-engineered.

Ask the dev for the tracker spec export if not already given — they either paste
the markdown into the chat or point to a directory of markdown files (one file
per epic/issue or per user story / task). Phase 1: parse the export into
intended-behavior units (fan a coarse-grained epic/issue file out into its
sub-items + acceptance criteria). Phase 2: diff the as-built `/spec` against those
units, classifying each as Matches / Diverged / Missing / Unspecified /
Ambiguous, citing the as-built evidence (the `contract.md` section and its
`path:line` pointer). Output a drift report, a proposed Rule-5 resolution per
finding (noting PO vs dev approval), and open `spec-drift` issues for anything
needing a decision. Make no code or spec edits and do not commit — this is report
+ propose only.
