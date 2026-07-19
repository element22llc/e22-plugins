<!-- steer:inject-when=code-project -->
## Where things live

This layout is the **app** profile: a monorepo of apps + shared packages. A
**library** / **cli** is a single package (no `/apps` split); an **infra** repo
is organized as IaC (`live/` + `modules/`, or Ansible `roles/` + `playbooks/`)
— see Stack. The `/spec` spine is identical across all profiles.

- **`/apps`** — deployable applications (e.g. `apps/web`), each independently
  buildable and deployable (backend placement: see Stack).
- **`/packages`** — shared libraries consumed by apps/packages; not deployed.
- **`/configs`** — shared tooling config (lint, base tsconfig, test presets).
- **`/spec`** — product intent; source of truth for what the product does and
  why. Design exports: `/spec/design` (product) or
  `/spec/features/[id]/design-export/` (feature). Also `/spec/HISTORY.md`
  (action history) and `/spec/tracker.md` (issue-tracker declaration).
- **`/spec/app`** — app knowledge docs: usage, workflows, roles,
  configuration, limitations, troubleshooting, release notes.
- **`/spec/decisions`** — ADRs.
- **`/spec/sources`** — **recurring**, versioned PO source documents,
  maintained by `/steer:intake`.
- **`/spec/reference`** — **one-off** (non-versioned) source/research
  materials feeding the spec. The `/steer:reference` prose is **not** stored
  here — it ships with the plugin.
- **`/infra`** — infrastructure-as-code and deploy scripts.
- **`ARCHITECTURE.md`** (root) — *how it's built*: stack, the apps/packages
  map, how a request flows. `/spec/app` is *how to use/operate it*,
  `/spec/design` holds the *diagrams* it links to, `/spec/decisions` the *why*;
  `README.md` is the front door linking to all of them.

Specs are organized by user-facing feature; code however the stack wants — a
feature may span several apps/packages (coupling rules: `/steer:spec`).
