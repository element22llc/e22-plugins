---
name: design-sources
description: Guide to design exports — URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md.
when_to_use: Use when a feature originates from a Claude Design export or URL, Figma, or screenshots.
---

# Design-sources reference

Read the full design-sources walkthrough bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/DESIGN-SOURCES.md`

Key points (read the file for the full detail):

- **Most features have no export, or only a partial one — that is normal.** A
  committed export is one useful input; its absence is not a blocker. The
  constant across every path is the product's `DESIGN.md` (below).
- A **Claude Design URL** is a human-only traceability link — Claude **cannot**
  fetch it (it returns `403`). The **local committed export** (ZIP/HTML) is what
  you actually read.
- Where artifacts live: Greenfield product-level → `spec/design/`; feature-level
  → `spec/features/[id]/design-export/` and the `intent.md` `Design source`
  section.
- Read only what's visible (screens, flows, components, copy, states). **Do not
  invent** business rules, permissions, backend behavior, data models, or
  validation — anything not visible goes to the feature's `intent.md` →
  `## Open questions`.
- The design is authoritative for **visual behavior and flow**; the spec is
  authoritative for **what the system does**. Conflicts → the feature's
  `intent.md` → `## Open questions`.
- The export is a **spec to realize in the standard stack, not code to ship**.
  Rebuild the UI (Next.js + TS + Tailwind); the prototype's delivery tech (UMD
  React, in-browser Babel, hand-rolled CSS) is disposable. Serving the prototype
  runtime as a maintained surface is an **ADR-gated, kill-dated exception** — see
  "Realizing the design vs. serving the prototype" in the reference.
- **No / partial export (the common case):** build the UI deliberately, not in
  generic AI defaults. Use the **`frontend-design`** plugin re-listed in this
  marketplace (`/plugin install frontend-design@e22-plugins`) for the craft
  layer — scoped to a professional/enterprise default, the standard stack
  (Next + TS + Tailwind), and accessibility. It fills gaps; it never overrides a
  screen a committed export already designed.
- Reusable product-wide UI rules live in the product's `DESIGN.md` — populated
  as you build (third origin: established while building without an export) so
  every feature stays uniform; feature-specific details stay in the feature's
  `intent.md`.
