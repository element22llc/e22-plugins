# apps

Deployable services for this product. Each app (e.g. `apps/api`) is
**independently buildable and deployable** — it has its own entry point, build,
and deploy target.

A service repo is headless by default: the deployables here are services —
APIs, workers, schedulers — with no UI app. If the product later grows a real
web UI, that is usually a move to the `app` profile and worth an ADR; the
plugin-injected stack rules cover where a backend belongs (run
`/steer:reference conventions`).

- Put a thing here if it ships on its own. Shared code it depends on lives in
  [`/packages`](../packages/README.md).
- Each app may have its own non-prod surface and deploy target — see
  [`/infra`](../infra/README.md).

Workspace tooling (npm/pnpm/bun workspaces, turbo, nx, …) is the product team's
choice — record it in an ADR under [`/spec/decisions`](../spec/decisions) (run `/steer:adr`). The
toolchain itself is pinned with mise; see [`mise.toml`](../mise.toml).

This folder starts empty — the bootstrap (`/steer:init`) scaffolds the real
first service here instead of shipping a placeholder to delete.

When you add a deployable app here, give it an `apps/<app>/Dockerfile` from the
plugin's `templates/docker/` reference (plus a repo-root `.dockerignore`) — CI
builds it when present. See that directory's README for which template fits your
stack.
