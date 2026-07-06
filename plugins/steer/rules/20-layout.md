<!-- steer:inject-when=code-project -->
## Where things live

The layout below is the **app** profile: an internal monorepo with multiple apps
and shared packages in one repo. A **library** / **cli** is a single package (no
`/apps` split); an **infra** repo is organized as IaC (`live/` + `modules/`, or
Ansible `roles/` + `playbooks/`) — see Stack — infrastructure. The `/spec` spine
is identical across all profiles.

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
- **`/spec/sources`** — versioned home for **recurring** PO source documents that
  arrive in successive versions, maintained by `/steer:intake`.
- **`/spec/reference`** — **one-off** (non-versioned) source/research materials
  feeding the spec (inventories, vendor metadata, schema/DDL dumps, discovery
  docs). The `/steer:reference` prose is **not** stored here — it ships with the
  plugin and is loaded on demand via `/steer:reference`. Contrast `/spec/sources`
  (recurring, versioned) and `/spec/design` (UI/design exports).
- **`/infra`** — AWS infrastructure-as-code and deploy scripts.
- **`ARCHITECTURE.md`** (root) — system-architecture + tech-stack overview, the
  engineer's system model: stack, the apps/packages map, how a request flows.
  Distinct audiences — `ARCHITECTURE.md` is *how it's built*, `/spec/app` is *how
  to use/operate it*, `/spec/design` holds the *diagrams* `ARCHITECTURE.md` links
  to, and `/spec/decisions` holds the *why* (ADRs). `README.md` is the front door
  and links to all of them.

Specs are organized by user-facing feature; code however the stack wants — a
feature may span several apps/packages (coupling rules: the spec workflow,
`/steer:spec`).
