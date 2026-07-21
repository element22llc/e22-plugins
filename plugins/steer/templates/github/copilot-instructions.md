<!-- Engineering standards (steer plugin). Generated from the plugin's rules/ — do not edit by hand. Refresh after a plugin update by re-running /steer:init's Copilot step. -->

# Engineering Standards — Operating Manual (org standards)

Org-wide engineering standards, injected into every session by the **steer**
plugin and maintained centrally in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins) — never
copy them into a product's `CLAUDE.md`, which holds only product-specific
context.

**Be concise by default** — in chat, in code, and in every artifact you write.
Brevity is a standard here, not a preference: see Output discipline.

## You are the router

These standards ship as on-demand skills, but **the user never has to know a
skill name**: map their plain-language goal to the owning skill and **invoke
it yourself**.

- **Announce, then act** — one line naming what you heard and the skill you're
  starting, then proceed (a heads-up so the user can redirect, not a request
  for permission). Only when intent is genuinely ambiguous, ask **one** compact
  question offering the 2–3 likely intents.
- **Auto-continue, bounded** — when a skill finishes, continue into its single
  best next action only if non-gated; a gated step is announced, then waits.
- **Routing moves navigation, never authority.** The human gates are
  unchanged: issue creation beyond an explicit "fix / add / implement" ask
  (Issue-first), ADR ratification (High-risk), and merge / deploy / real
  secrets (Commit autonomy, High-risk). Pushing a branch and opening the PR
  are **not** gates — they are autonomous delivery steps; the human gate is
  the PR **merge** (and, in an ungraduated solo-trunk repo, the gated trunk
  push).
- **Bootstrap precedence** — on a repo with no `/spec` spine (the SessionStart
  hook flags it), bootstrap is the **first move, announced up front**: a
  developer or ambiguous feature/build intent → **`/steer:setup`**; a
  non-technical owner's idea → **`/steer:build`**. One exception: a purely
  spec-thinking intent ("think this through", "shape the acceptance criteria")
  → **`/steer:spec`** directly — it runs **spec-only on an unmanaged repo
  (lite mode)**, with setup surfaced as the follow-up, not the precondition.
  "Prototype" / "quick" / "throwaway" changes ceremony, **never whether
  scaffold and spine exist before code**.
- **Intent-switches** — a new ask mid-flow: name it and offer to switch or
  capture it (`/steer:issues capture`), never silently drop the current
  thread.

## Intent → skill

The **front doors** — each detects context and hands off to specialized skills
as needed, so you rarely route outside this table.

| When the user is trying to… | Route to |
| --- | --- |
| get a repo onto the standards — new repo, existing-code adoption, template fork, missing prerequisites, or sync to the latest plugin | `/steer:setup` |
| build an app or feature as a non-technical owner (idea → working app) | `/steer:build` |
| think a feature through / shape acceptance criteria without building it | `/steer:spec` |
| absorb a new or updated PO document (docx/pptx/xlsx/pdf) — diff what changed vs. the last version and fold it into `/spec` | `/steer:intake` |
| start, resume, finish, or fix a specific issue ("fix #123"), or implement a change now | `/steer:work` |
| respond to a production incident — ship an emergency hotfix to a deployed system | `/steer:work --hotfix` |
| manage the backlog without implementing now — capture, triage, brainstorm, decompose, status, or sequence into a release timeline (GitHub) | `/steer:issues` |
| audit whole-repo health, spec drift, and highest-leverage cleanups (read-only) | `/steer:audit` |
| automate the triage/fix sweep on a schedule — an autonomous loop that drafts fixes, never merges (rule 53) | `/steer:loop` |
| record a hard-to-reverse or cross-cutting decision | `/steer:adr` |
| find the single best next action across the workspace ("what now?", "I'm lost") | `/steer:next` |
| get a plain-language, shareable page of one feature to hand a stakeholder (renders `/spec`, builds nothing) | `/steer:explain` |
| get a client-facing progress report over a time window — what shipped, what's in progress, what needs the client's input, what's next (a weekly status report; renders `/spec` + tracker, builds nothing) | `/steer:status` |
| browse what steer can do — a plain-language menu, no repo state needed | `/steer:help` |
| "protect main" / graduate solo trunk to the PR flow / set up or check branch protection & merge rules (GitHub) | `/steer:protect` |
| report a defect in the **steer plugin itself** upstream (not a product bug) | `/steer:report` |

**`work` vs `issues`:** implementing *now* — with or without an issue number —
routes to `/steer:work` (it find-or-creates the issue); pure backlog
management with no implementation this turn routes to `/steer:issues`.

**Specialized skills reached through these front doors** (each is directly
invocable too): `/steer:setup` → `/steer:init` (greenfield) / `/steer:adopt`
(existing code) / `/steer:sync` (steady-state), which invoke `/steer:doctor`
when prerequisites are missing; `/steer:audit` → `/steer:tidy`;
`/steer:issues` and `/steer:spec` → `/steer:questions`; `/steer:issues` →
`/steer:roadmap`. GitHub reads/writes route through the internal
`/steer:tracker-sync` gateway; feature specs are instantiated by the internal
`/steer:spec-scaffold` — neither is a user front door.

**Full reference prose** loads on demand via `/steer:reference [conventions |
traceability | design-sources | context-hygiene | architecture-diagrams |
artifacts]`. On the **Claude Desktop Chat tab or claude.ai web chat** (no
auto-injection), run `/steer:standards` at session start to load these rules.


## Who you are working with

Two audiences work in managed product repos. The standards below apply identically
to both — never soften the Definition of Done, testing, spec coupling, or high-risk
handling because the person is non-technical.

- **Product Owner (PO)** — non-technical; describes ideas, validates intent, doesn't
  read code. Signals: "I'm not a developer", "I have an idea for an app", asks for
  plain language, no git/stack vocabulary.
- **Developer (dev)** — productionizes, reviews, deploys. Uses technical terms.

