---
# Repository-local tracker contract. Read by /steer:tracker-sync and /steer:issues.
# /steer:init resolves the placeholders — never ship fabricated values.
system:                     # github | jira | linear | azure-devops | other | none-yet
repository:                 # "[owner/repository]" for GitHub; project key or URL otherwise
reference_format:           # "#123" | "PROJ-123" | "ENG-123" | "AB#123"
item_url_pattern:           # e.g. https://example.atlassian.net/browse/{ref}

# --- Optional: GitHub Issues workflow (ignored on other trackers) -----------
# The base workflow needs only authenticated GitHub access + repository above.
workflow:
  issue_is_work_record: true
  spec_is_product_truth: true
  require_tracker_ref_for_features: true
  close_parent_after_product_validation: true
# Labels mirror the canonical steer:source marker (the marker is the source of
# truth; the label is derived/searchable). Kind is the steer:kind marker, not a label.
labels:
  audit: source:audit
  adoption: source:adoption
  security: source:security-review
  code_review: source:code-review
  ci: source:ci
  dependency: source:dependency
  drift: source:spec
  question: source:spec

# Owners — maps a spec question's `owner:` role to a GitHub assignee (login).
# Used when /steer:questions promotes a question to a spec-question issue: the
# question's `owner:` resolves to the login(s) here and the issue is assigned.
# `shared` is not a row — it resolves to product + development together.
# Leave a row blank to skip auto-assignment for that role (the issue is left
# unassigned and gets `needs:triage` instead). Never fabricate a login.
owners:
  product:        # @login of the product owner / PO
  development:    # @login of the dev lead
  design:         # @login (optional)
  security:       # @login (optional)
---

# Issue tracker — [Product name]

> Declares which external tracker this product uses and how work items are
> referenced everywhere else (specs, PRs, action history). The machine-readable
> contract is the **frontmatter above**; the prose below is the human summary.
> The workflow is **client-agnostic** — any tracker works; only this file knows
> which one. Full conventions: run `/steer:traceability`. GitHub Issues lifecycle:
> see the issue-workflow reference, driven by `/steer:issues`.

## Conventions (summary)

- **Specs:** each feature's `intent.md` carries its tracker ref(s) in the
  header (`> Tracker:`); a feature with no tracked item yet says `none yet`.
- **PRs:** the description references the tracker item using `reference_format`
  above (use the tracker's auto-linking/closing syntax where it has one).
- **Action history:** every `/spec/HISTORY.md` entry lists the tracker ref in
  its `Refs:` line when one exists.
- **Unresolved product questions** that are *not yet* tracked externally live
  in the owning spec's `## Open questions` (feature `intent.md`, or `vision.md`
  for product-level) — promote one to a tracker item when it needs scheduling
  or an external owner, then replace the question with the ref. A **blocking**
  question still open after 14 days is escalated by the SessionStart hook so it
  can't rot unseen; promotion routes it to a named human via the **Owners map**.
- **Owners map (`owners:` frontmatter):** maps a question's `owner:` role
  (`product`/`development`/`design`/`security`) to a GitHub login. On promotion,
  `/steer:questions` assigns the `spec-question` issue to the mapped login;
  `owner: shared` assigns product **and** development; a blank/missing row leaves
  the issue unassigned with `needs:triage`. Fill it once per repo so escalated
  questions land on a person, not a backlog.
- **Context preservation:** when work starts from a tracker item, capture its
  acceptance criteria into the feature's `intent.md` rather than leaving them
  only in the tracker — the spec is the in-repo source of truth; the tracker
  ref is the pointer back.

## Notes

[Anything product-specific: components/labels in use, who triages, sync
cadence with `/steer:drift`, …]
