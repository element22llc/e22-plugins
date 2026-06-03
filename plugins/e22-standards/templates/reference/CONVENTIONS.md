# Conventions

Cross-cutting conventions for Element 22 product repos. The always-on rules keep
only pointers; this is the full prose, loaded on demand via `/e22-conventions`.

## Versioning policy

Default to **current stable** versions of all tools, runtimes, frameworks, and
libraries.

- When setting up a new product, pin to the current stable release of each tool
  unless the org has approved a specific baseline.
- When adding a dependency, prefer the current stable major/minor.
- When suggesting a library or framework, check what the current stable version
  is rather than relying on training-data memory.
- Avoid prerelease, beta, or canary versions unless there is a specific reason.
  Note the reason in the relevant ADR or commit message.
- Dependency upgrades are routine work, but they should still be reviewed like
  any other change.
- For existing products, upgrade intentionally and verify with CI and the
  non-prod environment before production.

If you, Claude, are unsure what the current stable version is, say so and ask
the dev to confirm or check a registry. Do not guess.

### Toolchain: `latest` in config, pinned in the lockfile

The toolchain (language runtimes, CLI tools) is managed with **mise**. The
template's `mise.toml` files set every tool to `latest` on purpose — so the
template never carries stale version numbers that someone has to hand-maintain.

Reproducibility comes from the **lockfile**, not from the `mise.toml` value:

- `[settings] lockfile = true` is enabled, so `mise install` writes the exact
  resolved versions to `mise.lock` (one per config dir: root and `infra/`).
- **Commit `mise.lock`.** It is the real pin — CI and every developer machine
  install from it, so they always agree. `latest` in `mise.toml` only decides
  what gets resolved the next time the lock is *regenerated*.
- **First use:** run `mise install` (and `cd infra && mise install`) and commit
  the generated lockfiles. This is the "pin on adoption" step.
- **Bumping:** run `mise upgrade` to move the lock forward, review the diff like
  any other change, and — for infra tools — validate in non-prod before prod.

This keeps the "default to current stable" rule above (you resolve `latest` once,
at adoption) without leaving an unpinned `latest` in any active product.
mise setup steps are in the product README.

## Internal monorepo layout

Code lives at the repo root in three top-level directories:

- **`/apps`** — deployable applications. Each app is independently buildable and
  deployable, with its own deploy target.
- **`/packages`** — shared libraries consumed by apps or other packages. Not
  independently deployed.
- **`/configs`** — shared tooling configuration (lint, base tsconfig, formatter,
  test presets) referenced by apps and packages.

A single product repo may hold multiple apps and packages. The org stays
polyrepo *across* products (SOC2 isolation); the monorepo is internal to this
one product.

## Workspace tooling

These are E22's **default biases**, not mandates — lean toward them, and if a
project warrants a different tool, record the choice as an ADR under
`/spec/decisions`. `mise` still pins the underlying runtimes regardless of which
package manager you use.

- **Node.js → [pnpm](https://pnpm.io).** Use pnpm for installs and for workspaces
  (`pnpm-workspace.yaml`) across `/apps` and `/packages`. Prefer it over npm or
  yarn; don't mix lockfiles in one repo.
- **Python → [uv](https://docs.astral.sh/uv/).** Use uv for environments,
  dependency resolution, and locking (`uv add`, `uv sync`, `uv run`). Prefer it
  over pip/Poetry/pip-tools.

Layered task runners (turbo, nx) remain a per-project call — record them in an
ADR if adopted.

### Linting & formatting

One linter+formatter per language, installed via mise (single fast binaries, so
they fit the lockfile model above):

- **Node / TypeScript → [Biome](https://biomejs.dev).** One tool for both lint
  and format. Prefer it over ESLint + Prettier; don't run them alongside Biome.
  Init per workspace with `biome init`, then `biome check` (lint) and
  `biome format`. Pinned in the root `mise.toml`.
- **Python → [Ruff](https://docs.astral.sh/ruff/).** One tool for both lint
  (`ruff check`) and format (`ruff format`). Prefer it over Flake8 / Black /
  isort. Uncomment `ruff` in the root `mise.toml` for Python products.

These are E22 defaults, not mandates — swap one only with an ADR under
`/spec/decisions`. Wire them into the CI `lint` step (see
`.github/workflows/ci.yml`) once the stack exists so a green `ci` enforces them.

### Testing

One test runner per language:

- **Node / TypeScript → [Vitest](https://vitest.dev).** Use it for unit and
  integration tests across `/apps` and `/packages`; run with `pnpm test`. Prefer
  it over Jest; don't run both in one repo.
- **Python → [pytest](https://docs.pytest.org/).** Run with `uv run pytest`.

Coverage expectations and the "tests in the same PR" rule are in the always-on
Testing rules.

### Auth & error tracking

- **Auth → [Better Auth](https://better-auth.com/)** for the Node/Next.js stack.
  Auth is a high-risk area — scope with the dev and record an ADR before wiring
  it in.
- **Error tracking → [Sentry](https://sentry.io)** for error capture on both
  frontend and backend. Keep DSNs and auth tokens in Secrets Manager — never
  commit them.

## Windows: use WSL

Develop inside **WSL2** (Windows Subsystem for Linux), not native Windows. The
toolchain (mise, uv, pnpm, OpenTofu/Terragrunt) and the shell scripts CI lints
all assume a POSIX environment, so WSL avoids a class of path, line-ending, and
shell-incompatibility issues. Setup steps are in the product README.
