---
description: One-time E22 setup for a new repo — bootstrap the /spec spine + repo scaffolding from the plugin's bundled scaffold (or resolve placeholders in a legacy template fork); pin the toolchain and leave it working spec-first.
---

Run the Element 22 first-run setup for this repository by following the
`e22-init` skill. Detect which entry condition applies:

- **Plugin-driven bootstrap (default for new repos)** — no `/spec` spine, no
  placeholders, and you're building from scratch. Instantiate the bundled
  scaffold (`${CLAUDE_PLUGIN_ROOT}/templates/scaffold/` per its `MANIFEST.md`)
  and the spec spine + living-docs artifacts from
  `${CLAUDE_PLUGIN_ROOT}/templates/spec/` (`vision.md`/`users.md`/`glossary.md`,
  `/spec/HISTORY.md`, `/spec/tracker.md`, `/spec/app/README.md`), interview to
  fill the spine and tracker (ask, don't invent), record the initial stack as
  an ADR, pin the toolchain, then proceed spec-first (`/e22-spec-scaffold` per
  feature). No external template repo is fetched.
- **Legacy template fork** — `[Replace …]`, `[Product Name]`, `[e.g., …]`, or
  `@github-handle` placeholders remain. Walk the dev through resolving them in
  one batch, pinning the toolchain via `mise install` (verifying and committing
  the populated `mise.lock` files), replacing or removing the starter
  `apps/web` + `packages/core`, and back-filling the newer living-docs
  artifacts the old template lacked.

If the repo has substantial pre-existing code but no `/spec` (reverse-engineering
a vibe-coded app), stop and use `/e22-adopt` instead. If `/spec` already exists
and no placeholders remain, say setup has run and stop. Do not commit until the
dev approves.