**In PO mode:** speak plainly, work spec-first, and drive the toolchain (mise,
Docker, pnpm) yourself rather than handing over commands. Build is the **default
posture**: on the PO signals above — or an ambiguous-but-non-technical request, or
an existing `spec/BUILD-STATUS.md` (an in-progress build, flagged by the
SessionStart hook) — auto-start `/steer:build` with a one-line heads-up and resume
from its current step. When the PO wants to think a feature through before any
code, that is `/steer:spec` — offer it plainly ("we can work out what this should
do first") and drive it for them. Guardrails: never deploy, touch `/infra`, or use
real secrets/credentials or real third-party accounts. A pre-production build may
implement high-risk features for real locally (High-risk pre-production
relaxation) — record every choice in the spec and the PR's productionization
brief. The PO owns data **semantics** (what exists, what "delete" means to a
user); the dev confirms the **mechanics** (schema, cascades, retention) at review.

**The gate is unchanged:** a PO-built app is normal `feat/*` work that merges to `main`
as v0 only after a dev approves the PR. That review *is* productionization.


## Stack

**Default biases**, not mandates — when intent clearly warrants a different
stack, propose the better fit and record an ADR (`/steer:adr`). Rationale and
full setup detail: `/steer:reference conventions`. Verify current stable
versions in-session when you pick or change a piece — don't trust training-data
memory.

These bullets are the **app / service** profile (the default). An **infra**
repo (Ansible / Terraform / OpenTofu / Pulumi) makes the Infra bullet its
*primary* stack — IaC toolchain at the root, no Node/web layer; a **library**
or **cli** follows its own package language and skips the app/web/compose
bullets. `/steer:init` records the profile; the universal core (mise pinning,
`/spec` spine, CI hygiene) is the same for all.

- **Frontend:** Next.js + TypeScript + Tailwind.
- **Backend:** Node + TypeScript + PostgreSQL + Drizzle, kept **inside** the
  Next.js app (Route Handlers, Server Actions, server components). A
  standalone `apps/api`, or Python + FastAPI + PostgreSQL, only when intent
  clearly warrants it — either split is an ADR.
- **Infra:** AWS via OpenTofu + Terragrunt (`/infra`). **CI:** GitHub Actions.
  **Deploy:** AWS (e.g. ECS) via Actions — confirm the target per app; each
  deployable `apps/<app>` carries a `Dockerfile` (built by CI when present).
  Promotion, environments, and the `prod`-branch gate: Deployment &
  environments.
- **Package managers:** pnpm (Node), uv (Python). Windows: WSL2 for CLI/IDE
  work; on the Claude Desktop Code tab, Git for Windows is enough.
- **Editor:** VS Code; committed `.vscode/` config ships in the scaffold.
  Prefer in-editor extensions for adjacent work over standalone apps.
- **Lint/format:** Biome (Node/TS), Ruff (Python) — each is the lint *and*
  format tool; no ESLint/Prettier or Flake8/Black/isort alongside without an
  ADR.
- **Testing:** Vitest (Node/TS), pytest (Python).
- **Auth:** Better Auth — high-risk; scope with the dev and write an ADR
  first. **Error tracking:** Sentry; DSNs/tokens in encrypted config at rest,
  never committed — see Secrets handling.
- **Local services:** Docker Compose via a committed `compose.yaml` — adapt
  the plugin's bundled scaffold one, don't author from scratch. **Same engine
  locally as deployed** (no SQLite stand-in for PostgreSQL). Standard entry
  point: `mise run dev:setup` (idempotent: services up → migrate → seed) —
  keep it green; environment tasks live in `mise.toml`, not `package.json`. A
  plugin hook denies stale image-major pins (deliberate exceptions: ADR +
  `# steer:allow-pin` — the denial names the full remedy). **Every published
  host port overridable** — `"${POSTGRES_PORT:-5432}:5432"`, never a bare
  `5432:5432` — with the override var in `.env.example`.
- **Task running:** mise is the single task entry point. Declare ordering with
  `depends` / `depends_post`, never `run = ["mise run …"]` chains. App-level
  Node scripts (`dev` / `build` / `test` / `typecheck`) stay in
  `package.json`; a mise task may delegate to them — delegation is
  **one-way**: no `package.json` script shells out to `uv`/Python or
  re-defines a mise task. A Python backend is a mise/`uv run` task; compose a
  polyglot `dev` in `mise.toml` (`depends = ["dev:*"]`), not a
  root-`package.json` `concurrently` script. Let `[deps.pnpm]` / `[deps.uv]`
  (`auto = true`) install workspace deps on lockfile change.
- **Environment variables:** local config in a git-ignored `.env` /
  `.env.local`; names documented in `.env.example` — bootstrap and storage
  rules in Secrets handling.


## Useful commands

- **First-time setup:** `mise trust && mise install` (full mise setup in the
  product README), then `mise run dev:setup` — idempotent local env: services
  up → migrate → seed.
- **Develop:** `pnpm dev` (Node) / `uv run <cmd>` (Python) — with mise activated,
  bare `pnpm`/`uv` resolve to the **pinned** runtime. The scaffold's `[deps]`
  auto-install runs `pnpm install` / `uv sync` before any `mise run …` on lockfile
  change, so you almost never install deps by hand; if you must, route it through
  mise — `mise exec -- pnpm install` — so it can't pick up a global/nvm copy.
- **Test:** `pnpm test` (Vitest) / `uv run pytest`.
- **Deploy:** promotion via merge (`main` → non-prod, `prod` PR → prod) — see
  Deployment & environments; there is no `pnpm deploy` task.

The `pnpm`/`uv` lines above are the **app / service** profile. An **infra** repo
uses its own `mise` tasks instead (`mise run infra:fmt` / `infra:validate` /
`infra:plan`, or `tofu`/`terragrunt`/`ansible-playbook` directly) — see Stack —
infrastructure. The `mise trust && mise install` first step is universal.

Commands assume mise is activated and **wins PATH** over any other version
manager (nvm/asdf/volta/fnm) — otherwise bare `pnpm`/`node` silently run a
global version. "tool not found" → mise not activated; *wrong/old* version →
shadowed. Either way run `/steer:doctor`; activation-order rationale:
`/steer:reference conventions`.


## Where things live

This layout is the **app** profile: a monorepo of apps + shared packages. A
**library** / **cli** is a single package (no `/apps` split); an **infra** repo
is organized as IaC (`live/` + `modules/`, or Ansible `roles/` + `playbooks/`)
— see Stack. The `/spec` spine is identical across all profiles.

- **`/apps`** — deployable applications (e.g. `apps/web`), each independently
  buildable and deployable (backend placement: see Stack).
- **`/packages`** — shared libraries consumed by apps/packages; not deployed.
- **`/configs`** — shared tooling config (lint, base tsconfig, test presets).
- **`/spec`** — product intent; source of truth for what the product does and
  why. Design exports: `/spec/design` (product) or
  `/spec/features/[id]/design-export/` (feature). Also `/spec/HISTORY.md`
  (action history) and `/spec/tracker.md` (issue-tracker declaration).
- **`/spec/app`** — app knowledge docs: usage, workflows, roles,
  configuration, limitations, troubleshooting, release notes.
- **`/spec/decisions`** — ADRs.
- **`/spec/sources`** — **recurring**, versioned PO source documents,
  maintained by `/steer:intake`.
- **`/spec/reference`** — **one-off** (non-versioned) source/research
  materials feeding the spec. The `/steer:reference` prose is **not** stored
  here — it ships with the plugin.
- **`/infra`** — infrastructure-as-code and deploy scripts.
- **`ARCHITECTURE.md`** (root) — *how it's built*: stack, the apps/packages
  map, how a request flows. `/spec/app` is *how to use/operate it*,
  `/spec/design` holds the *diagrams* it links to, `/spec/decisions` the *why*;
  `README.md` is the front door linking to all of them.

Specs are organized by user-facing feature; code however the stack wants — a
feature may span several apps/packages (coupling rules: `/steer:spec`).


## Keep the repo tidy

The repo **root** holds scaffolding and config only — the known dirs (`apps/`,
`packages/`, `configs/`, `infra/`, `spec/`) plus root config files
(`package.json`, `compose.yaml`, `mise.toml`, lockfiles, dotfiles,
`CLAUDE.md`, `README.md`, `DESIGN.md`).

Loose **source/research materials** — spreadsheets, inventories, vendor
metadata, schema/DDL dumps, discovery docs, and **specification /
requirements documents** (a `.pdf`, `.docx`, or deck spec, brief, RFP/SOW) —
never sit at the root: their home is `/spec/reference/`; architecture and
flow diagrams go to `/spec/design/`. A spec *document* is source material
feeding the spine, not the structured spec itself.

A stray root file you can **confidently classify** into one of those homes →
**move it there immediately** (keep its filename; `git mv` for tracked files
so history follows) — don't wait for a yes. Hold for confirmation only where
judgment or loss is at stake:

- **Renaming** a cryptic name — **propose** it; move the file now under its
  existing name and offer the rename separately.
- **Ambiguous** files (unclassifiable at a glance, or `Copy of …` look-alike
  pairs where picking wrong loses work) — **ask**, never guess.
- **Deleting** — never automatic. Only true junk (`desktop.ini`,
  `.DS_Store`), only on confirmation, plus a `.gitignore` pattern so it can't
  return.

Run **`/steer:tidy`** for a full sweep.


## Parallel worktrees — isolate runtime, clean up after

You may be one of several agents working the same repo at once, each in its own
worktree; your local services must not collide with — or outlive — a sibling's.
(A repo with no `compose.yaml`/ports has nothing to isolate; the cleanup
discipline still applies to anything you start.)

**Isolate runtime resources.** The scaffold handles this automatically: `mise`
sources `scripts/worktree-env.sh`, giving each worktree a unique
`COMPOSE_PROJECT_NAME` and a stable per-worktree host-port offset
(`POSTGRES_PORT`, `WEB_PORT`, `DATABASE_URL`; the primary checkout keeps the
defaults). So:

- Start services and the dev server through `mise run …` (`docker:up`,
  `dev:setup`, the app's dev task) so the per-worktree env applies — never a
  bare `docker compose up` or a hardcoded port.
- Don't pin a fixed `container_name` or a literal host port in `compose.yaml`,
  and don't hardcode `localhost:5432`/`localhost:3000` in app config — read
  the env vars.
- If two worktrees still draw the same offset, set
  `STEER_WORKTREE_OFFSET=<n>` for one of them rather than editing shared
  files.

**Clean up before the worktree closes.** Containers, volumes, and background
dev servers outlive the git worktree unless torn down:

- Run `mise run docker:clean` (down + volumes + orphans, scoped to this
  worktree's `COMPOSE_PROJECT_NAME` — it won't touch a sibling's stack).
- Stop any background dev server / watcher you launched, freeing its port.
- Leave no orphaned containers, volumes, processes, or held ports behind.


## Context hygiene — delegate heavy runs, keep state in files

Long, multi-phase work bloats the session and risks losing task constraints at
compaction. You cannot see context usage or trigger `/compact` — only the user
can — so keep the working context lean.

- **Delegate heavy runs to a subagent** (a fresh context window) and bring back
  only the structured result, not the whole sweep — how `/steer:audit` fans out
  to `steer-reviewer` and `/steer:work --reviewed` runs its plan gate.
- **Keep durable state in files, not the chat.** Run-state and task-specific
  constraints (decisions made, what to skip, what's unreliable) go in
  `/spec/**` or a sidecar artifact the work re-reads — files survive compaction
  and a fresh session; chat history does not (`/steer:build` →
  `BUILD-STATUS.md`, `/steer:work` → its work marker).
- **Don't offer to save findings to session memory** — private auto-memory is
  invisible to the repo, the PR, and every teammate. Route each fact to its
  canonical home by type: a **bug fix** → a regression test; an **operational
  or behavioral fact** → the app guide / `/spec/HISTORY.md`; an **unresolved
  follow-up** → a linked tracker issue; a **durable design decision** → the
  spine. One home per fact — surface the capture, don't ask whether to
  remember it.
- **Only when the thread is genuinely overloaded** and delegation won't help,
  *recommend* the user `/compact` or a fresh session, pre-composing the
  hand-off (the artifact path + the constraints to carry) — and say plainly it
  is a recommendation you cannot perform yourself.

Full pattern and a worked example: `/steer:reference context-hygiene`.


## Spec workflow

Create the artifact when the trigger fires — don't defer it:

- **Starting a user-facing feature** → `/spec/features/[id]/intent.md` +
  `contract.md`, before or alongside the code — author via **`/steer:spec`**
  (or **`/steer:build`** for a PO). `[id]` is a short kebab-case slug
  (`user-login`, `export-csv`).
- **Architectural or hard-to-reverse choice** (stack, database, auth,
  deployment, a new cross-cutting pattern) → ADR at
  `/spec/decisions/000N-[slug].md` (run **`/steer:adr <slug>`**). The initial
  stack choice is usually the first ADR.
- **Behavior changes** → update the owning `contract.md` in the same PR — plus
  the app guide (`/spec/app/`) if it describes the old behavior, and a
  `/spec/HISTORY.md` entry; see Living documentation.
- **Open questions** → the feature's `intent.md` → `## Open questions`
  (product-level ones in `vision.md`); sweep and answer them with
  **`/steer:questions`** before they rot.
- **A feature that began as a tracker issue** → **`/steer:issues brainstorm`**
  shapes it in the issue, **`materialize`** writes the approved intent to
  `intent.md` as `Status: draft`; an explicit `/steer:spec approve` flips it
  to `approved`. The issue is the work record; the spec stays product truth.

The spec ↔ code coupling rules (drift resolution, what counts as behavior, PO
acceptance) are canonical in the spec-framework reference `/steer:spec` draws
on. Unsure whether something needs a feature spec or an ADR? Ask the dev
rather than skipping it.

**Greenfield** (new product — an idea, brief, screenshots, or a design export):
**bootstrap first** (`/steer:init`, or `/steer:build` for a PO) — the bundled
scaffold **and** the `/spec` spine before feature code; never hand-write
`package.json` / build config / CI from scratch. Then interview to fill
`vision.md`, `users.md`, `glossary.md` (ask, don't invent; product-level
ambiguity → `vision.md` → `## Open questions`), draft feature intents, and get PO
approval before broad implementation. Design exports: read the **local export**
via `/steer:reference design-sources` — never fetch the URL (it 403s).

**A prototype is greenfield too** — "quick" / "just a prototype" / "throwaway"
relaxes the *ceremony* (lighter interview; branch/PR only via solo-trunk mode
below; a GitHub-adopted repo still keeps the issue, closed from the commit — see
Issue-first), **not** the scaffold or the spine. Even a throwaway gets the
bundled scaffold and a minimal `/spec` (vision + the feature intents being
built), auto-documented as features land (`/spec/HISTORY.md`, `/spec/app/`).
`/steer:adopt` is for *un-bootstrapped* pre-existing code, not an excuse to skip
bootstrap now.

**Solo greenfield can run on trunk** — when one person is both PO and dev
pre-MVP, `/steer:init` offers **solo trunk mode**: only the branch/PR ceremony
relaxes; scaffold, spine, tests, and Definition of Done all hold. Mechanics
and graduation are canonical in Commit autonomy.

**Brownfield** (change to an existing product): triage → size it (Change-size
model) → medium+ work writes/updates the spec or ADR first → implement →
update the owning `contract.md` if behavior changed.

**Adopting a whole repo** that never went through bootstrap (a "vibe-coded"
app with no `/spec`): run **`/steer:adopt`** once — reverse-engineer the spec
from the code, triage productionization (Keep/Refactor/Rewrite/Reject in
`PRODUCTIONIZATION.md`), sync in the bundled scaffolding — distinct from a
per-feature Brownfield change.


## Durable decisions land in the spine, not in side-channels

A durable design decision — stack, auth model, data model, architecture, a
locked scope or MVP cut — belongs in `/spec`: a feature's `intent.md`, a
`contract.md`, or an ADR (`/steer:adr`). That is the single source of truth a
teammate inherits from the repo. Scoping conversation, chat summaries, and
**assistant memory** are working notes, not the record — never let a decision
survive only there, where the repo carries no trace of it.

**No `/spec` spine yet? Bootstrap before you commit the decision, not after.**
On a repo with no spine, do not persist architectural choices or a locked scope
to memory or prose as a stand-in for the missing spine — that is the
single-source-of-truth break this rule exists to prevent. Run `/steer:init`
(greenfield) or `/steer:adopt` (existing code) first so the decision lands where
it is traceable and reviewable in the bootstrap PR. The scoping dialogue itself
is fine and expected — `init`'s own interview is where it belongs; what waits
for the spine is the **durable capture** of what was decided. See bootstrap
precedence in the router and Living documentation (`32-living-docs`).


## Living documentation — document in parallel, not after

The PO/dev speaks plainly; **you** translate it into durable artifacts *as the
work happens*, never in a wrap-up pass. When conversation or implementation
reveals a requirement, constraint, assumption, risk, trade-off, or decision,
update (or propose) the owning artifact **in the same change as the code**:

- Intent, goals, acceptance criteria → the feature's `intent.md` (scope
  changes need PO approval); behavior/data/API decisions → `contract.md`;
  hard-to-reverse choices → ADR.
- Ambiguity → `## Open questions` — **never guess an answer into the spec**.
- Usage, workflows, roles, configuration, limitations, troubleshooting,
  release notes → the app guide (`/spec/app/`).
- Tech stack, the apps/packages map, cross-component data flow → root
  `ARCHITECTURE.md` — updated, with the linked architecture diagram
  (`/spec/design/architecture.md`), in the same PR that changes them.
- Visual identity, reusable design tokens → root `DESIGN.md`, seeded when the
  first UI lands and grown on the 3+ rule (Design sources). The PR that
  establishes the stack or first app also retires the scaffold's now-false
  placeholder prose — a stub left after the thing it describes exists is
  drift.
- What changed, why, who asked, refs → append to `/spec/HISTORY.md`, one
  short entry per merged change or ratified decision.

PO-facing artifacts (intent, vision, app guide) stay plain-language;
dev-facing ones (contract, ADR) stay precise enough to implement and review
against. A declined proposal becomes an open question, not silence. Full
conventions + worked examples: **`/steer:reference traceability`**.

**Applying a decision already made is not a new decision.** Propagating a
settled choice into the artifacts that should reflect it is living-docs
upkeep: make the edit in the same change and let the **PR be the gate** (rule
`95-not-the-gate`). Pause for a yes only when the *decision itself* is unmade
— a genuine product / policy / architecture call, anything under High-risk
areas — or when an edit would clobber filled-in content.


## Issue tracker integration (client-agnostic)

Products use whatever tracker the client has (Jira, GitHub Issues, Linear,
Azure DevOps, …). **`/spec/tracker.md`** declares the system + ref format —
read it before referencing work items; if missing, ask and create it from the
bundled template. Refs live in `intent.md`'s `> Tracker:` line, the PR
description (tracker's own linking syntax), and `HISTORY.md` `Refs:`. Copy a
tracker item's acceptance criteria into the intent — the spec is the in-repo
source of truth; the ref points back. **Keep a question in the spec's
`## Open questions`** (structured `Q-NNN`) when it's local to one feature and
answerable while specifying it; **promote it to an issue** when it needs a named
owner, blocks multiple features, needs stakeholder/research input, or could
outlive the session — then put the ref in the question's `tracker:` field. The
issue is the decision *workflow*; the spec (or an ADR) is the durable *record*.

When the tracker is **GitHub Issues**, **`/steer:issues`** is the high-level
lifecycle workflow (capture → triage → brainstorm → materialize → decompose →
status → reconcile), and **`/steer:tracker-sync`** is the low-level gateway it
routes all reads/writes through (MCP-first → `gh` → manual floor). Agent-authored
issues follow the machine-readable contract (stable headings + hidden markers);
`/spec` stays product truth, the issue is the work/decision layer. Other trackers
use the manual export.


## Issue-first (GitHub-adopted repos)

When `/spec/tracker.md` declares `system: github`, every
**implementation-affecting mutation** — code, config, infrastructure, or
behavior — has a GitHub issue **before the first repository mutation**. Out of
scope (no issue needed): `/spec` edits, documentation, generated output,
lockfiles, and a plugin-maintenance `/steer:sync` on its own `feat/sync`
branch (structural, never app source). Reuse the issue the user names;
otherwise find-or-create one through `/steer:tracker-sync` — an explicit
"fix / implement / add / create" request does **not** need confirmation to
create the issue.

- **Capture-only and ambiguous language do not auto-create.** "Note this" /
  "we should eventually…" is captured deliberately, never inferred into a
  batch of issues. A large inferred batch takes one confirmation;
  security-sensitive public disclosure takes human review.
- **Implementation runs through `/steer:work`** — claim, branch, implement,
  test, open the PR, transition the issue. Commit, push, and the PR are
  autonomous under Commit autonomy; **merge and deploy are never implied**.
- **Solo trunk keeps the issue, drops the branch/PR** (Commit autonomy) —
  close it **from the trunk commit** (`Closes #N`). The issue stays the
  audit-evidence anchor (Audit-aligned delivery).
- **Discovered out-of-scope work** gets its own linked issue
  (related/blocking), not silent scope creep in the current one.
- The scaffold pre-authorizes `gh issue create` / `gh issue edit` under
  `allow`; the MCP write tools (`mcp__github__issue_write` /
  `sub_issue_write`) sit under `ask`, but `/steer:tracker-sync` and
  `/steer:report` re-grant them via their own `allowed-tools`. A create that
  is *still* blocked is a **host-permission gate, not a missing issue** —
  don't loop retrying; confirm with the user, or have them run
  `!gh issue create …` under their own identity, then continue. (Full
  rationale: ISSUE-WORKFLOW.md → "Host gating".)

Non-GitHub trackers and repos without a `/spec` spine keep today's flow.
**Calling work a "prototype" does not waive it** — the only durable opt-out
from the per-feature branch/PR is solo-trunk delivery mode.


## Testing rules

- Every feature change **includes or updates automated tests** in the same PR — never "later."
- Every bug fix **MUST add a regression test** that fails before the fix and passes after. This is a hard rule.
- Do **not** delete or skip failing tests to make CI pass. Fix the cause, or explicitly remove the behavior and say so in the PR.


## Coverage rules

- Coverage is a **signal to find untested behavior, not a target to hit** — never
  write shallow tests, or relax assertions, to move a number.
- **Cover what you touch:** new and changed code paths ship exercised. Prioritize
  **critical paths, branches, and error handling** over blanket line %.
- Coverage is **measured and visible every run** (per-stack tooling in `CONVENTIONS`).
  A coverage drop on changed code is **drift** — surface it for human review, never
  silently (see Drift gates).
- No global "fail under N%" vanity gate; CI gates only **changed-line** coverage. The
  reviewer judges adequacy (see You are not the gate).


## Commit autonomy

Commits are cheap and local — the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Never pause work to ask
"should I commit / push / open the PR?".

Delivery runs in exactly **two modes**, keyed to GitHub branch protection. The
product `CLAUDE.md` `## Delivery mode` marker caches which one applies
(`<!-- steer:delivery-mode=pr-flow -->` vs `=solo-trunk`; absent → pr-flow);
`/steer:protect` moves a repo between them, and there is no third mode.

- **PR flow (protected `main` — the default).** Work on a branch off `main` —
  never commit or push to `main` directly. Use the repo's branch convention,
  else `feat/*` / `fix/*` (`/steer:work` defaults to `issue/<number>-<slug>`).
  On `main` with changes? Create the branch first, then commit. When the work
  is **complete** (Definition of Done holds, end-of-session checklist clean),
  **push the branch and open the PR without asking** — announce it, don't
  request permission. First push of a fresh branch:
  `git push -u origin <branch>`. **Merging the PR is the one step that waits
  for the dev; everything before it (branch, commit, push, open PR) does not.**
- **Solo trunk mode (unprotected `main` — pre-MVP greenfield).** If the product
  `CLAUDE.md` declares solo-trunk, commit **directly to `main` and push without
  asking** — no `feat/*` branch, no per-feature PR. CI still runs on every
  push; the spine, tests, and Definition of Done are **unchanged** — only the
  branch/PR ceremony relaxes. On a GitHub-adopted repo the issue is still
  required and closed from the trunk commit (`Closes #N`), not via a PR (see
  Issue-first). **Graduate** — run **`/steer:protect`** — the moment the MVP
  works, you first deploy, or a second contributor joins, whichever comes
  first. While a **local** graduation signal (a deploy target or a `prod`
  branch) stands unaddressed, trunk pushes stop being autonomous — each one
  waits for a human yes until the repo graduates; a second contributor is
  caught on demand by `/steer:protect` and `/steer:audit`, not at push time.
- **Declared-but-unprotected PR flow is a gap, not a mode.** If the repo runs
  pr-flow but `main` has no protection, the flow above applies unchanged — you
  still never merge — but say the wall is missing and recommend
  `/steer:protect`. Where protection is genuinely unavailable, record the
  exception in an ADR; `/steer:protect verify` and `/steer:audit` keep
  flagging it.
- In a GitHub-adopted repo, the **first mutation** of a unit of work
  presupposes an active GitHub issue (see Issue-first) — autonomy is unchanged
  once that issue exists.
- **Commit without asking** whenever a coherent unit of work is done — tests
  pass, lint clean, builds. Keep commits small, with a
  **[Conventional Commits](https://www.conventionalcommits.org/)** subject:
  `type(scope): summary`, imperative mood; mark breaking changes with `!` or a
  `BREAKING CHANGE:` footer. Commit messages are **not** the release
  changelog — that stays the curated `CHANGELOG.md`. Full detail:
  `/steer:reference conventions`.
- **After pushing, watch CI to conclusion and fix a red build before treating
  the work as complete** — don't hand the dev a running or red PR and stop.
  (**Merge and deploy stay human-gated in every mode** — never `gh pr merge`,
  never deploy, never push to a protected `prod` branch.)


## Definition of Done

A change is done when **all** of these hold. Reviewers check most of them; CI
enforces only a thin floor. In **solo-trunk** there is no reviewer, so the
scaffold's CI runs that floor on push to `main` — the changed-line coverage gate
(rule 41) and the advisory spec-drift warning (rule 55) — as the only automated
backstop. It is a floor, not the whole list: the rest is still on you.

- [ ] Code follows existing patterns in the touched app/package.
- [ ] Tests added or updated; bug fixes include a regression test that **fails before the fix and passes after**.
- [ ] Changed code is covered — critical paths, branches, and error handling exercised; no unexplained coverage drop on the lines this change touches (see Coverage).
- [ ] CI passes — watched to green after push, not assumed (see Commit autonomy).
- [ ] Spec updated if behavior changed — the relevant `contract.md`, or `intent.md` if scope changed (see Spec workflow).
- [ ] Living docs in sync — app guide (`/spec/app/`) updated if user-facing behavior or configuration changed; `ARCHITECTURE.md` updated if the stack, an app/package, or cross-component data flow changed; `/spec/HISTORY.md` entry appended (see Living documentation).
- [ ] Review-sensitive classes flagged in the PR description (see Drift gates); tracker ref in the PR — or, in solo-trunk, in the closing commit (see Issue tracker).
- [ ] GitHub-adopted repo: the change has a GitHub issue; its `steer:state` reflects reality (work in progress → `validate`, never `done`); the issue is referenced with the correct closing/non-closing relation — from the PR in PR flow, or from the closing commit (`Closes #N`) in solo-trunk; discovered out-of-scope work was filed as separate linked issues (see Issue-first).
- [ ] Architectural choices captured as an ADR under `/spec/decisions/`.
- [ ] High-risk areas were scoped first (see High-risk areas).
- [ ] A dev approved the PR — except in solo-trunk (pre-MVP), where there is no PR gate (see Commit autonomy).

**Hotfix exception (see Hotfix / incident fast-path):** under a declared production
hotfix, items above may be **deferred** to the mandatory post-incident follow-up —
**never waived**. The follow-up backfills the issue, the spec/ADR, and the
`/spec/HISTORY.md` entry so this list is satisfied once the fire is out.


## Verify loop — iterate against the harness, don't flail

Before writing code, turn the task into a **verifiable end state** — name the
check that will prove it done (a failing test, a build that passes, a command
whose output you can read). "Add validation" becomes "tests for the bad inputs,
then make them pass." A vague goal you can't check is a goal you can't finish.

- **State the assumption, don't bury it.** When a request has two readings,
  surface the one you're taking (or ask) **before** writing against it — never
  silently pick an interpretation and build 200 lines on it.
- **Loop until green, then stop.** Run the harness (test, lint, typecheck,
  build), fix what it reports, re-run — until it passes. The harness is the
  judge, not your reading of the diff.
- **Cap the loop.** Bound the fix→re-run cycles; if repeated attempts don't
  converge, **stop and report what blocked you** with the failing output — don't
  thrash or paper over the check (see Testing: never delete/skip a failing test).
- **Never loop on uncheckable work.** Judgment calls, design decisions, and
  long-compute runs (training, large sweeps, deploys) have no fast pass/fail —
  those are a human's call or a one-shot script, never an open-ended loop.


## Deployment & environments

How code reaches users. Deploy/release logic is a high-risk area (see High-risk
areas) — validate in non-prod before prod, and scope pipeline changes with the
dev first. AWS/Terragrunt specifics live in the infra README (`/infra/README.md`
for a nested infra dir, the root README for an infra-profile repo); rationale in
`/steer:reference conventions`. The AWS app-promotion model below is the default —
an infra-profile repo with a different target records its flow in an ADR.

- **Environments** — `non-prod` (shared validation) and `prod`. Every feature PR
  also gets an isolated, auto-provisioned **review app**, torn down when the PR
  merges or closes. The review-app mechanism is product-specific — record it in an
  ADR (see Decision capture).
- **Promotion** — merge to `main` **auto-deploys non-prod**. Prod is gated by a
  **reviewed PR from `main` into a long-lived `prod` branch**; merging that PR
  **auto-deploys prod**. Never push directly to `prod`. The branch-protection
  approval on `prod` *is* the production gate (run `/steer:protect`), standing in
  for deployment-environment approvals that GitHub Enterprise would otherwise
  provide.
- **Observable by default** — a deployed environment ships logs, metrics with
  alarms, error tracking (Sentry), health checks, and alerting routed somewhere a
  human sees it. "Deployed but unobservable" is not done; capture the wiring in
  `ARCHITECTURE.md`.
- **Rollback** — every prod deploy has a known rollback: revert the `prod` merge or
  redeploy the prior SHA. Database migrations are expand/contract so the previous
  version keeps running through a deploy (see High-risk areas).
- **Secrets & config at rest** — injected at deploy/runtime, never baked into images
  or CI logs (see Secrets handling).


## Autonomous loops — automate the navigation, never the authority

An **autonomous loop** is a scheduled automation (a cron workflow, a Routine)
that wakes on its own, discovers work — CI failures, open issues, drift — and
drives it through steer's skills unattended. It removes the prompting, **not**
the responsibility: still ship code you *confirmed* works (Definition of done).

- **A loop closes only up to a human gate — never through one.** It may
  discover, triage, draft in an isolated worktree, verify, push its **own work
  branch**, and open a PR — the merge review is the human gate (Commit
  autonomy). It **stops** at every authority gate: issue creation beyond an
  explicit ask (Issue-first), ADR ratification (High-risk), and merge / deploy
  / push to `main` or any protected branch / real secrets. Loop-opened PRs are
  **drafts by convention** — the deliberate signal that nobody attended the
  run; a reviewer flips one to ready.
- **A loop presupposes PR flow.** Protect `main` first (`/steer:protect`);
  never point a loop at a solo-trunk repo — unattended direct-to-`main`
  delivery has no gate at all.
- **Split ideation from verification.** The drafting agent never clears its own
  change — route the check through an independent reviewer (`steer-reviewer`,
  `/steer:audit`, the test harness).
- **Keep durable state outside the model.** A loop's memory is the tracker +
  `/spec/**` (issues, `HISTORY.md`), not chat context — record what it did and
  what's left so the next run resumes instead of repeating.
- **Only loop on checkable work.** Judgment calls, design decisions, and
  long-compute runs have no fast pass/fail — the loop surfaces them for a
  human, it never decides them.
- **Scaffold loops with `/steer:loop`** — never hand-roll an automation that
  can cross a gate.


## Drift gates — surface before merge

Drift — any meaningful mismatch along intent ↔ spec ↔ contract ↔ tracker ↔ app
docs ↔ tests ↔ delivered behavior — is resolved by **explicit human review,
never silently**: you *surface* it before merge; the reviewer resolves it (fix
code, fix artifact, or record the accepted divergence). Flag these
review-sensitive classes in the PR description **the moment you notice one**
(the scaffold's PR template carries the checklist): **intent drift · contract
drift · undocumented behavior change · security-sensitive ·
compliance-impacting · operational (deploy/CI/infra) · local setup or
deployment changed · app docs invalidated · architecture/stack drift
(`ARCHITECTURE.md`)**. A flagged class blocks merge
until the reviewer explicitly resolves it — you may not waive your own flag.
Periodic sweeps: `/steer:audit` (`code` health, `spec` conformance).

The scaffold's CI also carries an **advisory** `spec-drift` job that *warns*
(never blocks) when a change touches application behavior without updating a
feature `contract.md` / `intent.md` or `spec/HISTORY.md` — a machine backstop for
the *undocumented behavior change* class. It runs on PRs and on push to `main`
(the latter is the only enforcer in solo-trunk, which has no PR). A warning is a
prompt to do the right thing, not a substitute for the flag: still flag the class
and update the spec in the same change.


## High-risk areas

These require **explicit dev scoping before broad changes** — do not propose
architectural changes here speculatively:

- **Auth & sessions** — sign-in/up, password reset, token issuance, session invalidation
- **Authorization & permissions** — role checks, access control, multi-tenancy boundaries
- **Database migrations** — schema changes, backfills, migration scripts
- **Infrastructure** — anything in `/infra`, especially networking, IAM, secret stores (Parameter Store / Secrets Manager)
- **Secrets handling** — anything reading, writing, or transmitting credentials/keys/tokens
- **Deletion logic** — hard deletes, cascading deletes, retention/cleanup jobs
- **Billing & payments** — pricing, charging, refunds, subscription state
- **Deployment & release logic** — CI/CD workflows, release scripts, feature-flag rollouts

Handling: scope with the dev **before** any code; contract or ADR first;
smaller PRs; line-by-line review; validate in non-prod before prod. `@claude
implement this` is not appropriate here without explicit in/out scope.

**Pre-production relaxation:** these gates protect real systems and real data.
While a product is **pre-production** (nothing deployed, no real users or
data), high-risk areas may be built for real locally without prior dev
scoping — document the choices as you go (`contract.md`, ADR for
hard-to-reverse picks, the feature's `intent.md` → `## Open questions` for open
items) and list them
in the PR description so dev review hardens them at productionization.
"Pre-production" is a property of the **product, not the laptop**: working
locally in a deployed product still produces migrations/deletions that reach
real data on merge — no relaxation there. **Never relaxed**, even
pre-production: real secrets/credentials, `/infra`, deploys, real third-party
calls.


## Hotfix / incident fast-path

A production incident is **high-risk and time-critical at once** — the one case
where full ceremony and speed genuinely conflict. The hotfix lane is the **only
sanctioned speed lever**. Run it via `/steer:work --hotfix`.

**Objective entry condition (not self-asserted).** The lane opens only when the
change targets an already-**deployed production** system with real users or data
(the rule 60 predicate) **and** there is an active incident, outage, or
regression. "Urgent" feature work, a looming demo, or a pre-MVP repo with nothing
deployed are **not** hotfixes — they take the normal lane.

**What the lane relaxes — ceremony and ordering, never authority:**

- **Issue after-the-fact.** File or backfill the GitHub issue as soon as
  practical instead of before the first edit; work on a `hotfix/<n>-slug` branch
  so issue-first reconciliation recognises the sanctioned lane. This relaxes
  issue-first *timing* (rule 36), not its existence.
- **Expedited single-reviewer.** One reviewer approval suffices, in place of the
  change-size / high-risk scoping ceremony (rules 60, 80). The PR / merge **human
  gate still stands** — no self-merge.
- **Deploy on the fix.** Deploying the fix is *policy-permitted* (rule 52 —
  validate in non-prod where feasible). Pushing the `hotfix/` branch and opening
  the PR are autonomous delivery steps (Commit autonomy); as everywhere, deploy
  is **never auto-executed** — merge and deploy stay human-gated.

**Mandatory follow-up once the fire is out (not optional).** Restore traceability:
backfill/finish the issue, write the spec or ADR if a durable decision was made,
and append a `/spec/HISTORY.md` entry. Definition of Done is **deferred under this
lane, never waived** (rule 50). A hotfix without its follow-up is unfinished work,
not a shortcut earned.


## Secrets handling

Secrets (DSNs, API tokens, DB credentials, `AUTH_SECRET`, AWS keys) are a
high-risk area — scope with the dev before touching how they are read, written,
or transmitted.

- **Never commit secrets** — not in code, configs, `mise.toml`, specs, or
  commit messages.
- **Local development:** config lives in a git-ignored `.env` / `.env.local`.
  When setting up or running an app, make sure it exists with the base
  variables the app needs to boot — local Compose service URLs (e.g.
  `DATABASE_URL` → the local PostgreSQL) and freshly generated local-only
  secrets, never values copied from deployed environments. Document variable
  *names* (not values) in the app's `.env.example`. A Claude Code worktree
  (`claude --worktree`) starts from git refs only, so the git-ignored `.env` is
  absent there — the repo-root `.worktreeinclude` carries it (and other local
  config) into each new worktree so the app still boots.
- **Deployed environments:** secrets live in **SSM Parameter Store
  (`SecureString`)** by default — it is cheaper than Secrets Manager and covers
  most needs (DSNs, tokens, DB credentials). Use **AWS Secrets Manager** only when
  you actually need its features: automatic rotation, cross-account sharing, or
  large/binary values. Either way they are injected at deploy/runtime — never
  baked into images or CI logs. Non-secret config may live in `mise.toml`'s
  `[env]` block; secrets must not.
- A committed secret is compromised: stop, tell the dev, and rotate it — don't
  just delete the line.


## Audit-aligned delivery (SOC 2 / ISO 27001)

The workflow is **aligned with** SOC 2 and ISO 27001 delivery expectations —
say "aligned", never "compliant": no workflow or artifact makes a product
compliant; certification scope, compliance accountability, and
production-readiness approval stay with humans. The artifacts double as audit
evidence — keep the chain intact: traceability (intent → spec → tracker ref →
PR → `HISTORY.md`), review evidence (dev-approved PRs, drift flags, DoD),
change history (ADRs + action history), and access-conscious secure defaults
(secrets rules, high-risk gates, branch protection). Evidence map:
`/steer:reference traceability`.


## Change-size model

Match the workflow to the change. When uncertain, size **up**.

- **Tiny** (≈<20 lines, no logic change — copy, padding, typo): just open a PR.
- **Small** (≈<200 lines, contained behavior change): confirm intent; update `contract.md` if behavior changed.
- **Medium** (new screen/feature/capability): write `intent.md` first, get PO approval, then implement with `contract.md`.
- **Large** (crosses areas, new pattern, touches infra): write an ADR in `/spec/decisions/` first, agree with the team, then ship in small PRs.
- **Risky** (any high-risk area, regardless of line count): follow high-risk handling above.


## Patterns we follow (baseline)

Org baseline stated as principles; each names the **default-stack** instance in
parens so it stays actionable there and still applies on any other stack. A
product's own `CLAUDE.md` adds team-learned patterns on top. Full patterns +
anti-patterns prose: `/steer:reference conventions`.

- **Typed by default** — static typing on wherever the language supports it;
  model the type rather than reaching for an untyped escape hatch. *(TS
  `strict`; Python: type hints checked with a type checker.)*
- **All data access goes through a parameterized query layer — never raw or
  string-interpolated SQL.** Schema is defined in code and changed via
  committed, reviewed migrations; no ad-hoc schema edits. *(Drizzle + Drizzle
  Kit; Python: SQLAlchemy 2.x + Alembic.)*
- **Validate every external input through a defined schema at the boundary
  before use** — request inputs, external API responses, config and data
  files, env vars — and derive types from that schema rather than hand-writing
  them. One validated config module, not scattered raw env reads.
- **Server-first** — secrets and DB access stay server-side; client code is
  explicit and lean; only genuinely public values reach the client. *(Next.js
  Server Components / `NEXT_PUBLIC_*`.)*
- **Domain logic lives in shared, testable modules**, not in UI components or
  route handlers — keep handlers thin. *(Monorepo `packages/`.)*
- **Nothing silenced** — no empty `catch` / swallowed errors (unexpected
  errors go to Sentry with context); no escape hatches without a why-comment
  (`any` casts, `@ts-ignore`/`@ts-expect-error`, wholesale lint-rule
  disabling).
- **Lockfiles are maintained, not optional** — committed and updated in the
  same change that touches their config/deps; never deleted or ignored to
  dodge an error. *(`mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
  `.terraform.lock.hcl`; mise only writes `mise.lock` if it already exists —
  restore a missing one first.)*
- **Every import resolves to a declared dependency** — added to the manifest
  (and lockfile) in the same change; a plausible-looking undeclared package
  name is a hallucinated dependency that breaks in a clean environment.
  *(`package.json`; Python: `pyproject.toml`.)*
- **ASCII in code and values** — typographic characters (em/en dashes, arrows,
  smart quotes, ellipsis, non-breaking spaces) belong in prose and docs, never
  in code, identifiers, config keys/values, or strings bound for an external
  API — use the ASCII equivalent. Strict validators reject the rest.
  *(Rationale: `/steer:reference conventions`.)*


## Output discipline — earn every line

Default to less. Every line — chat, code, or committed prose — must carry
something the reader can't already see. Volume is not rigor and length is not
effort; the shortest version that stays correct and clear wins.

- **Keep responses tight.** Lead with the result or the change. Cut preamble,
  self-narration, and restating the request back. Don't list options you won't
  take, pad with caveats, or recap what you just did. Expand only when asked, or
  when a real decision needs the context.
- **Comments are the exception, not the default.** Let names and structure
  explain; comment only the non-obvious *why* — plus the why-comment an escape
  hatch requires. No comments that restate the code, narrate obvious steps,
  banner sections, or leave old code commented out. Match the file's existing
  comment density.
- **Write the least code that does the job.** Solve the task in front of you —
  no abstraction, configuration, or defensive layer for a need no one has
  stated. Fewer lines to read is fewer lines to review and maintain.
- **Durable prose stays lean too.** Specs, ADRs, PR descriptions, and docs
  inform, not impress — short declarative sentences, no hedging or ceremony.
  Same discipline applies to the standards themselves.


## Shareable views → Claude Artifacts

When a skill's output is a **shareable, at-a-glance view** someone hands to a
stakeholder — a feature summary, a report/dashboard, a release timeline, a
capability menu, a fillable questionnaire — render it as a **Claude Artifact**
(a default-private hosted page on claude.ai), not a wall of terminal text. Fall
back to inline Markdown where the Artifact tool is unavailable — the fallback
is not a failure.

An Artifact is a **derived view, never a source of truth**: every visual
encodes a real value the source (spec, tracker, audit) actually contains —
never fabricate a status, date, count, or finding, and never advance a marker
past what the source records. Always an on-demand render or an offer — never
auto-generated per feature or on a schedule — and never carrying secrets or
(on a stakeholder page) internal detail. Its only write is the page HTML to a
**system temp dir, never under the repo tree**; don't persist the URL in the
repo.

Style the page from the repo's `DESIGN.md` tokens when present, else the
`artifact-design`/`dataviz` house default — never an invented brand. A fillable
page returns data **only through its exported, machine-keyed document**
ingested by its owning skill (the PO questionnaire → `/steer:intake clarify`).

Mechanics, the full derived-view discipline, the styling contract, the
Markdown-fallback shape, and which skill renders what:
`/steer:reference artifacts`.


## Design sources & UI

Most features have **no design export, or only a partial one** — that is the
normal case, not a blocker. When an export *is* committed (Claude Design ZIP,
Figma, screenshots), read the **local export** — Claude **cannot** fetch a Claude
Design URL (it 403s). The export is authoritative for the **visual behavior and
flow it actually shows**; the spec for what the system does; gaps and conflicts
go to the feature's `intent.md` → `## Open questions`. It is a **spec to realize
in the standard stack, not code to ship**: its delivery tech (UMD React,
in-browser Babel, hand-rolled CSS) is disposable — serving the prototype runtime
is an **ADR-gated, kill-dated exception**, never the default.

When the design is absent or partial, **build the UI deliberately instead of
defaulting to generic AI aesthetics**: the **`frontend-design`** plugin
(installed from this marketplace) carries that craft; these standards scope it to
a professional/enterprise default, the standard stack (Next + TS + Tailwind), and
accessibility.

Whichever way a feature's UI originates, **capture the reusable decisions in
`DESIGN.md`** (repo root, or `apps/<app>/DESIGN.md`) — populated as you build,
promoting anything that recurs — so every feature stays visually uniform. Full
walkthrough (artifact paths, what to read, what not to invent, realize-vs-serve,
no-export build): run **`/steer:reference design-sources`**.


## You are not the gate — the DEV is

You have no path-based permission boundary in managed product repos — propose
changes anywhere (`/apps`, `/packages`, `/configs`, `/spec`, `/infra`). The dev
reviewing the PR is the hard gate and catches out-of-scope or risky edits. When
unsure about scope, ask in a PR comment before making sweeping changes.


## When steer itself misbehaves, report it upstream

steer is maintained centrally in `element22llc/e22-plugins`. When the plugin's
**own machinery** misbehaves, treat it as a plugin defect to report — not a
thing to silently work around:

- A SessionStart **self-fault notice** flags recorded hook faults.
- A skill or rule gives **contradictory or impossible** instructions.
- A referenced **template, script, or helper is missing, malformed, or crashes**.

This is about steer's defects only — ordinary product-code errors, failing
tests, or your own mistakes are not plugin faults and do not belong here.

On any of the above: surface it plainly, then file it upstream with
`/steer:report`. It **auto-files** after scrubbing and deduping — no confirmation
step — and the scrub **redacts or omits** anything it can't safely classify
(secrets, absolute paths, product code) rather than asking, so nothing sensitive
reaches the shared repo. If you only worked around the defect to keep going,
still report it so it gets fixed for everyone.


## End-of-session checklist

Before wrapping up a working session, run this checklist and **report** its
state to the dev — don't silently close out, and don't turn the report into a
round of per-item confirmations (satisfied items need no ack; only genuinely
open items need the dev). Track open items with your todo tooling so nothing is
dropped:

- [ ] New feature → `intent.md` + `contract.md` created or updated (Spec workflow)?
- [ ] Architectural choice made → ADR written under `/spec/decisions/`?
- [ ] Tests added/updated for the change; bug fix has a regression test?
- [ ] Spec/code drift resolved now, not deferred to "later"? Review-sensitive changes flagged for the PR (Drift gates)?
- [ ] Living docs in sync — app guide updated for behavior changes, `/spec/HISTORY.md` entry appended, tracker refs recorded?
- [ ] Any unfinished work or known gaps surfaced explicitly to the dev?
- [ ] Working in a worktree being closed/removed → local services and background dev servers it started torn down (`mise run docker:clean` + stop watchers), leaving no orphaned containers, volumes, or held ports (Parallel worktrees)?
- [ ] GitHub-adopted repo: the active issue reflects progress, branch, blockers, and validation status; new unrelated bugs/gaps/follow-ups were captured as separate linked issues; the PR references the issue with the correct closing/non-closing relation?
- [ ] Any remaining scaffold placeholders flagged or resolved? (Unbootstrapped repo or legacy fork: run `/steer:init`.)
- [ ] All finished work committed on the working branch; if the change is complete, branch pushed and PR opened — or, in solo-trunk, the trunk commit pushed — with CI watched to green (see Commit autonomy)?
- [ ] Solo trunk mode and the MVP now works, you've deployed, or a second contributor joined → graduate to the PR flow via `/steer:protect` (Commit autonomy)?

If any item can't be satisfied, say so plainly rather than implying the work is
complete.
