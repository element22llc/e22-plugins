---
name: e22-design-sources
description: E22 guide to design exports — URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md. Use when a feature originates from a Claude Design export/URL, Figma, or screenshots.
---

# Element 22 design-sources reference

Read the full design-sources walkthrough bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/DESIGN-SOURCES.md`

Key points (read the file for the full detail):

- A **Claude Design URL** is a human-only traceability link — Claude **cannot**
  fetch it (it returns `403`). The **local committed export** (ZIP/HTML) is what
  you actually read.
- Where artifacts live: Greenfield product-level → `spec/design/`; feature-level
  → `spec/features/[id]/design-export/` and the `intent.md` `Design source`
  section.
- Read only what's visible (screens, flows, components, copy, states). **Do not
  invent** business rules, permissions, backend behavior, data models, or
  validation — anything not visible goes to `/spec/SPEC-QUESTIONS.md`.
- The design is authoritative for **visual behavior and flow**; the spec is
  authoritative for **what the system does**. Conflicts → `/spec/SPEC-QUESTIONS.md`.
- The export is a **spec to realize in the standard stack, not code to ship**.
  Rebuild the UI (Next.js + TS + Tailwind); the prototype's delivery tech (UMD
  React, in-browser Babel, hand-rolled CSS) is disposable. Serving the prototype
  runtime as a maintained surface is an **ADR-gated, kill-dated exception** — see
  "Realizing the design vs. serving the prototype" in the reference.
- Reusable product-wide UI rules live in the product's `DESIGN.md`;
  feature-specific details stay in the feature's `intent.md`.
