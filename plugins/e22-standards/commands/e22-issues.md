---
description: "High-level GitHub Issues lifecycle for the /spec spine — capture, triage, brainstorm, materialize, decompose, status, and bounded reconcile. A thin orchestrator over /e22-tracker-sync that delegates spec/audit/drift/question reasoning to their skills. Agent issues follow the machine-readable contract; /spec stays product truth."
---

Drive the GitHub Issues lifecycle for this product's `/spec` spine by following
the `e22-issues` skill.

First read `/spec/tracker.md`: if the tracker is **not** GitHub Issues, say so and
stop (the manual flows in `/e22-tracker-sync` apply). Otherwise detect capability
through `/e22-tracker-sync` (MCP → `gh` → manual) and say which path you took.
Then run the requested mode:

- **capture** — open an issue from the conversation/prototype/screenshot/design
  source, rendering the matching form's semantic fields into the machine-readable
  body (never submit a Form).
- **triage [#N|--all]** — dedup, classify, label, suggest routing + next state.
- **brainstorm #N** — product discovery in the issue (one editable AI-synthesis
  comment); no spec written yet.
- **materialize #N** — `/e22-spec` writes/updates `intent.md` as `Status:
  proposed` (never approved), links the issue, runs `/e22-spec validate`, opens a
  PR, and comments the spec path back.
- **decompose #N** — implementation sub-issues from an **approved** intent
  (native sub-issues, else `Parent: #N` fallback); `--prototype` for pre-approval.
- **status [#N|feature-id]** — unified issue + intent/contract + sub-issue
  progress + blockers view (runs validate).
- **reconcile #N|feature-id|--all** — bounded (one issue/feature) or repo-wide
  reconcile; enforce the question-reconciliation floor; never auto-resolve drift
  or product decisions.
- **bootstrap-labels** — idempotently create/reconcile the `source:*` /
  `needs:*` / `risk:*` label taxonomy (`gh label create --force`) so Issue Forms
  and agent labels actually apply. Run by `/e22-init` and `/e22-adopt`.
- **project [bootstrap|sync]** — optional GitHub Project enrichment, gated on
  `project.enabled` + `owner` + `number`. `bootstrap` creates/reconciles fields +
  options and **outputs manual view-creation steps** (`gh` cannot create saved
  views); `sync` discovers field/option IDs at runtime, adds the issue if absent,
  mirrors `e22:state` → `Status`. Degrades gracefully when Projects/org fields or
  the `project` scope are unavailable.
- **publish-audit / publish-drift** — file the audit-run+findings / decision-
  checklist drift issues from `/e22-audit` / `/e22-drift`. Audits **reconcile**
  across runs (stable `finding-key`), never duplicate.

All GitHub reads/writes route through `/e22-tracker-sync`. Issue updates touch
only the `e22:managed` block (human content preserved); creates are idempotent
(find-by-marker) and need one confirmation. Never edit `/apps`, `/packages`, or
`contract.md` behavior. References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`,
`spec-framework.md`.
