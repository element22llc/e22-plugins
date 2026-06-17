# Scaffold manifest — plugin-driven repo bootstrap

This directory is the **bundled repository scaffold**: everything a new
product repo needs to be locally operational, carried by the plugin so it is
always current (`/plugin update`) and needs no external template repo. It
replaces the old static `element22llc/repository-template` as the bootstrap
source — see the README's migration notes.

It is consumed by **`/steer:init`** (greenfield bootstrap) and **`/steer:adopt`**
(scaffolding sync into an existing app). Both follow the same discipline:
**copy-and-adapt, never clobber** — if the target file already exists, diff and
reconcile into it instead of overwriting, and adapt stack-specific content
(Python → `uv` task commands, services the product actually needs in
`compose.yaml`) before committing.

## Install map

Dotfiles are stored here **without their leading dot** (so they don't act on
this plugin repo itself); rename on copy as mapped below.

| Bundled path | Install as | Notes |
|---|---|---|
| `README.md` | `README.md` | Product README: status, quickstarts (PO + dev), WSL, CI secret, branch protection. Fill placeholders via `/steer:init`. |
| `CLAUDE.md` | `CLAUDE.md` | Product-specific context only — the org standards are injected by this plugin, never copied in. |
| `DESIGN.md` | `DESIGN.md` | Visual-identity stub. **Never overwrite** a `DESIGN.md` that `/steer:adopt` reverse-engineered or a team populated. |
| `mise.toml` | `mise.toml` | Toolchain + standard tasks (`dev:setup`, `docker:*`, `db:*`). Adapt tasks to the product's stack. |
| `mise.lock` | `mise.lock` | Placeholder — mise only writes the lock if the file exists. `mise install` populates it; commit the result. |
| `compose.yaml` | `compose.yaml` | Local backing services (PostgreSQL baseline). Host ports stay env-overridable (`${POSTGRES_PORT:-5432}`). |
| `package.json` | `package.json` | Root workspace scripts (Node products). Skip for Python-only products. |
| `pnpm-workspace.yaml` | `pnpm-workspace.yaml` | pnpm monorepo + catalog. Skip for Python-only products. |
| `biome.json` | `biome.json` | Lint + format (Node/TS). Python products use Ruff via `pyproject.toml` instead. |
| `env.example` | `.env.example` | Documented variable *names* (never values). Pair with a git-ignored `.env`. |
| `gitignore` | `.gitignore` | Merge into an existing one rather than replacing it. |
| `mcp.json` | `.mcp.json` | GitHub MCP server for local sessions (`${GITHUB_PAT}` via shell, never committed). |
| `claude/settings.json` | `.claude/settings.json` | Enables `steer` + companion plugins; git permission guardrails. Merge if one exists. |
| `vscode/extensions.json` | `.vscode/extensions.json` | Recommended extensions. |
| `vscode/settings.json` | `.vscode/settings.json` | Editor defaults (Biome as formatter). |
| `configs/*` | `configs/*` | Shared tooling config (base tsconfig). |
| `apps/README.md` | `apps/README.md` | What belongs in `/apps`. |
| `packages/README.md` | `packages/README.md` | What belongs in `/packages` (if bundled). |
| `infra/README.md`, `infra/mise.toml`, `infra/mise.lock` | `infra/…` | OpenTofu + Terragrunt conventions; infra toolchain pinned separately. |
| `policy/versions.yml` | `policy/versions.yml` | **Version-pin policy** (approved major-version floors). Enforced deterministically by the version-pin hook and the CI scanner. Seeded from the plugin default; the product may tighten it. |
| `scripts/scan-version-pins.sh` | `scripts/scan-version-pins.sh` | CI version-pin scanner (the committed-state backstop). Shipped so consumer CI runs it without the plugin checked out. Kept byte-identical to the plugin's copy. |
| `scripts/version-policy.sh` | `scripts/version-policy.sh` | Shared policy parser/decider the scanner sources. Verbatim copy of the plugin's `hooks/lib/version-policy.sh`. |

## Spec spine (instantiate from `../spec/`)

