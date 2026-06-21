# [Product Name]

> Replace this section after bootstrapping the repo (`/steer:init`).

One-sentence description of what this product does and who it serves.

## Status

- **Mode:** Greenfield | Brownfield  (delete one)
- **Production:** Not yet deployed | Live at [URL]
- **PO:** @github-handle
- **Devs:** @github-handle, @github-handle

## How this repo works

This repo follows a shared workflow across all our products. It's an **internal
monorepo** — multiple apps and shared packages live in this one product repo
(the org stays polyrepo *across* products):

- **`/spec`** is the product spine. It describes what this product does and why. Read this first.
- **`/apps`** holds deployable applications (e.g. `apps/web`) — each independently buildable and deployable. The Next.js web app owns its own backend (Route Handlers / Server Actions) by default; a separate `apps/api` is the exception.
- **`/packages`** holds shared libraries consumed by apps or other packages — not independently deployed.
- **`/configs`** holds shared tooling config (lint, base tsconfig, formatter, test presets).
- **`/infra`** holds AWS infrastructure-as-code, provisioned with **OpenTofu** + **Terragrunt**.
- **`CLAUDE.md`** is the operating manual for Claude when working in this repo.

Defaults for package managers: **pnpm** for Node, **uv** for Python (rationale
via the `steer` plugin — run `/steer:conventions`). They're biases, not mandates —
record a different choice in an ADR under `/spec/decisions`. On Windows, develop
inside **WSL2** — see [Windows: develop in WSL](#windows-develop-in-wsl).
- **`mise.toml`** manages every language runtime and CLI tool. The root file covers repo-wide tools; `infra/mise.toml` covers OpenTofu + Terragrunt for infra contributors. The config uses `latest`; the committed **`mise.lock`** holds the exact pinned versions, so all machines and CI agree. Install [mise](https://mise.jdx.dev) and run `mise install` (and `cd infra && mise install` if you'll touch infra) to get set up — that writes/refreshes `mise.lock`, which you commit. The scaffold ships placeholder `mise.lock` files because mise only writes the lock when the file already exists — don't delete them. Bump later with `mise upgrade`. Run `/steer:conventions` for the latest-in-config / pinned-in-lockfile rationale.

## Quick links

- [Product spec](./spec/vision.md) — what this product does and why. Spec ↔ code rules and templates come from the `steer` plugin: run `/steer:spec-scaffold`, `/steer:adr`, or `/steer:conventions`
- [App guide](./spec/app/README.md) — how to use the product: workflows, roles, configuration, limitations, troubleshooting
- [Architecture](./ARCHITECTURE.md) — tech stack, the apps/packages map, and how the pieces fit together
- [Action history](./spec/HISTORY.md) — what changed, why, who asked, and where it's specified
- [Issue tracker](./spec/tracker.md) — which tracker this product uses and how work items are referenced
- [CLAUDE.md](./CLAUDE.md) — the operating manual: stack, spec workflow, testing, change-size model
- [File a feature request](../../issues/new?template=feature.yml)
- [File a bug report](../../issues/new?template=bug.yml)

## Quickstart for POs (non-technical)

You don't need to read code or run commands — Claude does the setup.

1. **One time:** install [Claude Code](https://claude.com/claude-code) and
   [Docker Desktop](https://www.docker.com/products/docker-desktop/) (start it).
2. Open this repo's folder in Claude Code.
3. Type **`/steer:build`** and describe your idea. Claude interviews you, writes
   the spec for you to approve, then builds the app and runs it on your machine.

A developer reviews everything before it becomes the official version.

## Quickstart for devs

> Prefer an assisted setup? In Claude Code, run **`/steer:doctor`** — it detects
> what's missing and installs the toolchain (mise, then pnpm/uv/node) with your
> confirmation, and flags Docker Desktop / WSL2. The manual steps below are the
> equivalent by hand.

```bash
# One-time: install mise
brew install mise                          # macOS
# See https://mise.jdx.dev/getting-started.html for other platforms

# Activate mise in your shell; add this to ~/.zshrc or ~/.bashrc
eval "$(mise activate zsh)"

# Per repo
mise install                               # installs tools; writes/refreshes mise.lock (commit it)
mise run dev:setup                         # local env in one command: Docker services up,
                                           # migrations applied, dev data seeded (idempotent —
                                           # rerun anytime; needs Docker running)

# Node apps/packages — pnpm is the default package manager
pnpm install
pnpm dev

# Python apps/packages — uv is the default
uv sync
uv run <your-dev-command>
```

> `mise run dev:setup` is the standard entry point for a working local
> environment. The baseline starts the PostgreSQL in [`compose.yaml`](./compose.yaml)
> and fans `db:migrate` / `db:seed` out to workspace packages that define them
> (those steps no-op until the first real app lands).
> Adapt the tasks in `mise.toml` to the product during `/steer:init`.

> Local config vars are documented in [`.env.example`](./.env.example) — copy it
> to a git-ignored `.env` and fill in real values. Running several products
> at once and hitting `port is already allocated`? Set a distinct `POSTGRES_PORT`
> (e.g. `5433`) in `.env` and mirror it in `DATABASE_URL`; Compose picks it up
> automatically.

> On **Windows**, run all of the above inside WSL2 — see [Windows: develop in WSL](#windows-develop-in-wsl).

Before the `@claude` GitHub workflow will run, add the `ANTHROPIC_API_KEY` secret and the steer marketplace App credentials (`STEER_APP_ID` / `STEER_APP_PRIVATE_KEY`) — see [GitHub Actions secrets](#github-actions-secrets) below. To use the GitHub MCP server from local Claude Code sessions, export a `GITHUB_PAT` — see [GitHub MCP server](#github-mcp-server-local-claude-code-only) below.

## Windows: develop in WSL

On Windows, do all development inside **WSL2** (Ubuntu recommended), not native Windows or PowerShell. The toolchain (mise, uv, pnpm, OpenTofu/Terragrunt) and the shell scripts CI lints assume a POSIX environment; WSL avoids path, line-ending, and shell-incompatibility issues.

1. **Install WSL2** — in an elevated PowerShell, run `wsl --install` (installs WSL2 + Ubuntu), then reboot. Verify with `wsl -l -v` (the distro should show `VERSION 2`). Full guide: <https://learn.microsoft.com/windows/wsl/install>.
2. **Clone the repo *inside* the Linux filesystem** (e.g. `~/code/…`, not `/mnt/c/…`) — working under `/mnt/c` is markedly slower and breaks file-watching.
3. **Install the toolchain in WSL**: open the Ubuntu shell and follow the [Quickstart for devs](#quickstart-for-devs) above (install mise, activate it in `~/.bashrc`/`~/.zshrc`, `mise install`). Install pnpm/uv via mise or their official installers — inside WSL, not on Windows.
4. **Editor**: use VS Code with the **WSL** extension (`code .` from the WSL shell), or a JetBrains IDE in WSL mode, so the editor uses the Linux toolchain.
5. **Git line endings**: keep `core.autocrlf` off in WSL (`git config --global core.autocrlf input`) so scripts stay LF.

## GitHub Actions secrets

`.github/workflows/claude.yml` (the `@claude` mention workflow — and any Claude Code Review workflow you add) authenticates to the Anthropic API and **loads the `steer` plugin from the org marketplace**, so the in-CI agent runs under the same engineering standards as a local Claude Code session (not a stock, standards-less Claude). Set these up **before** opening the first PR, or those jobs fail.

- **`ANTHROPIC_API_KEY`** (secret, required) — create at <https://console.anthropic.com/settings/keys>, scoped to this project's billing workspace (not a personal key). Add under **Settings → Secrets and variables → Actions → Secrets**. Without it the job fails with a silent 401.
- **`STEER_APP_ID`** (variable) + **`STEER_APP_PRIVATE_KEY`** (secret) — credentials for the shared **steer marketplace GitHub App** (read-only on the private `element22llc/e22-plugins` marketplace repo). The default `GITHUB_TOKEN` is scoped to this repo only and **cannot** reach another org repo, so without them the `plugins` load fails and CI Claude silently runs with no steer rules. These are **org-managed, not per-repo** — see [the App below](#steer-marketplace-github-app). Add the App ID under **Settings → Secrets and variables → Actions → Variables** and the private key under **Secrets**. The workflow mints a short-lived (1 h, auto-revoked), repo-scoped token from them; if `STEER_APP_ID` is unset the steps no-op and the clone goes anonymous (correct once the marketplace is public).

Verify: comment `@claude` on any PR or issue and confirm the reply reflects steer standards (e.g. it cites the Definition of Done or spec discipline) — that proves the plugin loaded, not just that the action ran. The workflow log's `system/init` event also lists loaded plugins. A 401 means `ANTHROPIC_API_KEY` is missing/wrong/mis-scoped; a marketplace-clone or plugin-not-found error means the App credentials are missing or the App lacks access. This workflow uses `anthropics/claude-code-action@v1` and does **not** consume `.mcp.json` or `GITHUB_PAT`.

### steer marketplace GitHub App

One App is created **once for the org** and reused by every product repo — no per-repo personal access tokens to mint, rotate, or leak. Org owners set it up:

1. **Create the App** (org **Settings → Developer settings → GitHub Apps → New GitHub App**): any name (e.g. *steer-marketplace-reader*), no callback URL, **Repository permissions → Contents: Read-only** (nothing else), and *Where can this app be installed?* → Only this account.
2. **Generate a private key** (App settings → *Private keys → Generate*) and note the **App ID**.
3. **Install the App** on the marketplace repo only: App settings → *Install App* → select `element22llc/e22-plugins`.
4. **Publish the credentials to product repos** as an **organization** variable + secret (org **Settings → Secrets and variables → Actions**) so every repo inherits them: variable `STEER_APP_ID` = the App ID, secret `STEER_APP_PRIVATE_KEY` = the generated `.pem` contents. Scope them to the repos that use `claude.yml`.

Rotating the key or revoking access is then a single org-level action, not a sweep across every repo.

## GitHub MCP server (local Claude Code only)

This repo ships a project-scoped `.mcp.json` that wires **local Claude Code sessions** to GitHub's hosted MCP server (read issues, comment on PRs, inspect workflow runs). It is not used by GitHub Actions. The config references `${GITHUB_PAT}`; the token never lives in the repo — you provide it via your shell.

1. **Create a fine-grained PAT** at [github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens) scoped to this repo's owner, with repository permissions: Actions (Read), Commit statuses (Read), Contents (Read/write), Issues (Read/write), Pull requests (Read/write), Metadata (Read); organization Members (Read). Classic-PAT equivalent: `repo`, `read:org`, `workflow`. Set expiry ≤90 days. Defer to [GitHub's MCP docs](https://docs.github.com/en/copilot/customizing-copilot/extending-copilot-chat-with-the-github-mcp-server) if required scopes change.
2. **Export it from your shell rc** (`~/.zshrc` / `~/.bashrc`): `export GITHUB_PAT="github_pat_…"`, then reload. A secret manager works too (e.g. `export GITHUB_PAT="$(op read 'op://Personal/github-pat/credential')"`).
3. **Verify**: restart Claude Code in this repo, run `/mcp`, and confirm `github` is connected.

Never put the token in a repo file (even gitignored), commit a `.mcp.json` with the literal token, or paste it into a Claude message.

## Document conversion MCP server (markitdown, local Claude Code only)

The same `.mcp.json` also wires **local Claude Code sessions** to Microsoft's [markitdown](https://github.com/microsoft/markitdown) MCP server (run via `uvx markitdown-mcp`), which converts binary Office documents (`.docx`, `.xlsx`, `.pptx`) — and other formats like HTML, EPUB, and CSV — into clean Markdown. Use it when a stakeholder hands over source material in those formats, so Claude can read it cheaply instead of choking on raw zip+XML. **PDFs and images don't need it — Claude's `Read` tool already handles those natively** (it renders PDF pages visually), so reach for markitdown for the Office binaries specifically.

1. **Prerequisite — `uv`** (provided by default): the server runs via `uvx markitdown-mcp`, so `uv` must be on your `PATH`. `mise.toml` pins `uv` and `python` for every repo, so `mise install` ([Quickstart for devs](#quickstart-for-devs)) sets this up out of the box — no per-product opt-in. First use auto-fetches the `markitdown-mcp` package from PyPI — no token or env var required.
2. **Verify**: restart Claude Code in this repo, run `/mcp`, and confirm `markitdown` is connected. (If you removed `uv`/`python` from `mise.toml` it shows disconnected instead — nothing breaks, but conversion is unavailable.)

markitdown-mcp is meant for **local, trusted use only** — don't expose it over HTTP/SSE.

## Branch protection

steer is advisory in the local session — it won't *block* a push to `main`. The
real gate is **GitHub branch protection** on the default branch, and the required
rules are the single source of truth in [`policy/branch-protection.yml`](policy/branch-protection.yml):
a PR before merging, 1 approval, dismiss stale approvals on new commits, the `ci`
status check, linear history, and no bypassing — even for admins. In **Settings →
Code security**, enable Secret scanning + push protection.

Don't set this up by hand — run **`/steer:protect`**. It reads that policy, diffs
it against the repo's live settings, and (on your confirmation) applies what's
missing via the GitHub API. `init`/`adopt` recommend it as the final bootstrap
step, and `/steer:audit` flags it when it drifts.

Be honest about what `ci` verifies: it always runs stack-agnostic hygiene (`actionlint`, `shellcheck`, the version-pin scan), then auto-detects your stack and runs its checks — Node/TS (Biome + typecheck + tests) when a `package.json`/`pnpm-workspace.yaml` is present, Python (Ruff + pytest) when a `pyproject.toml` is. A detected stack with **no** test contract fails the build, so a green `ci` never means "no tests ran". Before any app exists, only the hygiene phase runs and `ci` reports that application validation is not yet active. The `design.md` lint job is advisory and intentionally not required.

#### Dependabot — and the auto-merge exception

[`.github/dependabot.yml`](.github/dependabot.yml) keeps dependencies patched. The
paired [`dependabot-auto-merge.yml`](.github/workflows/dependabot-auto-merge.yml)
workflow is a **deliberate, documented exception** to the human-review rule above:
because dependency bumps don't touch application logic, steer **auto-approves and
auto-merges the low-risk subset — patch and minor updates** (where most security
fixes land). **Major** bumps are never auto-merged: they can carry breaking changes
and may need a [`policy/versions.yml`](policy/versions.yml) decision, so a human
reviews them.

This waives only the human *review*, never the tests: the workflow waits for the
required `ci` check before it merges, so a bump that breaks tests, lint, or the
version-pin scan never lands — **CI, not a human, is what guarantees the bump is
safe.** Auto-merge is scoped to Dependabot by the workflow's `dependabot[bot]`
guard — GitHub's repo-wide `allow_auto_merge` setting is deliberately left **off**,
so no other PR gets an auto-merge button. `/steer:protect` enables Dependabot
alerts + security updates (so security PRs get opened); the merge itself is enacted
by the workflow, not by protect. Want zero automated merges? Delete that workflow —
Dependabot PRs then go through the same human gate as everything else.
