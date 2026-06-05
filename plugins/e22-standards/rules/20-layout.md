## Where things live

E22 products are **internal monorepos**: multiple apps and shared packages in
one repo.

- **`/apps`** — deployable applications (e.g. `apps/web`), each independently
  buildable and deployable (backend placement: see Stack).
- **`/packages`** — shared libraries consumed by apps/packages; not deployed.
- **`/configs`** — shared tooling config (lint, base tsconfig, test presets).
- **`/spec`** — product intent; source of truth for what the product does and
  why. Design exports: `/spec/design` (product) or
  `/spec/features/[id]/design-export/` (feature).
- **`/spec/decisions`** — ADRs.
- **`/infra`** — AWS infrastructure-as-code and deploy scripts.

Specs are organized by user-facing feature; code however the stack wants — a
feature may span several apps/packages (coupling rules: `/e22-spec-scaffold`).
