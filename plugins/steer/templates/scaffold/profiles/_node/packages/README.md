# packages

Shared libraries consumed by the repo's apps (in profiles that ship an `/apps`
layer) or by other packages (e.g. `packages/ui`, `packages/core`,
`packages/types`). Packages are **not independently deployed** — they ship as
part of whatever depends on them.

- Put a thing here if more than one app needs it, or to keep an app's internals
  factored. If it ships on its own, it's an app, not a package.
- Shared tooling config (lint, tsconfig, formatter, test presets) lives in
  [`/configs`](../configs/README.md), not here.

Workspace tooling is the product team's choice — record it in an ADR under
[`/spec/decisions`](../spec/decisions) (run `/steer:adr`).
