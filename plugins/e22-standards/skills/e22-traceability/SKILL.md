---
name: e22-traceability
description: "Full E22 traceability & living-documentation reference — natural-language-to-spec routing, action history (/spec/HISTORY.md), app knowledge docs (/spec/app/), client-agnostic issue-tracker integration (/spec/tracker.md), pre-merge drift gates, and SOC 2 / ISO 27001-aligned delivery."
when_to_use: Use for any question about living docs, tracker refs, drift flags, audit evidence, or the PO-facing vs dev-facing artifact split.
---

# Element 22 traceability & living-docs reference

Read the full prose bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/TRACEABILITY.md`

It covers, in detail:

- **Living documentation** — the natural-language-to-spec contract: the
  routing table from plain-language statements (goals, decisions, trade-offs,
  questions, validations) to their owning artifacts; extraction discipline
  (extract don't embellish, ask on ambiguity, same-PR updates, propose don't
  stealth-edit); the PO-facing vs dev-facing register split.
- **Action history** — `/spec/HISTORY.md` format and worked entry; what it
  serves (auditability, onboarding, review evidence, decision archaeology,
  drift over time); append-only discipline.
- **App knowledge docs** — `/spec/app/` structure (usage, workflows, roles,
  configuration, limitations, troubleshooting, runbook, release notes) and the
  same-PR update trigger.
- **Issue tracker integration** — the client-agnostic model
  (`/spec/tracker.md` declares; everything else just uses the declared ref
  format), the Jira/GitHub/Linear/Azure DevOps adapter table, where refs live,
  and how untracked questions get promoted.
- **Drift gates** — the eight review-sensitive classes, flag-when-noticed
  mechanics, who may resolve a flag, and the periodic sweeps
  (`/e22-drift`, `/e22-audit`, `/e22-questions`).
- **SOC 2 / ISO 27001-aligned delivery** — "aligned, never compliant" wording,
  and the expectation→artifact evidence map.
- **Worked examples** — a PO's day and a dev's day through the same workflow.

Open that file and answer from it. The lean always-on versions of these rules
are `32-living-docs`, `35-issue-tracker`, `55-drift-gates`, and
`75-compliance` — this reference is their full rationale and how-to.
