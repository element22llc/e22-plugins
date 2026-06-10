---
description: One-time E22 setup for a new repo — resolve template placeholders, or bootstrap the /spec spine + scaffolding for a non-template greenfield repo; pin the toolchain and leave it working spec-first.
---

Run the Element 22 first-run setup for this repository by following the
`e22-init` skill. Detect which entry condition applies:

- **Freshly forked template** — `[Replace …]`, `[Product Name]`, `[e.g., …]`, or
  `@github-handle` placeholders remain. Walk the dev through resolving them in
  one batch, pinning the toolchain via `mise install` (verifying and committing
  the populated `mise.lock` files), and replacing or removing the starter
  `apps/web` + `packages/core`.
- **Non-template greenfield** — no `/spec` spine, no placeholders, and you're
  building from scratch. Bring in the spine (`vision.md`/`users.md`/`glossary.md`)
  and scaffolding from `element22llc/repository-template`, interview to fill the
  spine (ask, don't invent), record the initial stack as an ADR, pin the
  toolchain, then proceed spec-first (`/e22-spec-scaffold` per feature).

If the repo has substantial pre-existing code but no `/spec` (reverse-engineering
a vibe-coded app), stop and use `/e22-adopt` instead. If `/spec` already exists
and no placeholders remain, say setup has run and stop. Do not commit until the
dev approves.
