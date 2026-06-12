# apps

Deployable applications for this product. Each app (e.g. `apps/web`) is
**independently buildable and deployable** — it has its own entry point, build,
and deploy target.

By default the UI web app (`apps/web`, Next.js) **owns its own backend** via
Route Handlers / Server Actions / server-side data fetching — don't add a
separate `apps/api` for it. A standalone API app is the exception, warranted
only by a non-web consumer, independent scaling/deploy, or a different runtime
(e.g. Python + FastAPI); record that split as an ADR. See the `Stack` section in
[`CLAUDE.md`](../CLAUDE.md).

- Put a thing here if it ships on its own. Shared code it depends on lives in
  [`/packages`](../packages/README.md).
- Each app may have its own non-prod surface and deploy target — see
  [`/infra`](../infra/README.md).
- An app may carry its own `apps/<app>/DESIGN.md` if it has a distinct visual
  identity; otherwise the root [`DESIGN.md`](../DESIGN.md) is the shared default.

Workspace tooling (npm/pnpm/bun workspaces, turbo, nx, …) is the product team's
choice — record it in an ADR under [`/spec/decisions`](../spec/decisions) (run `/e22-adr`). The
toolchain itself is pinned with mise; see [`mise.toml`](../mise.toml).

This folder starts empty — the bootstrap (`/e22-init`) scaffolds the real
first app here (default frontend: Next.js) instead of shipping a placeholder
to delete.
