# Action history — [Product name]

> Append-only log of meaningful changes: what changed, why, who (or what)
> asked for it, and which specs/issues/decisions/code areas were affected.
> Newest entries first. One entry per merged change or ratified decision — not
> per commit. Claude appends the entry in the same PR as the change; the PR
> review is what makes it evidence.
>
> This file exists for auditability (SOC 2 / ISO 27001-**aligned** traceability
> and review evidence), onboarding, reconstructing product decisions, and
> spotting intent drift over time. Keep entries short — 3–6 lines. Detail
> lives in the linked spec/ADR/PR, not here.

## Format

```markdown
## YYYY-MM-DD — [one-line what]
- **Why:** [one line — the problem or request driving it]
- **Requested by:** [@po-handle | @dev-handle | tracker item | adoption/audit finding]
- **Refs:** [tracker ref] · [spec/features/<id>/ or spec/decisions/000N] · [PR #]
- **Areas:** [apps/packages/infra touched, or "spec-only"]
```

## Entries

## YYYY-MM-DD — Repo bootstrapped under E22 standards
- **Why:** [new product | adopted existing app]
- **Requested by:** [@handle]
- **Refs:** [bootstrap PR #]
- **Areas:** scaffolding, /spec
