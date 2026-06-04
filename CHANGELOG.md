# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## e22-standards

### 1.4.0

- **Fix: toolchain pinning silently produced no lock.** mise only writes
  `mise.lock` when the file already exists, so the documented
  "`mise install` generates the lock" flow pinned nothing on a fresh fork.
  `CONVENTIONS.md` and `/e22-init` step 4 now document the caveat, require
  restoring a missing lock (`touch mise.lock` / `mise lock`) before installing,
  and require verifying the lock contains real `[[tools.*]]` entries before
  committing. Pairs with `repository-template`, which now ships committed
  placeholder `mise.lock` files (root and `infra/`).
- New org standard: **lockfile discipline** (always-on rule in the practices
  baseline + a `CONVENTIONS.md` section). `mise.lock`, `pnpm-lock.yaml`,
  `uv.lock`, `.terraform.lock.hcl` are committed and updated in the same change
  that touches their config/deps; never deleted or git-ignored to dodge an
  error; lockfile-only diffs get real review.
- New org standard: **mise backends must be cross-platform** (macOS + Linux).
  The registry default backend is not always usable everywhere — e.g. plain
  `pnpm` → `aqua:pnpm/pnpm` has no valid macOS asset, so repos pin `"npm:pnpm"`
  explicitly. Verify `mise install` works on both platforms when adding a tool.
- `/e22-init` step 5 now covers workspace lockfile adoption: the template ships
  no `pnpm-lock.yaml` on purpose (the starter's would go stale); generate and
  commit it (or `uv.lock`) once the real workspace exists.

### 1.3.0

- New org standard: **standard mise tasks**. Every repo exposes
  `mise run dev:setup` — the idempotent one-command local environment (Compose
  services up → `db:migrate` → `db:seed`) — plus `docker:up/down` and
  `db:migrate`/`db:seed`. Environment-orchestration tasks live in `mise.toml`
  (polyglot, owns tooling outside the workspace), not `package.json`, whose
  scripts stay app-level.
- Stack rule's Local-services bullet now names `mise run dev:setup` as the
  standard entry point and requires keeping it green as the stack evolves; the
  always-on commands cheat-sheet includes it in first-time setup.
- `CONVENTIONS.md` gains a "Standard mise tasks" section (the task vocabulary,
  the idempotency contract, and the mise-vs-package.json rationale), surfaced
  in the `/e22-conventions` skill summary.
- `/e22-init` gains step 6: adapt the template's baseline tasks to the product
  being built — real services in `compose.yaml`, real migrate/seed scripts,
  `uv run` instead of pnpm for Python products, or delete the docker/db tasks
  when there are no backing services.
- Pairs with `repository-template`, which now ships the baseline `[tasks]`
  block in `mise.toml` and a Postgres `compose.yaml` (host port overridable via
  `POSTGRES_PORT` so parallel products don't collide on 5432).

### 1.2.0

- New always-on rule **Commit autonomy** (`rules/45-commit-autonomy.md`): on a
  `feat/*`/`fix/*` branch, commit coherent units of work without asking the dev
  for permission — the PR review is the gate, not each commit. Never commit to
  `main` directly. When the work is judged complete (Definition of Done holds),
  proactively propose opening the PR and wait for the dev's confirmation before
  pushing/creating it.
- End-of-session checklist gains a matching item: all finished work committed,
  PR proposed if the change is complete.

### 1.1.0

- Local-dev `.env` bootstrap: the Stack and Secrets rules now require that when
  setting up or running an app locally, `.env` is created and populated with
  the base variables the app needs to boot — e.g. `DATABASE_URL` pointing at
  the local Compose PostgreSQL and freshly generated local-only secrets (auth
  secret, API tokens) — instead of leaving the dev to hand-assemble it from the
  README. Deployed/production secret values must never be copied into it.

### 1.0.0

- Initial release. Fresh start: replaces the earlier experimental 7-plugin
  three-zone marketplace (removed — preserved in git history) with a single
  `e22-standards` plugin mirroring the `repository-template` org standards.
- Always-on ruleset (`rules/*.md`) injected via a `SessionStart` hook: stack,
  layout, spec workflow, testing, Definition of Done, high-risk areas, secrets,
  change-size model, baseline patterns/anti-patterns, design-sources, and the
  end-of-session checklist.
- Skills: `e22-init`, `e22-spec-scaffold`, `e22-adr`, `e22-conventions`,
  `e22-design-sources`. Command: `/e22-init`.
- Bundled spec templates (`feature-intent`, `feature-contract`, `adr`) and full
  reference prose (`CONVENTIONS.md`, `DESIGN-SOURCES.md`, `spec-framework.md`).
