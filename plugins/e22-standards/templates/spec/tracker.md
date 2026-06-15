---
# Repository-local tracker contract. Read by /e22-tracker-sync and /e22-issues.
# /e22-init resolves the placeholders — never ship fabricated values (a real
# project number here could mutate the wrong GitHub Project).
system:                     # github | jira | linear | azure-devops | other | none-yet
repository:                 # "[owner/repository]" for GitHub; project key or URL otherwise
reference_format:           # "#123" | "PROJ-123" | "ENG-123" | "AB#123"
item_url_pattern:           # e.g. https://example.atlassian.net/browse/{ref}

# --- Optional: GitHub Issues workflow (ignored on other trackers) -----------
# The base workflow needs only authenticated GitHub access + repository above.
# Projects are optional enrichment; leave disabled until one exists.
project:
  enabled: false
  owner:                    # Project owner (org or user login) — numbers are owner-scoped
  number:                   # GitHub Project number, when enabled
workflow:
  issue_is_work_record: true
  spec_is_product_truth: true
  require_tracker_ref_for_features: true
  close_parent_after_product_validation: true
# Labels mirror the canonical e22:source marker (the marker is the source of
# truth; the label is derived/searchable). Kind is the e22:kind marker, not a label.
labels:
  audit: source:audit
  adoption: source:adoption
  security: source:security-review
  code_review: source:code-review
  ci: source:ci
  dependency: source:dependency
  drift: source:spec
  question: source:spec
fields:
  status: Status            # mirrors the e22:state marker (marker is the base source of truth)
  priority: Priority
  effort: Effort
  spec_state: Spec state
---

# Issue tracker — [Product name]

> Declares which external tracker this product uses and how work items are
> referenced everywhere else (specs, PRs, action history). The machine-readable
> contract is the **frontmatter above**; the prose below is the human summary.
> The workflow is **client-agnostic** — any tracker works; only this file knows
> which one. Full conventions: run `/e22-traceability`. GitHub Issues lifecycle:
> see the issue-workflow reference, driven by `/e22-issues`.

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
  or an external owner, then replace the question with the ref.
- **Context preservation:** when work starts from a tracker item, capture its
  acceptance criteria into the feature's `intent.md` rather than leaving them
  only in the tracker — the spec is the in-repo source of truth; the tracker
  ref is the pointer back.

## Notes

[Anything product-specific: components/labels in use, who triages, sync
cadence with `/e22-drift`, …]
