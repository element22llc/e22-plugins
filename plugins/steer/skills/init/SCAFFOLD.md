# `/steer:init` — step 2: instantiate the bundled scaffold

Read this file when you reach step 2 of Path B. Step 1 (confirm the mode) and
steps 3–7 (interview, first ADR, pin the toolchain, proceed spec-first, hand
off) stay in `SKILL.md`, as do the guardrails.

**Member repo? Resolve the topology before instantiating anything under
`spec/`.** This repo is a **polyrepo member** if `spec/PRODUCT.md` is already
present, or if the workspace session that sent you here said so. In a member,
install `spec/PRODUCT.md` (from
`${CLAUDE_PLUGIN_ROOT}/templates/spec/product.md`) and **skip every
product-level artifact** below — `vision.md`, `users.md`, `glossary.md`,
`/spec/HISTORY.md`, `/spec/app/`, `/spec/features/`, `/spec/tracker.md`. Those
live once, in the workspace. The member still gets its own internals:
`spec/decisions/`, `spec/design/`, `DESIGN.md`, `ARCHITECTURE.md`,
`PRODUCTIONIZATION.md`, and the whole non-`spec/` scaffold. Writing the
product-level files here manufactures the split-brain spine rule
`30-spec-workflow` and `/steer:reference polyrepo` exist to prevent — if you
cannot tell which role this repo plays, say so and stop rather than write them
locally. Everything else in this step is unchanged.

