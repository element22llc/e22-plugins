# Dockerfile reference templates

**On-demand, not bootstrap-installed.** These are the starting-point container
images for a product's **deployable apps**. Unlike the rest of the scaffold, they
are *not* copied into a repo at `/steer:init` time — a fresh repo has no app yet,
and a Dockerfile with nothing to build would ship broken. They are instantiated
**when the first deployable app is created** and then owned by the product, the
same way `compose.yaml` is adapted per repo.

## Which profiles get one

Only **`app`** and **`service`** — the profiles that deploy as containers (default
target: AWS ECS). **`library`** and **`cli`** publish to package registries and
**`infra`** provisions cloud resources, so none of them get a Dockerfile.

## Where it lands

In a pnpm monorepo each `apps/<app>/` is independently deployable, so:

- The Dockerfile installs at **`apps/<app>/Dockerfile`** (one per deployable app).
- `.dockerignore` installs at the **repo root** — the build context is the repo
  root (`docker build -f apps/<app>/Dockerfile .`) so the lockfile and workspace
  `packages/` are in scope.

## When it is instantiated

- **`/steer:build`** — when it scaffolds the real first app (step 5).
- **`/steer:adopt`** — Phase 10, for an already-deployable app that has no
  Dockerfile (copy-and-adapt, never clobber an existing one).
- **Spec-first work** — when a feature adds the first `apps/<app>`, add its
  Dockerfile from here (the `apps/README.md` scaffold points here).

## Pick by stack

| Template | Stack | Notes |
|---|---|---|
| `Dockerfile.node` | Node / Next.js (the default) | Multi-stage; requires `output: "standalone"` + `outputFileTracingRoot` set to the repo root in `next.config`. Set the `APP` build arg to the app dir. |
| `Dockerfile.python` | Python / FastAPI + uv | Multi-stage `uv sync --frozen`; point the CMD at the app's ASGI entry point. |

## Base-image pinning

The `FROM` major must satisfy `policy/versions.yml` (today: `node >= 22`,
`python >= 3.10`) — the version-pin scanner and hook enforce it in CI and locally.
Keep it in sync with `mise.toml`'s runtime pin; a deliberately older base needs an
ADR plus `# steer:allow-pin <reason>` on the `FROM` line.

## CI

The scaffold `.github/workflows/ci.yml` **builds every `apps/*/Dockerfile` (and a
root `Dockerfile`, if any) when present** — build-only, no registry push, no
credentials. That is what keeps an instantiated Dockerfile from rotting. When no
Dockerfile exists the step is skipped with a notice, so a green `ci` never falsely
implies an image built. Pushing/deploying the image is a per-app concern (confirm
the target per app) and lives outside this stack-agnostic CI.
