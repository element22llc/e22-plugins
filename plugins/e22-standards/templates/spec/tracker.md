# Issue tracker — [Product name]

> Declares which external tracker this product uses and how work items are
> referenced everywhere else (specs, PRs, action history). The workflow is
> **client-agnostic**: any tracker works; only this file knows which one.
> Full conventions: run `/e22-traceability`.

## Tracker

- **System:** [Jira | GitHub Issues | Linear | Azure DevOps | other | none yet]
- **Project/board:** [key or URL, e.g. `PROJ`, `org/repo/issues`, team key]
- **Reference format:** [`PROJ-123` | `#123` | `ENG-123` | `AB#123`]
- **Item URL pattern:** [e.g. `https://example.atlassian.net/browse/{ref}`]

## Conventions (summary)

- **Specs:** each feature's `intent.md` carries its tracker ref(s) in the
  header (`> Tracker:`); a feature with no tracked item yet says `none yet`.
- **PRs:** the description references the tracker item using the format above
  (use the tracker's auto-linking/closing syntax where it has one).
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
