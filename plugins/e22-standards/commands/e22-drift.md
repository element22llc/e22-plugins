---
description: Audit the built app against its full spec and a batch of source tickets (pasted or exported) to expose drift. Read-only — reports findings and proposes Rule-5 resolutions, opens spec-drift issues, and never edits code or spec.
---

Audit this product for spec drift by following the `e22-drift` skill.

Ask the dev for the source tickets if not already given — they either paste the
tickets into the chat or point to an export (a Jira CSV/JSON/Markdown dump or a
directory). Phase 1: reconcile those tickets against the `/spec` spine and flag
spec gaps (propose spec additions; do not write them). Phase 2: audit `/apps`
and `/packages` against the spec plus the ticket behaviors, classifying each as
Conforms / Drifted / Missing / Extra / Ambiguous with `path:line` evidence.
Output a drift report, a proposed Rule-5 resolution per finding (noting PO vs
dev approval), and open `spec-drift` issues for anything needing a decision.
Make no code or spec edits and do not commit — this is report + propose only.
