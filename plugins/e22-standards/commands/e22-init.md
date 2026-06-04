---
description: Run the one-time Element 22 first-run setup for a freshly forked template repo (resolve placeholders, pin the toolchain, replace the starter).
---

Run the Element 22 first-run setup for this repository by following the
`e22-init` skill.

Scan the repo for `[Replace …]`, `[Product Name]`, `[e.g., …]`, and
`@github-handle` placeholders. If none remain, tell the dev the template is
already customized and stop. Otherwise, walk the dev through resolving them in
one batch, pinning the toolchain via `mise install` (verifying and committing
the populated `mise.lock` files), and replacing or removing the starter `apps/web` +
`packages/core`. Do not commit until the dev approves.
