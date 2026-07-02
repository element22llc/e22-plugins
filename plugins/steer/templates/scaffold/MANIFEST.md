# Scaffold manifest — plugin-driven repo bootstrap

This directory is the **bundled repository scaffold**: everything a new
product repo needs to be locally operational, carried by the plugin so it is
always current (`/plugin update`) and needs no external template repo. It
replaces the old static `element22llc/repository-template` as the bootstrap
source.

It is consumed by **`/steer:init`** (greenfield bootstrap) and **`/steer:adopt`**
(scaffolding sync into an existing app). Both follow the same discipline:
**copy-and-adapt, never clobber** — if the target file already exists, diff and
reconcile into it instead of overwriting, and adapt stack-specific content
(Python → `uv` task commands, services the product actually needs in
`compose.yaml`) before committing.

The capability-critical subset of these rows is additionally tracked by
[`../reference/CAPABILITIES.md`](../reference/CAPABILITIES.md), which
**`/steer:sync`** walks on every sync to repair *missing or mis-wired* wiring in
already-adopted repos (whole-file presence + wiring — the gap additive
reconciliation can't reach). When a migration moves a capability file, update its
path in both this map and that file in the same change.

## Install map — Layer 0 (Core)

**Core is profile-agnostic: every profile installs all of it.** Dotfiles are
stored here **without their leading dot** (so they don't act on this plugin repo
itself); rename on copy as mapped below. The Node project files and per-type
structure live in **profile overlays** (Layer 1 / Layer 2) — see below.

| Bundled path | Install as | Notes |
|---|---|---|
| `README.md` | `README.md` | Product README: status, quickstarts (PO + dev), WSL, CI secret, branch protection. Fill placeholders via `/steer:init`. |
| `CLAUDE.md` | `CLAUDE.md` | Product-specific context only — the org standards are injected by this plugin, never copied in. |
| `ARCHITECTURE.md` | `ARCHITECTURE.md` | System-architecture + tech-stack overview (the engineer's system model). Auto-populated by `/steer:init`, reverse-engineered by `/steer:adopt`; drift-gated. **Never overwrite** an `ARCHITECTURE.md` that `/steer:adopt` reverse-engineered or a team populated. |
| `mise.toml` | `mise.toml` | Toolchain (`node`/`python`/`uv` pinned — **mandatory for agent tooling**) + standard tasks (`dev:setup`, `docker:*`, `db:*`). Adapt tasks to the product's stack (`library`/`cli` prune `docker:*`/`db:*`). No `mise.lock` ships — `/steer:init`/`/steer:adopt` create and commit it (`touch mise.lock`, `mise install`, `mise lock --platform linux-x64,macos-arm64`). Until then CI installs unlocked; never commit an empty lock. **`infra` substitutes `profiles/infra/mise.toml`** (Layer 2). |
| `compose.yaml` | `compose.yaml` | Local backing services (PostgreSQL baseline). **Core for every profile** — the containerize-by-default nudge (run services in Docker, not on the host). Host ports stay env-overridable (`${POSTGRES_PORT:-5432}`). An `infra` repo with no local services may delete it. |
| `env.example` | `.env.example` | Documented variable *names* (never values). Pair with a git-ignored `.env`. |
| `gitignore` | `.gitignore` | Merge into an existing one rather than replacing it — reconcile additively with `scripts/scaffold_reconcile.py` (never removes a repo's own lines). |
| `worktreeinclude` | `.worktreeinclude` | Git-ignored local config (`.env*`, `.mise.local.toml`, `.claude/settings.local.json`) Claude Code copies into each `claude --worktree` — worktrees start from git refs only, so without this the app can't boot there. Merge additively if one exists; never add regenerable caches/virtualenvs. |
| `claude/settings.json` | `.claude/settings.json` | Enables `steer` + companion plugins; git permission guardrails. If one exists, merge additively with `scripts/scaffold_reconcile.py` (unions permission lists / plugins, never overwrites an existing value). The `Bash(git add*.env)` deny is deliberately narrow: `.env.local` / `.env.*.local` variants are already covered by the scaffold `.gitignore` plus the `git add -f` / `--force` denies, so the glob is **not** widened to `.env.*` (which would re-block the committed `.env.example`). |
| `vscode/extensions.json` | `.vscode/extensions.json` | Recommended extensions. |
| `vscode/settings.json` | `.vscode/settings.json` | Editor defaults (Biome as formatter). |
| `aislop/config.yml` | `.aislop/config.yml` | Scopes the **advisory `ai-slop` CI job** (`.github/workflows/ci.yml`): keeps the differentiated `ai-slop/*` rules on, turns down the security/complexity rules that duplicate the `ci` job's ruff/bandit/Biome/audit gates. Tune or delete to taste; promote the gate to blocking via the commented `ci.failBelow`. |
| `infra/README.md`, `infra/mise.toml` | `infra/…` | Conditional: a nested `/infra` dir inside a monorepo (OpenTofu + Terragrunt conventions; infra toolchain pinned separately — create `infra/mise.lock` at pin time, same as the root). Distinct from the `infra` *profile* (whose root mise is `profiles/infra/mise.toml`). |
| `policy/versions.yml` | `policy/versions.yml` | **Version-pin policy** (approved major-version floors). Enforced deterministically by the version-pin hook and the CI scanner. Seeded from the plugin default; the product may tighten it. |
| `policy/branch-protection.yml` | `policy/branch-protection.yml` | **Branch-protection policy** (the GitHub-side PR gate `main` must enforce). Read by `/steer:protect`, which diffs it against the repo's live settings and applies the gap on confirmation. Seeded from the plugin default; the product may tighten it. |
| `scripts/scan-version-pins.sh` | `scripts/scan-version-pins.sh` | CI version-pin scanner (the committed-state backstop). Shipped so consumer CI runs it without the plugin checked out. Kept byte-identical to the plugin's copy. |
| `scripts/version-policy.sh` | `scripts/version-policy.sh` | Shared policy parser/decider the scanner sources. Verbatim copy of the plugin's `hooks/lib/version-policy.sh`. |
| `scripts/worktree-env.sh` | `scripts/worktree-env.sh` | **Core for every profile** (pairs with `compose.yaml`). Sourced by `mise.toml` (`[env]._.source`): gives each Claude Code worktree a unique `COMPOSE_PROJECT_NAME` + a stable per-worktree host-port offset (`POSTGRES_PORT`, `WEB_PORT`, `DATABASE_URL`) so parallel agents don't collide on Docker/ports. Primary checkout = offset 0 (ports unchanged). Adapt the BASELINE block to the product's services. |

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
| `../spec/design-architecture.md` | `spec/design/architecture.md` | The living, global architecture diagram (Mermaid by default; opt-in LikeC4) that `ARCHITECTURE.md` links to. |
| `../spec/history.md` | `spec/HISTORY.md` | **Action history** — append-only what/why/who-asked/refs log. |
| `../spec/tracker.md` | `spec/tracker.md` | Which issue tracker this product uses + reference conventions. |
| `../spec/app-docs.md` | `spec/app/README.md` | **App knowledge docs** index — usage, roles, configuration, limitations, troubleshooting, release notes. |
| `../spec/sources-readme.md` | `spec/sources/README.md` | What belongs in `spec/sources/` — the versioned home for recurring PO documents, maintained by `/steer:intake`. |
| `spec/features/.gitkeep` | `spec/features/.gitkeep` | Bundled so the dir survives the first commit; `/steer:spec-scaffold` populates it. |
| `spec/decisions/.gitkeep` | `spec/decisions/.gitkeep` | Bundled so the dir survives the first commit; `/steer:adr` populates it. |

Six more `templates/spec/` templates also live there but are instantiated **on
demand** by their skills — not copied at bootstrap — so they are not in this
install map: `feature-intent.md` + `feature-contract.md` (`/steer:spec-scaffold`),
`adr.md` (`/steer:adr`), `build-status.md` + `productionization.md`
(`/steer:build`), and `source-manifest.md` (`/steer:intake`).

## GitHub templates (instantiate from `../github/`)

All GitHub templates live in one home, `templates/github/`. The installable
ones are listed here; the agent-authored issue **bodies**
(`../github/issue-bodies/*.md`) are **not** installed — they are read by the
plugin at runtime (`/steer:issues`, `/steer:audit spec`, `/steer:audit`) to author
issue bodies that satisfy the contract in `reference/ISSUE-SCHEMA.md`. The
YAML Issue **Forms** below are the human capture UI; the two are different
artifacts for different runtimes (see `reference/ISSUE-SCHEMA.md`). The optional
gh-aw agentic workflow under `../github/agentic/` (e.g. `triage.md`) is **not
installed** by `/steer:init` or `/steer:adopt` — opt in deliberately per the docs
(GitHub → "Agentic workflows (gh aw)").

| Template | Install as | Notes |
|---|---|---|
| `../github/workflows/ci.yml` | `.github/workflows/ci.yml` | CI: always-on stack-agnostic hygiene + auto-detected stack checks (Node/Python); a detected stack with no tests fails. |
| `../github/dependabot.yml` | `.github/dependabot.yml` | Dependabot config — `github-actions` ecosystem live; `npm`/`pip`/`docker` blocks commented out for `/steer:init`/`/steer:adopt` to uncomment per detected stack. Groups updates and `ignore`s majors (deferred to a `policy/versions.yml` decision). |
| `../github/workflows/dependabot-auto-merge.yml` | `.github/workflows/dependabot-auto-merge.yml` | Auto-approves + auto-merges Dependabot **patch/minor** PRs once the required `ci` check is green; **majors are left for a human**. The documented exception to the human-review gate — see scaffold `README.md` → branch-protection and `policy/branch-protection.yml`. Scoped to Dependabot by the workflow's `dependabot[bot]` guard; does **not** enable GitHub's repo-wide `allow_auto_merge`. |
| `../github/workflows/claude.yml` | `.github/workflows/claude.yml` | `@claude` mention workflow; **loads the `steer` plugin in CI** (via the action's `plugins`/`plugin_marketplaces` inputs) so in-CI Claude runs under the same standards as local. Needs the `ANTHROPIC_API_KEY` secret; the marketplace repo is public, so the plugin clone is anonymous and needs no credential — see scaffold `README.md` → GitHub Actions secrets. |
| `../github/copilot-instructions.md` | `.github/copilot-instructions.md` | **GitHub Copilot standards surface (CLI + VS Code).** The org standards as Copilot's always-on custom instructions — Copilot has no context-injecting SessionStart hook, so the rules ship as a static file instead. Read natively by both the Copilot CLI and Copilot in VS Code. **Generated** from `plugins/steer/rules/` (via `mise run gen:copilot`); **fully steer-managed — overwrite on refresh, never hand-edit** (put repo-specific Copilot guidance in a separate `*.instructions.md`). Harmless for Claude-only repos. Refresh after a plugin update by re-running `/steer:init`. |
| `../github/prompts/*.prompt.md` | `.github/prompts/*.prompt.md` | **GitHub Copilot skill surface (esp. VS Code).** One prompt file per user-invocable steer skill, surfaced in Copilot Chat as `/steer-<skill>` slash-commands (the VS Code analog to the skills the Copilot **CLI** loads via its plugin manifest). **Generated** from `plugins/steer/skills/` (via `mise run gen:copilot`); **fully steer-managed — overwrite on refresh, never hand-edit**. Harmless for Claude-only repos. Refresh after a plugin update by re-running `/steer:init`. |
| `../github/pull_request_template.md` | `.github/pull_request_template.md` | Carries the spec-sync, **drift-gate**, and living-docs checklists. |
| `../github/ISSUE_TEMPLATE/*` | `.github/ISSUE_TEMPLATE/*` | PO-friendly YAML Issue Forms — feature, bug, product-question, improvement (+ `config.yml`). Set the GitHub Issue **Type** (`Feature`/`Bug`/`Task`) and carry `source:*`/`needs:*` labels — run `/steer:issues bootstrap-labels` so those labels exist (GitHub silently drops a form label that doesn't), done automatically by `/steer:init` and `/steer:adopt`. Used when GitHub Issues is the tracker; harmless otherwise. `config.yml` ships its contact link **commented out** (no org-specific URL) — offer to enable it and point it at the team's discussions/chat during init/adopt. |

## Profile overlays

A managed repo has a **profile** that decides which stack-specific extras the
bootstrap lays down on top of the universal core (mise pinning, the `/spec`
spine, CI hygiene — installed for *every* profile). The profile is recorded as a
machine-readable marker on the product `CLAUDE.md`'s `## Profile` section —
`<!-- steer:profile=app -->` (or `infra` / `service` / `library` / `cli`),
sibling of the `## Delivery mode` marker. **Absent marker → `app`** (back-compat:
every repo predating profiles was an app monorepo). `/steer:init` and
`/steer:adopt` detect, confirm, and stamp it; `/steer:sync` back-fills `=app`
when missing. Rules do **not** read this marker — always-on rules self-gate on
filesystem *traits* (`has-apps` / `has-compose` / `has-infra` / `has-iac`), so a
repo's rule context always matches what is actually on disk.

The bootstrap applies up to **three additive layers** — each later layer only
*adds* files, never removes (the inverse of the old "install everything, then
omit" model):

- **Layer 0 — Core** (the Install map above): installed for **every** profile.
- **Layer 1 — Node baseline** (`profiles/_node/`): installed for Node-stack
  profiles (`app` / `service` / `library` / `cli`); **skipped for `infra`**, and
  skipped for a Python-only product (use `pyproject.toml`/Ruff instead).
- **Layer 2 — Profile extras** (`profiles/<profile>/`): the recommended
  structure for that project type.

Every Node profile is a **pnpm workspace** (monorepo-by-default) — `library` and
`cli` get `pnpm-workspace.yaml` + `packages/` too, not only `app`/`service`.

### Layer 1 — Node baseline (`profiles/_node/`)

| Bundled path | Install as | Notes |
|---|---|---|
| `profiles/_node/package.json` | `package.json` | Root workspace scripts. The skill adapts per profile (`library`: publishable, drop `private`; `cli`: add `bin`). |
| `profiles/_node/pnpm-workspace.yaml` | `pnpm-workspace.yaml` | Workspace globs + **catalog** (centralized dependency versions). |
| `profiles/_node/biome.json` | `biome.json` | Lint + format — org house style (width 100, double quotes, semicolons as-needed). Python-only products use Ruff via `pyproject.toml` instead. |
| `profiles/_node/configs/*` | `configs/*` | Shared tooling config (base tsconfig). |
| `profiles/_node/packages/README.md` | `packages/README.md` | What belongs in `/packages`. |

### Layer 2 — Profile extras (`profiles/<profile>/`)

| Bundled path | Install as | Profile — notes |
|---|---|---|
| `profiles/app/apps/README.md` | `apps/README.md` | **app** — what belongs in `/apps`. |
| `profiles/app/DESIGN.md` | `DESIGN.md` | **app** — visual-identity stub. **Never overwrite** a populated or `/steer:adopt`-reverse-engineered `DESIGN.md`. |
| `profiles/service/apps/README.md` | `apps/README.md` | **service**. |
| `profiles/infra/mise.toml` | `mise.toml` (repo root) | **infra** — **replaces** core mise (tofu/terragrunt/ansible/uv + the `node` runtime + `compose`/worktree wiring). Skip Layer 1; adapt `ARCHITECTURE.md`/README. CI auto-detects `*.tf`/Ansible and runs `tofu fmt`/`ansible-lint`. |

`library` and `cli` add **no** Layer-2 files — they are Core + Node baseline,
with the skill adapting `package.json` only. A monorepo that *also* has a nested
`/infra` dir stays profile `app` and gets the infra rule fragment + infra CI
automatically because `/infra` exists (trait, not marker) — it does not become
profile `infra`.

## Deliberately not bundled

- **A starter app** (the old template's `apps/web` + `packages/core`): the
  plugin-driven bootstrap scaffolds the *real* first app for the chosen stack
  instead of shipping a placeholder to delete. `pnpm dev` / `db:migrate` /
  `db:seed` no-op harmlessly until that app exists.
- **Workspace lockfiles** (`pnpm-lock.yaml` / `uv.lock`): generated and
  committed once the real workspace exists (a bundled one would be stale).
- **`/infra` `.hcl`/`.tf` files**: each product provisions when ready —
  `infra/README.md` carries the layout.
- **An `.mcp.json`** (GitHub + markitdown MCP servers): these now ship with the
  **plugin itself** (`plugins/steer/.mcp.json`), so every repo that enables steer
  gets them centrally and they refresh on `/plugin update` — no per-repo copy to
  scaffold, drift, or reconcile. A repo may still add its *own* project `.mcp.json`
  for product-specific servers; it merges additively with the plugin's.