**Instantiate the bundled scaffold — core plus the profile's extras.** Everything
lives in the plugin — no external template repo to fetch. Read
`${CLAUDE_PLUGIN_ROOT}/templates/scaffold/MANIFEST.md` and follow its
install map **and its "Profile overlays" section**: copy each scaffold file to
its target path (renaming the
dotfiles as mapped — `gitignore` → `.gitignore`, `env.example` →
`.env.example`, `claude/`, `vscode/`), instantiate the GitHub
templates from `${CLAUDE_PLUGIN_ROOT}/templates/github/` (the MANIFEST's
GitHub-templates section maps the Issue Forms, workflows, PR template, and the
full generated Copilot/VS Code surface — `copilot-instructions.md`,
`prompts/*.prompt.md` (skills), `agents/*.agent.md` (custom agents), and
`instructions/*.instructions.md` (path-scoped standards) — into `.github/`;
the opt-in `copilot-setup-steps.yml` is **not** auto-installed), and instantiate the
spec spine from
`${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
`vision.md`, `users.md`, `glossary.md`, plus the living-docs artifacts —
`/spec/HISTORY.md` (from `history.md`), `/spec/tracker.md` (from
`tracker.md`), and `/spec/app/README.md` (from `app-docs.md`) — and the
design/sources homes: `/spec/design/README.md` (from `design-readme.md`),
`/spec/design/source.md` (from `design-source.md`),
`/spec/design/architecture-diagram.md` (from
`design-architecture-diagram.md` — the living global architecture diagram
`ARCHITECTURE.md` links to), and
`/spec/sources/README.md` (from `sources-readme.md` — the versioned home for
recurring PO documents, maintained by `/steer:intake`). Install the
bundled `spec/features/.gitkeep` and `spec/decisions/.gitkeep` so those dirs
survive the first commit (an empty dir does not — `/steer:spec-scaffold`
and `/steer:adr` populate them later). **Adapt to the chosen stack
and never clobber existing files** (the MANIFEST's per-file notes say what
to adapt — e.g. for a Python-only product skip the Layer-1 Node baseline and
use `pyproject.toml`/Ruff, swap task commands to `uv run …`). Greenfield repos
rarely have these already, but if a target `.gitignore` or JSON config
(`.claude/settings.json`, `biome.json`) **does** exist, reconcile
it additively with
`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" auto <target> <scaffold-template> --apply`
instead of overwriting it.
- **Apply the layered profile overlays** (MANIFEST "Profile overlays"). The
  Core install map (Layer 0) lands for **every** profile; then compose
  **additively** — later layers only *add*:
  - **Node-stack profiles** (`app` / `service` / `library` / `cli` on a Node
    stack): also install **Layer 1**, the Node baseline
    `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/profiles/_node/` (`package.json`,
    `pnpm-workspace.yaml`, `biome.json`, `configs/`, `packages/`), then the
    profile's **Layer 2** dir — `profiles/app/` → `apps/README.md` + `DESIGN.md`
    + `claude/launch.json` (Desktop Code-tab preview server; copy only if the
    repo has no `.claude/launch.json` — never overwrite; repoint at `mise run
    dev` if the repo is polyglot);
    `profiles/service/` → `apps/README.md`; `library`/`cli` add nothing.
    Adapt `package.json`: `library` → publishable (drop `private`); `cli` → add
    the `bin` entrypoint. (A **Python-only** `service`/`library`/`cli` skips
    Layer 1 — use `pyproject.toml`/Ruff instead.)
  - **`infra`**: install
    `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/profiles/infra/mise.toml` as the
    **repo-root `mise.toml`** (replaces the core one) and **skip Layer 1
    entirely** (no Node project files). Core's `compose.yaml` +
    `scripts/worktree-env.sh` still land from Layer 0 — delete them only if the
    repo runs no local services. Enable the matching IaC engine in that
    `mise.toml` and adapt `ARCHITECTURE.md`/README to the IaC layout.
  - **`workspace`** (polyrepo spine host): install
    `${CLAUDE_PLUGIN_ROOT}/templates/spec/workspace.yml` as **`spec/workspace.yml`**
    (it is a spec artifact — product-level truth — not a root config file), then
    the Layer-2 dir `profiles/workspace/`: `README.md` and `mise.toml` and
    `compose.yaml` all **replace** their core counterparts, `gitignore` merges
    into `.gitignore`, and `scripts/ws.sh` installs as `scripts/ws.sh`. **Skip
    Layer 1 entirely** — this repo owns no application code, so also drop
    Layer 0's `apps/` and the Dockerfile refs. **Keep** Layer 0's
    `scripts/worktree-env.sh`: the workspace boots the members' services
    together and needs its own Compose project name so it never collides with a
    member's standalone stack.
    Interview for the member list and resolve every `spec/workspace.yml`
    placeholder — **never ship fabricated repo names or branches**; leave the
    file with a single placeholder member if the dev does not know them yet.
    Then derive the rest **from that manifest** (it is the one source of truth —
    `mise run ws:status` reports any of these that drift):
    - `.gitignore` — one anchored line per member `path:` (`/frontend/`).
    - `compose.yaml` — one `include:` entry per member that will run local
      services, long syntax. If none will, delete the file **and** the
      `ws:docker:*` + `ws:dev` tasks in `mise.toml`.
    - `mise.toml` — the `ws:dev` task's `depends` (keep `ws:docker:up` first, then
      one `//<member>:dev` per member with a dev server), and, once members are
      actually cloned, uncomment the top-of-file `monorepo_root = true` (a
      **top-level** key — under `[settings]` mise ignores it as an unknown field
      and monorepo mode never turns on) + `[monorepo]` with `config_roots` listed
      explicitly. Leave `[monorepo].lockfile` unset unless the pinned mise release
      accepts it. **Every task you add here stays `ws:`-prefixed** — the workspace
      config is an ancestor config in every member, so an unprefixed name shadows
      any member that does not define it (`/steer:reference polyrepo`).
    Then bootstrap each member separately: run `/steer:init` in it with its own
    profile, and instantiate `${CLAUDE_PLUGIN_ROOT}/templates/spec/product.md`
    as its `spec/PRODUCT.md` **instead of** the product-level spine files
    (`vision.md`, `users.md`, `glossary.md`, `HISTORY.md`, `spec/app/`,
    `spec/features/`, `spec/tracker.md`) — those live once, here. Namespace each
    member's Compose service/volume/network names while you are in it: `include:`
    warns and takes one side on a collision instead of merging. Members that
    already have working code go through `/steer:adopt` instead.
    **Recommend a monorepo first** unless the split is externally mandated, and
    read `/steer:reference polyrepo` before advising.
  **Set the profile marker:** write the chosen profile into the `CLAUDE.md`
  `## Profile` marker (`<!-- steer:profile=<profile> -->`) and its prose — the
  scaffold ships `=app`; rewrite the token for any other profile. A **root
  `mise.toml` must always land** (core or infra flavor) — it is what clears the
  scaffold nudge.
