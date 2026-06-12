# [Product Name]

> Replace this section after bootstrapping the repo (`/e22-init`).

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

E22 defaults for package managers: **pnpm** for Node, **uv** for Python (rationale
via the `e22-standards` plugin — run `/e22-conventions`). They're biases, not mandates —
record a different choice in an ADR under `/spec/decisions`. On Windows, develop
inside **WSL2** — see [Windows: develop in WSL](#windows-develop-in-wsl).
- **`mise.toml`** manages every language runtime and CLI tool. The root file covers repo-wide tools; `infra/mise.toml` covers OpenTofu + Terragrunt for infra contributors. The config uses `latest`; the committed **`mise.lock`** holds the exact pinned versions, so all machines and CI agree. Install [mise](https://mise.jdx.dev) and run `mise install` (and `cd infra && mise install` if you'll touch infra) to get set up — that writes/refreshes `mise.lock`, which you commit. The scaffold ships placeholder `mise.lock` files because mise only writes the lock when the file already exists — don't delete them. Bump later with `mise upgrade`. Run `/e22-conventions` for the latest-in-config / pinned-in-lockfile rationale.

## Quick links

- [Product spec](./spec/vision.md) — what this product does and why. Spec ↔ code rules and templates come from the `e22-standards` plugin: run `/e22-spec-scaffold`, `/e22-adr`, or `/e22-conventions`
- [App guide](./spec/app/README.md) — how to use the product: workflows, roles, configuration, limitations, troubleshooting
- [Action history](./spec/HISTORY.md) — what changed, why, who asked, and where it's specified
- [Issue tracker](./spec/tracker.md) — which tracker this product uses and how work items are referenced
- [CLAUDE.md](./CLAUDE.md) — the operating manual: stack, spec workflow, testing, change-size model
- [File a feature request](../../issues/new?template=feature-request.md)
- [File a bug report](../../issues/new?template=bug-report.md)

## Quickstart for POs (non-technical)

You don't need to read code or run commands — Claude does the setup.

1. **One time:** install [Claude Code](https://claude.com/claude-code) and
   [Docker Desktop](https://www.docker.com/products/docker-desktop/) (start it).
2. Open this repo's folder in Claude Code.
3. Type **`/e22-build`** and describe your idea. Claude interviews you, writes
   the spec for you to approve, then builds the app and runs it on your machine.

A developer reviews everything before it becomes the official version.

## Quickstart for devs

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

> `mise run dev:setup` is the standard E22 entry point for a working local
> environment. The baseline starts the PostgreSQL in [`compose.yaml`](./compose.yaml)
> and fans `db:migrate` / `db:seed` out to workspace packages that define them
> (those steps no-op until the first real app lands).
> Adapt the tasks in `mise.toml` to the product during `/e22-init`.

> Local config vars are documented in [`.env.example`](./.env.example) — copy it
> to a git-ignored `.env` and fill in real values. Running several E22 products
> at once and hitting `port is already allocated`? Set a distinct `POSTGRES_PORT`
> (e.g. `5433`) in `.env` and mirror it in `DATABASE_URL`; Compose picks it up
> automatically.

> On **Windows**, run all of the above inside WSL2 — see [Windows: develop in WSL](#windows-develop-in-wsl).

Before the `@claude` and Claude Code Review GitHub workflows will run, add an `ANTHROPIC_API_KEY` repository secret — see [GitHub Actions secret](#github-actions-secret) below. To use the GitHub MCP server from local Claude Code sessions, export a `GITHUB_PAT` — see [GitHub MCP server](#github-mcp-server-local-claude-code-only) below.

## Windows: develop in WSL

On Windows, do all development inside **WSL2** (Ubuntu recommended), not native Windows or PowerShell. The toolchain (mise, uv, pnpm, OpenTofu/Terragrunt) and the shell scripts CI lints assume a POSIX environment; WSL avoids path, line-ending, and shell-incompatibility issues.

1. **Install WSL2** — in an elevated PowerShell, run `wsl --install` (installs WSL2 + Ubuntu), then reboot. Verify with `wsl -l -v` (the distro should show `VERSION 2`). Full guide: <https://learn.microsoft.com/windows/wsl/install>.
2. **Clone the repo *inside* the Linux filesystem** (e.g. `~/code/…`, not `/mnt/c/…`) — working under `/mnt/c` is markedly slower and breaks file-watching.
3. **Install the toolchain in WSL**: open the Ubuntu shell and follow the [Quickstart for devs](#quickstart-for-devs) above (install mise, activate it in `~/.bashrc`/`~/.zshrc`, `mise install`). Install pnpm/uv via mise or their official installers — inside WSL, not on Windows.
4. **Editor**: use VS Code with the **WSL** extension (`code .` from the WSL shell), or a JetBrains IDE in WSL mode, so the editor uses the Linux toolchain.
5. **Git line endings**: keep `core.autocrlf` off in WSL (`git config --global core.autocrlf input`) so scripts stay LF.

## GitHub Actions secret

`.github/workflows/claude.yml` (the `@claude` mention workflow — and any Claude Code Review workflow you add) authenticates to the Anthropic API with a repository secret. Set it up **before** opening the first PR, or those jobs fail with silent 401s.

- **`ANTHROPIC_API_KEY`** — create at <https://console.anthropic.com/settings/keys>, scoped to this project's billing workspace (not a personal key). Add it under **Settings → Secrets and variables → Actions → New repository secret**.

Verify: open any PR and wait for `Claude Code Review` to leave a comment. A 401 in the workflow log means the secret is missing, wrong, or scoped to a different workspace. These workflows use `anthropics/claude-code-action@v1` and do **not** consume `.mcp.json` or `GITHUB_PAT`.

## GitHub MCP server (local Claude Code only)

This repo ships a project-scoped `.mcp.json` that wires **local Claude Code sessions** to GitHub's hosted MCP server (read issues, comment on PRs, inspect workflow runs). It is not used by GitHub Actions. The config references `${GITHUB_PAT}`; the token never lives in the repo — you provide it via your shell.

1. **Create a fine-grained PAT** at [github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens) scoped to this repo's owner, with repository permissions: Actions (Read), Commit statuses (Read), Contents (Read/write), Issues (Read/write), Pull requests (Read/write), Metadata (Read); organization Members (Read). Classic-PAT equivalent: `repo`, `read:org`, `workflow`. Set expiry ≤90 days. Defer to [GitHub's MCP docs](https://docs.github.com/en/copilot/customizing-copilot/extending-copilot-chat-with-the-github-mcp-server) if required scopes change.
2. **Export it from your shell rc** (`~/.zshrc` / `~/.bashrc`): `export GITHUB_PAT="github_pat_…"`, then reload. A secret manager works too (e.g. `export GITHUB_PAT="$(op read 'op://Personal/github-pat/credential')"`).
3. **Verify**: restart Claude Code in this repo, run `/mcp`, and confirm `github` is connected.

Never put the token in a repo file (even gitignored), commit a `.mcp.json` with the literal token, or paste it into a Claude message.

## Branch protection

On `main`, require: a PR before merging; 1 approval; dismiss stale approvals on new commits; the `ci` status check; linear history; and no bypassing — even for admins — unless the team explicitly approves. In **Settings → Code security**, enable Secret scanning + push protection.

Be honest about what `ci` verifies: out of the box it runs only stack-agnostic hygiene (`actionlint`, `shellcheck`). Your per-app lint/test/build steps ship commented-out in `.github/workflows/ci.yml` — activate them early so a green `ci` actually means tests passed. The `design.md` lint job is advisory and intentionally not required.
