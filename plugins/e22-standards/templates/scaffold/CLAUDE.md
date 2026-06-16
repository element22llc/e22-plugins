# Claude Operating Manual — [Product Name]

Element 22's org-wide engineering standards (stack defaults, monorepo layout,
spec workflow, testing rules, Definition of Done, high-risk areas, secrets
handling, change-size model, baseline patterns/anti-patterns, design sources)
are **injected automatically every session** by the **`e22-standards`** plugin
from the `e22-plugins` marketplace — see `.claude/settings.json`. They are maintained
centrally in [`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins)
and update via `/plugin update`, so they are **not** duplicated here. This file
holds only product-specific context.

> **New repo?** Run **`/e22-standards:e22-init`** once to fill the placeholders, pin the
> toolchain, and finish the bootstrap. Remove this line when setup is done.
> Non-technical PO? Type **`/e22-standards:e22-build`** to go from idea to a working local
> app — it runs the first-run setup for you.
>
> On-demand helpers from the plugin: `/e22-standards:e22-spec-scaffold <id>` (new feature
> spec), `/e22-standards:e22-adr <slug>` (architecture decision), `/e22-standards:e22-conventions`,
> `/e22-standards:e22-design-sources`, and `/e22-standards:e22-traceability` (full reference prose). If the
> plugin isn't installed, your teammate will be prompted to install it when
> they trust this folder.

## Product

[Replace with one paragraph: what this product does, who uses it, and what
success looks like. Pull from `/spec/vision.md` once it exists.]

## Stack overrides

The E22 default stack (injected by the plugin) applies unless overridden. Record
any deviation as an ADR under `/spec/decisions/` (run `/e22-standards:e22-adr`) and note it here:

- [none yet — defaults apply]

## Patterns we follow

The E22 baseline (Drizzle/parameterized SQL, Zod-validated boundaries,
server-first, strict typing, …) is injected by the plugin. Add only
product-specific patterns the team learns here.

## Things to avoid

The E22 baseline anti-patterns are injected by the plugin. Add only
product-specific ones discovered here.
