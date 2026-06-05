# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## e22-standards

### 1.6.0

- **New: PO path — `/e22-build` skill + command.** Non-technical product
  owners can now go idea → auto-drafted spec → intent validation → working
  local app entirely in Claude Code. The skill is a thin driver over the
  existing Greenfield flow: PO-adapted first-run setup (Claude installs and
  runs mise/Docker/pnpm itself, asks the PO only product name + one-liner,
  keeps the default stack), interview → `vision.md`/`users.md`/`glossary.md`,
  intents via `/e22-spec-scaffold`, an explicit PO-acceptance gate before
  broad implementation, feature-by-feature build with `contract.md` + tests,
  local demo via `mise run dev:setup` + `pnpm dev`, and handoff as a PR whose
  description is the dev's productionization brief (PO-built v0, approved
  intents, stubbed high-risk items, open questions).
- **New always-on rule `05-roles.md` (PO vs dev).** Defines the two audiences
  and PO-mode behavior: plain language, spec-first, Claude drives the
  toolchain; guardrails — never deploy, never touch `/infra`, high-risk areas
  (auth, secrets, migrations, billing, deletion) stubbed minimally and flagged
  for a dev. Standards are never softened for a non-technical user, and the
  gate is unchanged: a PO-built app merges to `main` as v0 only after a dev
  approves the PR.
- **Spec framework broadened to both audiences.** Rule 1 and the lifecycle
  table now say specs are written with Claude's help by a dev *or* a PO via
  `/e22-build` (PO approves intent, dev approves the PR). Fixed structure-
  diagram drift: removed `/spec/README.md` and `/spec/_templates/`, which the
  template repo doesn't ship (templates are bundled in this plugin).
- README: dropped the hand-maintained Versions table (already stale at 1.0.0)
  in favor of `plugin.json` + this changelog.
- Pairs with `repository-template`: PO quickstart in the README, `/e22-build`
  in the `CLAUDE.md` fork note, broadened `spec/vision.md` header, and two
  fresh-fork CI fixes — (1) `pnpm install --frozen-lockfile` failed every
  fresh fork's first PR (`ERR_PNPM_NO_LOCKFILE`, the template deliberately
  ships no `pnpm-lock.yaml`); the install step now freezes only once a
  lockfile exists; (2) mise-action v4 auto-runs `mise install --locked` when
  a `mise.lock` exists, so the comment-only placeholder locks failed every
  tool with "not in the lockfile"; CI now drops placeholder locks (no
  `[[tools]]` entries) from the runner workspace before setup and installs
  the exact pins once `/e22-init` commits populated locks. Both fixes are
  self-correcting at lock adoption.

### 1.5.0

- **New: enforced version-pin verification.** The "default to current stable /
  don't trust training-data memory" rule was advisory only, and the failure
  mode is being *confidently* stale (e.g. a fresh app scaffolded with
  `postgres:16` when current stable is 18), so the "if unsure, ask" escape
  hatch never fired. A new `PreToolUse` hook
  (`hooks/check-version-pins.sh`) now denies Write/Edit/Bash calls that pin a
  stale major for common images (`postgres:`, `node:`, `python:`, `redis:`,
  `valkey:`, `nginx:`, `mysql:`, `mariadb:`, `mongo:`), with current stable
  resolved live from the endoflife.date API — the hook hardcodes no versions.
  Fails open offline; Markdown exempt; deliberate older pins pass with an ADR
  plus a same-line `# pin-ok: <reason>` marker. Documented in
  `CONVENTIONS.md` (Versioning policy → Enforcement).
- **Versioning policy reworded:** verification of current stable is now
  unconditional before writing any pin, instead of "if unsure, say so" —
  models are not unsure, they are confidently stale.
- New stack rule: **don't author `compose.yaml` from scratch** — start from
  the `repository-template` one and adapt, so generated services can't
  reintroduce stale image majors.
- **Fix: hooks no longer depend on the executable bit.** `hooks.json` now
  invokes both hook scripts via an explicit `sh` prefix; marketplace install
  does not chmod, so a missing `+x` could previously leave a session with no
  org standards injected at all.

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
