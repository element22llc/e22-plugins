## Where things live

E22 products are **internal monorepos**: multiple apps and shared packages in
one repo.

- **`/apps`** — deployable applications (e.g. `apps/web`), each independently
  buildable and deployable (backend placement: see Stack).
- **`/packages`** — shared libraries consumed by apps/packages; not deployed.
- **`/configs`** — shared tooling config (lint, base tsconfig, test presets).
- **`/spec`** — product intent; source of truth for what the product does and
  why. Design exports: `/spec/design` (product) or
  `/spec/features/[id]/design-export/` (feature). Also home to
  `/spec/HISTORY.md` (action history) and `/spec/tracker.md` (issue-tracker
  declaration).
- **`/spec/app`** — app knowledge docs: usage, workflows, roles,
  configuration, limitations, troubleshooting, release notes (PO + dev
  facing).
- **`/spec/decisions`** — ADRs.
- **`/spec/reference`** — source/research materials feeding the spec
  (inventories, vendor metadata, schema/DDL dumps, discovery docs).
- **`/infra`** — AWS infrastructure-as-code and deploy scripts.

Specs are organized by user-facing feature; code however the stack wants — a
feature may span several apps/packages (coupling rules: `/e22-spec-scaffold`).
