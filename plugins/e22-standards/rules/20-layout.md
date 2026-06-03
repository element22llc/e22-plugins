## Where things live

E22 products are **internal monorepos**: multiple apps and shared packages in
one repo. Top-level layout:

- **`/apps`** — deployable applications (e.g. `apps/web`). Each is independently buildable and deployable. The web app owns its own backend via Next.js (Route Handlers / Server Actions) by default; a separate `apps/api` is the exception (see Stack).
- **`/packages`** — shared libraries consumed by apps or other packages (e.g. `packages/ui`, `packages/core`). Not independently deployed.
- **`/configs`** — shared tooling config (lint, base tsconfig, formatter, test presets).
- **`/spec`** — product intent; source of truth for what this product does and why. Greenfield design exports live under `/spec/design` (product-level) or `/spec/features/[id]/design-export/` (feature-level).
- **`/infra`** — AWS infrastructure-as-code and deploy scripts.
- **`/spec/decisions`** — ADRs, including the workspace-tooling choice.

Specs are organized by user-facing feature; code however the stack wants. A
feature may span several apps/packages. The spec ↔ code coupling rules are
opened by `/e22-spec-scaffold`.
