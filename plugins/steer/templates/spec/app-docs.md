# App guide — [Product name]

> **App knowledge documentation**: how to *use* and *operate* this product —
> for product owners, developers, and anyone onboarding. Plain language first;
> implementation detail belongs in `contract.md`s, not here. Claude updates
> (or proposes updates to) these pages **in the same PR** as any behavior
> change that invalidates them — a stale app guide is a drift-gate flag.
>
> For **what this product is and who it serves**, see the root
> [`README.md`](../../README.md) — don't restate its pitch or status here.
> This guide picks up where that leaves off: what a user actually *does* with
> the product. For **developer setup** (toolchain, running the repo locally)
> the root README is also the source of truth — link to it, don't duplicate it.
>
> This file is the index. Start with the sections below inline; split a
> section into its own file in `spec/app/` when it outgrows a page (e.g.
> `spec/app/troubleshooting.md`) and leave a link here. Omit sections that
> genuinely don't apply — don't fill them with boilerplate.

## How to use the app

[Jump straight into the app — don't re-pitch what the product is (that's the
root README). 2–3 sentences of orientation: what a user sees first and where
the main things live. Then one subsection per **major workflow**, written as
steps from the user's perspective.]

### [Workflow name]

1. …

## Roles & permissions

[Who can do what. One row per role; plain language.]

| Role | Can | Cannot |
|---|---|---|
| | | |

## Configuration concepts

[Settings/options a user or admin can change and what they affect — concepts,
not env vars (those live in `.env.example`).]

## Known limitations

[What the product deliberately doesn't do (link `vision.md` → "What this
product is NOT") and current known gaps users will hit.]

## Troubleshooting

[Symptom → likely cause → what to do. Add entries as real issues recur.]

## Operational runbook (dev-facing)

[Only once deployed: how to check health, restart, roll back, where logs and
alerts live, backup/restore. Keep it honest — delete this section while the
product is local-only.]

## Release notes

[Newest first. One short, user-facing entry per release or notable merge —
what changed *for the user*, not the implementation. Move to
`spec/app/release-notes.md` when it outgrows this page.]

### YYYY-MM-DD — [version or milestone]

- …

## Glossary

See [`spec/glossary.md`](../glossary.md) — one shared vocabulary, not a copy.