The product-level spec artifacts live with the other spec templates in
`templates/spec/`, one home per content type:

| Template | Install as | Notes |
|---|---|---|
| `../spec/vision.md` | `spec/vision.md` | What/who/why/success + product-level `## Open questions`. |
| `../spec/users.md` | `spec/users.md` | Personas and jobs-to-be-done. |
| `../spec/glossary.md` | `spec/glossary.md` | Shared vocabulary. |
| `../spec/design-readme.md` | `spec/design/README.md` | What belongs in `spec/design/` — the design-export home, lifecycle, and brownfield notes. |
| `../spec/design-source.md` | `spec/design/source.md` | Product-level design-source provenance (Greenfield only). |
| `../spec/history.md` | `spec/HISTORY.md` | **Action history** — append-only what/why/who-asked/refs log. |
| `../spec/tracker.md` | `spec/tracker.md` | Which issue tracker this product uses + reference conventions. |
| `../spec/app-docs.md` | `spec/app/README.md` | **App knowledge docs** index — usage, roles, configuration, limitations, troubleshooting, release notes. |
| `spec/features/.gitkeep` | `spec/features/.gitkeep` | Bundled so the dir survives the first commit; `/steer:spec-scaffold` populates it. |
| `spec/decisions/.gitkeep` | `spec/decisions/.gitkeep` | Bundled so the dir survives the first commit; `/steer:adr` populates it. |

The per-feature (`feature-intent.md`, `feature-contract.md` via
`/steer:spec-scaffold`) and per-decision (`adr.md` via
`/steer:adr`) templates also live in `templates/spec/`, but are
instantiated **on demand** by those skills — not copied at bootstrap — so they
are not in this install map.

## GitHub templates (instantiate from `../github/`)

All GitHub templates live in one home, `templates/github/`. The installable
ones are listed here; the agent-authored issue **bodies**
(`../github/issue-bodies/*.md`) are **not** installed — they are read by the
plugin at runtime (`/steer:issues`, `/steer:drift`, `/steer:audit`) to author
issue bodies that satisfy the contract in `reference/ISSUE-SCHEMA.md`. The
YAML Issue **Forms** below are the human capture UI; the two are different
artifacts for different runtimes (see `reference/ISSUE-SCHEMA.md`).

| Template | Install as | Notes |
|---|---|---|
| `../github/workflows/ci.yml` | `.github/workflows/ci.yml` | CI: always-on stack-agnostic hygiene + auto-detected stack checks (Node/Python); a detected stack with no tests fails. |
| `../github/workflows/claude.yml` | `.github/workflows/claude.yml` | `@claude` mention workflow; needs the `ANTHROPIC_API_KEY` repo secret. |
| `../github/pull_request_template.md` | `.github/pull_request_template.md` | Carries the spec-sync, **drift-gate**, and living-docs checklists. |
| `../github/ISSUE_TEMPLATE/*` | `.github/ISSUE_TEMPLATE/*` | PO-friendly YAML Issue Forms — feature, bug, product-question, improvement (+ `config.yml`). Set the GitHub Issue **Type** (`Feature`/`Bug`/`Task`) and carry `source:*`/`needs:*` labels — run `/steer:issues bootstrap-labels` so those labels exist (GitHub silently drops a form label that doesn't), done automatically by `/steer:init` and `/steer:adopt`. Used when GitHub Issues is the tracker; harmless otherwise. `config.yml` ships its contact link **commented out** (no org-specific URL) — offer to enable it and point it at the team's discussions/chat during init/adopt. |

## Deliberately not bundled

- **A starter app** (the old template's `apps/web` + `packages/core`): the
  plugin-driven bootstrap scaffolds the *real* first app for the chosen stack
  instead of shipping a placeholder to delete. `pnpm dev` / `db:migrate` /
  `db:seed` no-op harmlessly until that app exists.
- **Workspace lockfiles** (`pnpm-lock.yaml` / `uv.lock`): generated and
  committed once the real workspace exists (a bundled one would be stale).
- **`/infra` `.hcl`/`.tf` files**: each product provisions when ready —
  `infra/README.md` carries the layout.
