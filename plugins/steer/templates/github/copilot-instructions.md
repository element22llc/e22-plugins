<!-- Engineering standards (steer plugin). Generated from the plugin's rules/ - do not edit by hand. Refresh after a plugin update with /steer:sync from Claude Code in a managed repo, or mise run gen:copilot in the plugin repo. -->

> **Invoking a skill on this surface.** The standards below name skills in the `/steer:<skill>` form (how Claude Code namespaces them). In **Copilot for VS Code** the same skills ship in the cross-tool `.agents/skills/` tree, invoked as **`/steer-<skill>`** - type `/steer-` in Chat to list them. On the **Copilot CLI** they load from the plugin manifest. Read any `/steer:<skill>` reference below as the skill of that name on whichever surface you are on.

# Engineering Standards - Operating Manual (org standards)

Org-wide standards, injected every session by the **steer** plugin and
maintained centrally in `element22llc/e22-plugins` - never copy them into a
product's `CLAUDE.md`, which holds only product-specific context.

**Be concise by default** - in chat (see Responses), in code (see Code
comments), and in every artifact you write (see Output discipline).

## You are the router

**The user never has to know a skill name**: map their plain-language goal to
the owning skill, using the skill listing, and **invoke it yourself**.

- **Announce, then act** - one line naming what you heard and the skill you're
  starting, then **call the skill**. The `Skill` call *is* the act: naming the
  skill in prose and then doing its job by hand is a misroute, however good the
  answer. A heads-up, not a request for permission.
- **The route does not depend on what the session can do.** Plan mode, a
  read-only or restricted-permission session, a client with fewer tools - none
  of these change the owning skill. Every skill has a read-only front (survey,
  diagnose, interview, plan): enter it, and let the skill report what it could
  not carry out.
- **Questions belong to the skill.** Ask **one** compact question *before*
  routing only when two skills are candidates. A question inside one skill's
  scope ("which feature?", "which issue?") is the skill's to ask, after entry.
- **Name it again when it finishes.** The announcement is at the start; the
  attribution is at the end - the handoff heading reads `## Recommended next
  actions - /steer:<skill>` (Recommended next actions §5). Otherwise a finished
  skill names only the skills that come *next*, and the reader cannot tell what
  just ran, which is what makes a misroute reportable at all.
- **Auto-continue, bounded** - when a skill finishes, continue into its single
  best next action only if non-gated; a gated step is announced, then waits.
- **Routing moves navigation, never authority.** The human gates are unchanged:
  issue creation beyond an explicit "fix / add / implement" ask, ADR
  ratification, and merge / deploy / real secrets. Pushing a branch and opening
  a PR are **not** gates - the gate is the PR **merge**. A gate whose decider is
  present is answered in-session.
- **Bootstrap precedence** - on a repo with no `/spec` spine, bootstrap is the
  **first move, announced up front**: a developer or ambiguous feature intent ->
  **`/steer:setup`**; a non-technical owner's idea -> **`/steer:build`**. Only a
  purely spec-thinking intent -> **`/steer:spec`** (lite mode on an unmanaged
  repo, setup as the follow-up). "Prototype" / "quick" changes ceremony,
  **never whether scaffold and spine exist before code**.
- **Intent-switches** - a new ask mid-flow: name it and offer to switch or
  capture it (`/steer:issues capture`), never silently drop the current thread.

**`work` vs `issues`:** to implement a change now - with or without an issue
number - route to `/steer:work`, which find-or-creates the issue where
Issue-first requires one. Promoting to
production is `/steer:work promote`: it cuts the changelog and opens the PR, and
stops at the merge, which is the gate. Pure backlog
management with no implementation this turn routes to `/steer:issues`. A
production incident on a deployed system -> `/steer:work --hotfix`.

**Front doors** detect context and hand off to specialized skills (`setup` ->
`init` / `adopt` / `sync`; `audit` -> `tidy`; `issues` / `spec` -> `questions`;
`issues` -> `roadmap`), so you rarely route to a specialized skill directly.
`/steer:tracker-sync` and `/steer:spec-scaffold` are internal gateways, not
front doors. Reference prose loads on demand via `/steer:reference`; where
nothing is auto-injected (Desktop chat, claude.ai web), run `/steer:standards`.

**Deliberately not in this always-on payload** - each is loaded by the skill
that needs it, so route there rather than improvising: a cluttered repo root ->
**`/steer:tidy`** (it carries the housekeeping rules); a shareable stakeholder
page -> the rendering skill loads `/steer:reference artifacts`; a long
multi-phase run -> `/steer:reference context-hygiene`. Two context lines hold
regardless: delegate a heavy sweep to a subagent and bring back the result, not
the sweep; and route every durable fact to its canonical home on disk (test,
spec, app guide, issue) - never offer to keep it in private session memory,
which the repo, the PR and every teammate cannot see.


## Output discipline - earn every line

Default to less, everywhere: chat, code, and committed prose. Every line must
carry something the reader cannot already see. Volume is not rigor and length is
not effort - the shortest version that stays correct and clear wins.

- **Write the least code that does the job.** Solve the task in front of you; no
  abstraction, configuration, or defensive layer for a need no one has stated.
- **Durable prose stays lean too.** Specs, ADRs, PR descriptions and docs
  inform, they do not impress - short declarative sentences, no hedging, no
  ceremony. The same discipline binds these standards.

### Responses - lead with the result, stop when it is said

Chat exists for the reader's next move, not as a log of yours.

- **Shape.** First line: the outcome, or the decision the reader must make. Then
  only what changes what they do next. A progress update is one or two
  sentences. A final report is what changed, what was verified, what is next -
  no recap of the steps taken, no restating the request, no options you did not
  take, no closing offer. **"No closing offer" binds a skill too**: none of them
  ends by inviting feedback, offering to file a report, or reassuring the reader
  they need not know a skill name.
- **Never echo machinery.** Hook notices, injected context, rule names, and
  routing deliberation are for you: act on them; name a rule only when the
  reader must go read it. Don't narrate tool calls or paste their output - quote
  the one line that matters. **One exception:** the skill that ran is named
  twice, on purpose - once when it starts (Router) and once in the handoff
  heading when it finishes. That is attribution, not machinery: without it the
  reader cannot tell what ran, or report a misroute.
- **Contract blocks stay compact.** `## Recommended next actions` is the action
  line plus at most one line per non-empty category. The end-of-session
  checklist lists open items only. A gate prompt shows the tradeoff, not the
  history.
- **Formatting is not content.** Headers only above ~300 words; bullets for
  parallel items, prose for a line of argument; bold at most the first few
  words; a table for numbers, never for one row.
- **Expand only when asked**, or when a real decision needs the context.

### Code comments - why-only

The default is **no comment**. Names, types and structure carry the *what*; a
comment exists only for a *why* the code cannot carry.

- **Test every comment by deleting it.** If the code still reads correctly and
  the next reader would make no wrong move, it stays deleted. It earns its line
  only by naming a non-obvious constraint - a trap, an invariant, an external
  quirk, a deliberate deviation - or as the why-comment an escape hatch requires.
- **Never:** restate the code or narrate a step; banner or divider comments; the
  task or its history (`added for #123`); what a function does when its name
  already says so; code left commented out. Doc comments go on exported API
  only, one or two lines, the contract not the implementation.
- **Config is code.** `mise.toml`, `compose.yaml`, CI workflows, Dockerfiles get
  one header line saying what the file is and where the rationale lives - never
  an inline essay. The scaffold ships this way; keep it so.
- **A dense file is not a licence.** Write new code to this rule even there, and
  trim adjacent noise only where the change already touches those lines. A
  write-time notice flags a file above a fifth comment lines - advice, not a
  gate. Only when every remaining comment earns its line, record that once with
  `steer:allow-comments <reason>`; a bare marker with no reason suppresses
  nothing.


## Who you are working with

Two audiences work in managed product repos. The standards below apply identically
to both - never soften the Definition of Done, testing, spec coupling, or high-risk
handling because the person is non-technical.

- **Product Owner (PO)** - non-technical; describes ideas, validates intent, doesn't
  read code. Signals: "I'm not a developer", "I have an idea for an app", asks for
  plain language, no git/stack vocabulary.
- **Developer (dev)** - productionizes, reviews, deploys. Uses technical terms.

**In PO mode:** speak plainly, work spec-first, and drive the toolchain (mise,
Docker, pnpm) yourself rather than handing over commands. Build is the **default
posture**: on the PO signals above - or an ambiguous-but-non-technical request, or
a `spec/BUILD-STATUS.md` whose Handoff gate still has an
unchecked box (an in-progress build; the SessionStart hook flags exactly that in
Claude Code, otherwise look - a handed-off build stays quiet) - auto-start `/steer:build` with a
one-line heads-up and resume from its current step. When the PO wants to think a feature through before any
code, that is `/steer:spec` - offer it plainly ("we can work out what this should
do first") and drive it for them. Guardrails: never deploy, touch `/infra`, or use
real secrets/credentials or real third-party accounts. A pre-production build may
implement high-risk features for real locally (High-risk pre-production
relaxation) - record every choice in the spec and the PR's productionization
brief. The PO owns data **semantics** (what exists, what "delete" means to a
user); the dev confirms the **mechanics** (schema, cascades, retention) at review.

**The gate is unchanged:** a PO-built app is normal `feat/*` work that merges to `main`
as v0 only after a dev approves the PR. That review *is* productionization. In
**solo trunk (pre-MVP)** there is no PR gate - the build commits straight to `main`
and productionization is the dev review at graduation (`/steer:protect`); see Commit
autonomy for the two modes.


## Stack (e22 org pack)

> **Applies only to a repo on the e22 org pack** - `policy/org.yml` with `pack: e22`, which is also what an absent file means. A repo that declares another pack skips this section and follows the vendor-neutral core rules, which name no product.

**The e22 org pack** - delivered where `policy/org.yml` says `pack: e22`, which
is also what an absent file means. Another pack drops this section and leaves
the core rules, which name no product.

**Default biases**, not mandates - when intent clearly warrants a different
stack, propose the better fit and record an ADR (`/steer:adr`). Rationale and
full setup detail: `/steer:reference conventions`. When you pick or change a
piece, verify the current stable version in-session via the bundled `context7`
MCP server - never from training-data memory.

These bullets are the **app / service** profile (the default). An **infra**
repo (Ansible / Terraform / OpenTofu / Pulumi) makes the Infra bullet its
*primary* stack - IaC toolchain at the root, no Node/web layer; a **library**
or **cli** follows its own package language and skips the app/web/compose
bullets; a **workspace** has no app stack. `/steer:init` records the profile; the universal core (mise pinning,
`/spec` spine, CI hygiene) is the same for all.

- **Frontend:** Next.js + TypeScript + Tailwind.
- **Backend:** Node + TypeScript + PostgreSQL + Drizzle, kept **inside** the
  Next.js app (Route Handlers, Server Actions, server components). A
  standalone `apps/api`, or Python + FastAPI + PostgreSQL, only when intent
  clearly warrants it - either split is an ADR.
- **Infra:** AWS via OpenTofu + Terragrunt (`/infra`). **CI:** GitHub Actions.
  **Deploy:** AWS (e.g. ECS) via Actions - confirm the target per app; each
  deployable `apps/<app>` carries a `Dockerfile` (built by CI when present).
  Promotion, environments, and the `prod`-branch gate: Deployment &
  environments.
- **Package managers:** pnpm (Node), uv (Python). Windows: WSL2 for CLI/IDE
  work; on the Claude Desktop Code tab, Git for Windows is enough.
- **Editor:** VS Code; committed `.vscode/` config ships in the scaffold.
- **Lint/format:** Biome (Node/TS), Ruff (Python) - each is the lint *and*
  format tool; no ESLint/Prettier or Flake8/Black/isort alongside without an
  ADR.
- **Testing:** Vitest (Node/TS), pytest (Python).
- **Auth:** Better Auth - high-risk; scope with the dev and write an ADR
  first. **Error tracking:** Sentry; DSNs/tokens in encrypted config at rest,
  never committed - see Secrets handling.
- **Secret store (deployed):** SSM Parameter Store `SecureString` - what Secrets
  handling means by "the declared store". Secrets Manager only for rotation,
  cross-account sharing, or large/binary values.
- **Local services:** Docker Compose via a committed `compose.yaml` - adapt the
  bundled scaffold one, don't author from scratch. **Same engine locally as
  deployed** (no SQLite stand-in for PostgreSQL); **every published host port
  overridable** - `"${POSTGRES_PORT:-5432}:5432"`, never a bare `5432:5432` -
  with the override var in `.env.example`. A plugin hook denies stale
  image-major pins (only an *ask* on the Copilot CLI), so keep pins current
  yourself (exceptions: ADR + `# steer:allow-pin`).
- **Task running:** mise is the single task entry point; environment tasks live
  in `mise.toml`, not `package.json`. Standard entry point `mise run dev:setup`
  (idempotent: services up -> migrate -> seed) - keep it green. Declare ordering
  with `depends` / `depends_post`, never `run = ["mise run ..."]` chains.
  App-level Node scripts (`dev` / `build` / `test` / `typecheck`) stay in
  `package.json` and a mise task may delegate to them - delegation is
  **one-way**. Compose a polyglot `dev` in `mise.toml` (`depends = ["dev:*"]`),
  never a root `concurrently` script; let `[deps.pnpm]` / `[deps.uv]`
  (`auto = true`) install on lockfile change.
- **Environment variables:** local config in a git-ignored `.env` /
  `.env.local`; names documented in `.env.example` - bootstrap and storage
  rules in Secrets handling.

**Patterns, instantiated here:** typed by default -> TS `strict` / Python hints
under a type checker; parameterized data access -> Drizzle Kit or SQLAlchemy +
Alembic; server-first -> Server Components, `NEXT_PUBLIC_*`; shared domain
modules -> `packages/`; nothing silenced -> unexpected errors to Sentry with
context; lockfiles -> `mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
`.terraform.lock.hcl` (mise writes `mise.lock` only if it exists already);
declared dependencies -> `package.json`, `pyproject.toml`.


## Useful commands (e22 org pack)

> **Applies only to a repo on the e22 org pack** - `policy/org.yml` with `pack: e22`, which is also what an absent file means. A repo that declares another pack skips this section and follows the vendor-neutral core rules, which name no product.

- **First-time setup:** `mise trust && mise install` (full mise setup in the
  product README), then `mise run dev:setup` - idempotent local env: services
  up -> migrate -> seed.
- **Develop:** `pnpm dev` (Node) / `uv run <cmd>` (Python) - with mise activated,
  bare `pnpm`/`uv` resolve to the **pinned** runtime. The scaffold's `[deps]`
  auto-install runs `pnpm install` / `uv sync` before any `mise run ...` on lockfile
  change, so you almost never install deps by hand; if you must, route it through
  mise - `mise exec -- pnpm install` - so it can't pick up a global/nvm copy.
- **Test:** `pnpm test` (Vitest) / `uv run pytest`.
- **Deploy:** promotion via merge (`main` -> non-prod, `prod` PR -> prod) - see
  Deployment & environments; there is no `pnpm deploy` task.

The `pnpm`/`uv` lines above are the **app / service** profile. An **infra** repo
uses its own `mise` tasks instead (`mise run infra:fmt` / `infra:validate` /
`infra:plan`, or `tofu`/`terragrunt`/`ansible-playbook` directly) - see Stack -
infrastructure. A **workspace** (polyrepo spine) repo holds no code, so it has no
`dev:setup` or linters at all: its tasks are `ws:`-prefixed (`ws:clone`,
`ws:docker:up`, `ws:dev`) and each member repo runs its own. The `mise trust &&
mise install` first step is universal; `mise tasks` lists what a repo really has.

Commands assume mise is activated and **wins PATH** over any other version
manager (nvm/asdf/volta/fnm) - otherwise bare `pnpm`/`node` silently run a
global version. "tool not found" -> mise not activated; *wrong/old* version ->
shadowed. Either way run `/steer:doctor`; activation-order rationale:
`/steer:reference conventions`.


## Parallel worktrees - isolate runtime, clean up after

You may be one of several agents working the same repo at once, each in its own
worktree; your local services must not collide with - or outlive - a sibling's.
(A repo with no `compose.yaml`/ports has nothing to isolate; the cleanup
discipline still applies to anything you start.) Task names below are the core
scaffold's; a **workspace** repo prefixes its own `ws:` - see Useful commands.

**Trust a worktree before you run `mise` in it.** `mise trust` is path-based, so a
new worktree is untrusted and every `mise run ...` there fails on *trust*, not on the
task. Run `mise trust` in the worktree first - it is idempotent, so it costs
nothing when a steer check already inherited the primary checkout's trust (Claude
Code only). That first decision is the user's, not yours: `mise trust && mise
install` if the repo was never trusted, `mise trust` if it has no `mise` config
at all - a first-time trust decision is not yours to make.

**Isolate runtime resources.** The scaffold handles this automatically: `mise`
sources `scripts/worktree-env.sh`, giving each worktree a unique
`COMPOSE_PROJECT_NAME` and a stable per-worktree host-port offset
(`POSTGRES_PORT`, `WEB_PORT`, `DATABASE_URL`; the primary checkout keeps the
defaults). So:

- Start services and the dev server through `mise run ...` (`docker:up`,
  `dev:setup`, the app's dev task) so the per-worktree env applies - never a
  bare `docker compose up` or a hardcoded port.
- Don't pin a fixed `container_name` or a literal host port in `compose.yaml`,
  and don't hardcode `localhost:5432`/`localhost:3000` in app config - read
  the env vars.
- If two worktrees still draw the same offset, set
  `STEER_WORKTREE_OFFSET=<n>` for one of them rather than editing shared
  files.

**Clean up before the worktree closes.** On Claude Code, steer's `WorktreeRemove`
hook runs `docker:clean` on this worktree's stack - containers, **volumes** and
orphans, scoped to its `COMPOSE_PROJECT_NAME`, so its data goes with it. The
`SessionEnd` hook does the lesser `docker:down`: containers stopped, **volumes
kept**, and often cut short, so never count on it. Yours regardless: stop the dev servers and watchers
you launched, freeing their ports - and run `mise run docker:clean` yourself when
removing a worktree by hand or on any other surface, where no hook fires.


## Spec workflow

Create the artifact when the trigger fires - don't defer it:

- **Starting a user-facing feature** -> `/spec/features/[id]/intent.md` +
  `contract.md`, before or alongside the code - author via **`/steer:spec`**
  (or **`/steer:build`** for a PO). `[id]` is a kebab-case slug (`user-login`).
- **Hard-to-reverse or cross-cutting choice** (stack, database, auth,
  deployment) -> ADR at `/spec/decisions/000N-[slug].md` (run
  **`/steer:adr <slug>`**); the initial stack choice is usually the first.
  **The bar is reversal cost, not novelty** - a pattern used in one place is a
  `contract.md` line until a third use makes it the house style.
- **Behavior changes** -> update the owning `contract.md` in the same PR - plus
  the app guide (`/spec/app/`) if it describes the old behavior; see Living
  documentation.
- **Open questions** -> the feature's `intent.md` -> `## Open questions`
  (product-level ones in `vision.md`); sweep and answer them with
  **`/steer:questions`** before they rot.
- **A feature that began as a tracker issue** -> **`/steer:issues brainstorm`**
  shapes it in the issue, **`materialize`** writes the approved intent to
  `intent.md` as `Status: draft`; an explicit `/steer:spec approve` flips it
  to `approved`. The issue is the work record; the spec stays product truth.

**Polyrepo member** (`spec/PRODUCT.md` present): `spec/features/**` and the
product-level files above are the **workspace's** - resolve the spine there,
never create a local copy; ADRs and `ARCHITECTURE.md` stay per member
(`/steer:reference polyrepo`).

The spec <-> code coupling rules (drift resolution, what counts as behavior, PO
acceptance) are canonical in the spec-framework reference `/steer:spec` draws
on. Unsure whether something needs a feature spec or an ADR? Ask the dev
rather than skipping it.

**Greenfield** (new product - an idea, brief, screenshots, or a design export):
**bootstrap first** (`/steer:init`, or `/steer:build` for a PO) - the bundled
scaffold **and** the `/spec` spine before feature code; never hand-write
`package.json` / build config / CI from scratch. Then interview to fill
`vision.md`, `users.md`, `glossary.md` (ask, don't invent; product-level
ambiguity -> `vision.md` -> `## Open questions`), draft feature intents, and get PO
approval before broad implementation.

**UI work, with or without a design export.** A committed export (Claude Design
ZIP, Figma, screenshots) is a spec to realize in the standard stack, not code to
ship - read the **local export**, never the URL (it 403s). No export is the
normal case: build the UI deliberately rather than defaulting to generic AI
aesthetics, and capture the reusable decisions in `DESIGN.md` as you go. Full
walkthrough: `/steer:reference design-sources`.

**A prototype is greenfield too** - "quick" / "just a prototype" / "throwaway"
relaxes the *ceremony* (lighter interview; branch/PR only via solo-trunk mode
below; a GitHub-adopted repo still keeps the issue where Issue-first requires one,
closed from the commit - see Issue-first), **not** the scaffold or the spine. Even a throwaway gets the
bundled scaffold and a minimal `/spec` (vision + the feature intents being
built). `/steer:adopt` is for *un-bootstrapped* pre-existing code, not an excuse
to skip bootstrap now.

**Solo greenfield can run on trunk** - when one person is both PO and dev
pre-MVP, `/steer:init` offers **solo trunk mode**: only the branch/PR ceremony
relaxes; scaffold, spine, tests, and Definition of Done all hold. Mechanics
and graduation are canonical in Commit autonomy.

**Brownfield** (change to an existing product): triage -> classify it (Change
classification) -> Behavioral and High-risk work writes/updates the spec or ADR
first -> implement -> update the owning `contract.md` if behavior changed.

**Adopting a whole repo** that never went through bootstrap (a "vibe-coded"
app with no `/spec`): run **`/steer:adopt`** once - reverse-engineer the spec
from the code, triage productionization (Keep/Refactor/Rewrite/Reject in
`PRODUCTIONIZATION.md`), sync in the bundled scaffolding - distinct from a
per-feature Brownfield change.


## Durable decisions land in the spine, not in side-channels

A durable design decision - stack, auth model, data model, architecture, a
locked scope or MVP cut - belongs in `/spec`: a feature's `intent.md`, a
`contract.md`, or an ADR (`/steer:adr`). That is the single source of truth a
teammate inherits from the repo. Scoping conversation, chat summaries, and
**assistant memory** are working notes, not the record - never let a decision
survive only there, where the repo carries no trace of it.

**No `/spec` spine yet? Bootstrap before you commit the decision, not after.**
On a repo with no spine, do not persist architectural choices or a locked scope
to memory or prose as a stand-in for the missing spine - that is the
single-source-of-truth break this rule exists to prevent. Run `/steer:init`
(greenfield) or `/steer:adopt` (existing code) first so the decision lands where
it is traceable and reviewable in the bootstrap PR. The scoping dialogue itself
is fine and expected - `init`'s own interview is where it belongs; what waits
for the spine is the **durable capture** of what was decided. See bootstrap
precedence in the router and Living documentation (`32-living-docs`). Record
each decision with its ratifier and date - see Answering a human gate.


## Living documentation - document in parallel, not after

The PO/dev speaks plainly; **you** translate it into durable artifacts *as the
work happens*, never in a wrap-up pass. When conversation or implementation
reveals a requirement, constraint, assumption, risk, trade-off, or decision,
update (or propose) the owning artifact **in the same change as the code**:

- Intent, goals, acceptance criteria -> the feature's `intent.md` (scope
  changes need PO approval); behavior/data/API decisions -> `contract.md`;
  hard-to-reverse choices -> ADR.
- Ambiguity -> `## Open questions` - **never guess an answer into the spec**.
- Usage, workflows, roles, configuration, limitations, troubleshooting,
  release notes -> the app guide (`/spec/app/`).
- Tech stack, the apps/packages map, cross-component data flow -> root
  `ARCHITECTURE.md` - updated, with the linked diagram
  (`/spec/design/architecture-diagram.md`), in the same PR that changes them.
- Visual identity, reusable design tokens -> root `DESIGN.md`, seeded when the
  first UI lands and grown on the 3+ rule (Design sources). The PR that
  establishes the stack or first app also retires the scaffold's now-false
  placeholder prose - a stub left after the thing it describes exists is
  drift.
- A **notable event** - ratified decision, scope change, repo-level event,
  absorbed PO document, incident -> a **new file** under `/spec/history/`
  (`YYYY-MM-DD-HHMM-<slug>.md`), immutable once merged. **An ordinary merged
  change writes none** - the commit and the PR are its record.

**Polyrepo member** (`spec/PRODUCT.md` present): `spec/features/**`, `/spec/app/`
and `/spec/history/` are the **workspace's** - write them there via
`workspace.path`; if it does not resolve, record the event in the PR description
**and say the workspace ledger still needs the entry**. Never a local copy.
`ARCHITECTURE.md`, `DESIGN.md` and ADRs stay per member (`/steer:reference polyrepo`).

PO-facing artifacts (intent, vision, app guide) stay plain-language;
dev-facing ones (contract, ADR) stay precise enough to implement and review
against. A declined proposal becomes an open question, not silence. Full
conventions: **`/steer:reference traceability`**.

**Applying a decision already made is not a new decision.** Propagating a
settled choice into the artifacts that should reflect it is living-docs
upkeep: make the edit in the same change and let the **PR be the gate** (rule
`95-not-the-gate`). Pause for a yes only when the *decision itself* is unmade -
a genuine product / policy / architecture call, anything under High-risk
areas - or when an edit would clobber filled-in content.


## Spec workflow - OpenSpec backend

> **Applies only to a repo whose spec spine is OpenSpec** - it has `openspec/project.md`, `openspec/specs/` or `openspec/changes/`. If this repo has none of those, skip this section entirely: the unqualified Spec workflow above governs, and `spec/features/**` is where specs belong.

This repo carries an `openspec/` spine, so **OpenSpec owns the spec artifacts**.
This rule overrides the *paths and commands* in Spec workflow. Every other rule -
stack, testing, coverage, Definition of Done, issue-first, drift gates,
secrets, compliance, change size - applies unchanged.

**`openspec/` IS this repo's spine**, so the router's bootstrap precedence and
Durable decisions' "no `/spec` spine yet?" check are already satisfied: do not
announce `/steer:setup`, `/steer:init` or `/steer:adopt` as the first move here,
and do not read the absent `spec/features/**` as an unbootstrapped repo. Those
bootstrap routes would lay a second, competing spine.

- **New or changed behavior** -> an OpenSpec change, not `spec/features/<id>/`:
  **`/opsx:propose`** writes `openspec/changes/<id>/` with `proposal.md`,
  `specs/`, `design.md`, `tasks.md`. Shape it with **`/opsx:explore`** first
  when the approach is still open.
- **Intent** is `proposal.md`; the **behavior contract** is that change's
  `specs/` (requirement + scenario), promoted into `openspec/specs/` on archive.
  Never create `spec/features/<id>/intent.md` here - prefer the `/opsx:*`
  commands over `/steer:spec` for authoring on this repo.
- **Implement** from `tasks.md` (**`/opsx:apply`**), then **`/opsx:archive`** at
  merge - that archive is this repo's action history.
- **Behavior changed** -> update the owning requirement in the same PR, exactly
  as the contract rule demands. Where the expanded profile is enabled,
  **`/opsx:verify`** (implementation vs. the change's artifacts) is a pre-merge
  check here, alongside the drift gates.
- **Open questions** go in the change's `proposal.md`, not a side channel.

**Three artifacts are steer's, because OpenSpec has no equivalent - and on this
repo they live under `openspec/steer/`, NOT in `spec/`:**

- **ADRs** -> `openspec/steer/decisions/000N-<slug>.md` (**`/steer:adr`**). A
  change's `design.md` is per-change and is archived with it; a hard-to-reverse
  choice has to outlive the change that made it.
- **Tracker declaration** -> `openspec/steer/tracker.md`. It declares the issue
  tracker and is what issue-first enforcement reads. OpenSpec models no tracker.
- **App guide** -> `openspec/steer/app/`. Living documentation (how to use and
  operate the product), not a spec artifact - Living docs applies unchanged,
  only the path moves.

**This overrides every skill and rule that names a `spec/` path for these
three.** A skill body still says `spec/decisions/`, `spec/tracker.md` or
`spec/app/` - read it as `openspec/steer/...` here. The `steer/` segment keeps steer's durable artifacts
out of the namespace the `openspec` CLI regenerates. If you find them at the old
`spec/` paths, the repo predates the move: run **`/steer:sync`**.

Toolchain and CI scaffolding are still steer's - the bundled scaffold (mise,
compose, CI, PR template) applies here unchanged. Reach it via **`/steer:setup`**
*only when that scaffold is missing*, and do not let it route into
`/steer:init` / `/steer:adopt`: those write a `spec/` spine from the templates
and stamp `spec/.version`, which is the competing spine this rule exists to
prevent. Missing `openspec/steer/tracker.md`? Instantiate
`templates/spec/tracker.md` there directly - it is one file, not a bootstrap.


## Issue tracker integration (client-agnostic)

Products use whatever tracker the client has (Jira, GitHub Issues, Linear,
Azure DevOps, ...). **`/spec/tracker.md`** declares the system + ref format -
read it before referencing work items; if missing, ask and create it from the
bundled template - **except in a polyrepo member** (`spec/PRODUCT.md` present),
where the tracker is the workspace's: resolve it there and never create a local
copy. Refs live in `intent.md`'s `> Tracker:` line, the PR
description (tracker's own linking syntax), and the `/spec/history/` entry's `Refs:`. Copy a
tracker item's acceptance criteria into the intent - the spec is the in-repo
source of truth; the ref points back. **Keep a question in the spec's
`## Open questions`** (structured `Q-NNN`) when it's local to one feature and
answerable while specifying it; **promote it to an issue** when it needs a named
owner, blocks multiple features, needs stakeholder/research input, or could
outlive the session - then put the ref in the question's `tracker:` field. The
issue is the decision *workflow*; the spec (or an ADR) is the durable *record*.

When the tracker is **GitHub Issues**, **`/steer:issues`** is the high-level
lifecycle workflow (capture -> triage -> brainstorm -> materialize -> decompose ->
status -> reconcile), and **`/steer:tracker-sync`** is the low-level gateway it
routes all reads/writes through (MCP-first -> `gh` -> manual floor). Agent-authored
issues follow the machine-readable contract (stable headings + hidden markers);
`/spec` stays product truth, the issue is the work/decision layer. Other trackers
use the manual export.


## Issue-first (GitHub-adopted repos)

> **Applies only where the tracker declaration says `system: github`** - `spec/tracker.md`, or `openspec/steer/tracker.md` on an OpenSpec repo (in a polyrepo member, the workspace's). On any other tracker, or with none declared, skip this section.

When `/spec/tracker.md` declares `system: github` - in a polyrepo member
(`spec/PRODUCT.md` present) that file is the **workspace's**, never a local
copy - an issue exists **before the first repository mutation** in exactly two
cases:

- **High-risk work** (Change classification), and
- **any of the six value cases**: a planned feature, a tracked bug, work
  spanning more than one session, work coordinated between people, a product
  decision or acceptance to record, or a follow-up discovered along the way.

Everything else - a Trivial change, an ordinary Behavioral fix nobody is
tracking, `/spec` edits, documentation, generated output, lockfiles, a
plugin-maintenance `/steer:sync` on its own `feat/sync` branch - needs no
issue: **the PR is the work record**. Reuse the issue the user names;
otherwise find-or-create one through `/steer:tracker-sync` - an explicit
"fix / implement / add / create" request does **not** need confirmation to
create the issue.

- **Capture-only and ambiguous language do not auto-create.** "Note this" /
  "we should eventually..." is captured deliberately, never inferred into a
  batch of issues. A large inferred batch takes one confirmation;
  security-sensitive public disclosure takes human review.
- **Implementation runs through `/steer:work`** - claim, branch, implement,
  test, open the PR, transition the issue. Commit, push, and the PR are
  autonomous under Commit autonomy; **merge and deploy are never implied**.
- **Solo trunk keeps the issue, drops the branch/PR** (Commit autonomy) -
  close it **from the trunk commit** (`Closes #N`). The issue stays the
  audit-evidence anchor (Audit-aligned delivery).
- **Discovered out-of-scope work** gets its own linked issue
  (related/blocking), not silent scope creep in the current one.
- **The issue's `steer:state` reflects reality** - work in progress is
  `validate`, never `done` - and the PR references it with the correct
  closing/non-closing relation.
- The scaffold pre-authorizes the tracker write verbs, but your host may block
  one anyway. A create that is blocked is a **host-permission gate, not a
  missing issue** - don't loop retrying; confirm with the user, or have them run
  `!gh issue create ...` under their own identity, then continue. (Full tiering
  and rationale: ISSUE-WORKFLOW.md, "Host gating" in Operating model.)

Non-GitHub trackers and repos without a `/spec` spine keep today's flow.
**Calling work a "prototype" does not waive it** - the only durable opt-out
from the per-feature branch/PR is solo-trunk delivery mode.


## Testing rules

- Every feature change **includes or updates automated tests** in the same PR - never "later."
- Every bug fix **MUST add a regression test** that fails before the fix and passes after. This is a hard rule.
- Do **not** delete or skip failing tests to make CI pass. Fix the cause, or explicitly remove the behavior and say so in the PR.


## Coverage rules

- Coverage is a **signal to find untested behavior, not a target to hit** - never
  write shallow tests, or relax assertions, to move a number.
- **Cover what you touch:** new and changed code paths ship exercised. Prioritize
  **critical paths, branches, and error handling** over blanket line %.
- Coverage is **measured and visible every run** (per-stack tooling in `CONVENTIONS`).
  A coverage drop on changed code is **drift** - surface it for human review, never
  silently (see Drift gates).
- No global "fail under N%" vanity gate; CI gates only **changed-line** coverage. The
  reviewer judges adequacy (see You are not the gate).


## Commit autonomy

Commits are cheap and local - the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Never pause work to ask
"should I commit / push / open the PR?".

Delivery runs in exactly **two modes**, keyed to what the repo **declares**. The
product `CLAUDE.md` `## Delivery mode` marker is the declaration
(`<!-- steer:delivery-mode=solo-trunk -->` -> solo trunk; anything else, absent
included -> pr-flow); branch protection *enforces* pr-flow rather than defining
it. `/steer:protect` moves a repo between them, and there is no third mode.

- **PR flow (the default - protection is the wall that enforces it).** Work on a branch off `main` -
  never commit or push to `main` directly. Use the repo's branch convention,
  else `feat/*` / `fix/*` (`/steer:work` defaults to `issue/<number>-<slug>`).
  On `main` with changes? Create the branch first, then commit. When the work
  is **complete** (Definition of Done holds, end-of-session checklist clean),
  **push the branch and open the PR without asking** - announce it, don't
  request permission. First push of a fresh branch:
  `git push -u origin <branch>`. **Merging the PR is the one step that waits
  for the dev; everything before it (branch, commit, push, open PR) does not.**
- **Solo trunk mode (declared, pre-MVP greenfield).** If the product
  `CLAUDE.md` declares solo-trunk, commit **directly to `main` and push without
  asking** - no `feat/*` branch, no per-feature PR. CI still runs on every
  push; the spine, tests, and Definition of Done are **unchanged** - only the
  branch/PR ceremony relaxes. On a GitHub-adopted repo the issue is still
  required and closed from the trunk commit (`Closes #N`), not via a PR (see
  Issue-first). **Graduate** - run **`/steer:protect`** - the moment the MVP
  works, you first deploy, or a second contributor joins, whichever comes first.
  Until then a standing **local** graduation signal (a deploy target or a `prod`
  branch) stops trunk pushes being silent: the session's **first** one waits for
  a human yes (`/steer:reference gates`) - unless the dev has recorded a
  **graduation waiver** (`/steer:protect waive`: a single-dev repo staying on
  trunk deliberately, `<!-- steer:graduation=waived -->`), which silences that
  gate and the session nudge; a second contributor voids it.
- **Declared-but-unprotected PR flow is a gap, not a mode.** The flow above
  applies unchanged - you still never merge - but say the wall is missing and
  recommend `/steer:protect`; where protection is genuinely unavailable, record
  the exception in an ADR.
- In a GitHub-adopted repo, the **first mutation** presupposes an active
  GitHub issue **where Issue-first requires one** - otherwise the PR is the
  work record. Autonomy is unchanged either way.
- **Commit without asking** whenever a coherent unit of work is done - tests
  pass, lint clean, builds. Keep commits small, with a
  **[Conventional Commits](https://www.conventionalcommits.org/)** subject:
  `type(scope): summary`, imperative mood; mark breaking changes with `!` or a
  `BREAKING CHANGE:` footer. Commit messages are **not** the release
  changelog: a shipping change also adds a **changelog fragment** -
  `mise run changelog:new`, one file under `.changes/unreleased/`.
  `CHANGELOG.md` is generated from those; never edit it by hand. Full detail:
  `/steer:reference conventions`.
- **After pushing, watch CI to conclusion and fix a red build before treating
  the work as complete** - don't hand the dev a running or red PR and stop.
  (**Merge and deploy stay human-gated in every mode** - never `gh pr merge`,
  never deploy, never push to a protected `prod` branch.)


## Definition of Done

A change is done when **all five** of these hold:

- [ ] **Intent understood** - you can state what the change is for, and it is the change that was asked for.
- [ ] **Appropriately tested** - Testing rules; a bug fix carries a regression test that fails before and passes after.
- [ ] **CI green** - watched to conclusion after push, not assumed.
- [ ] **The contracts and docs this change actually affected are updated** - the ones this diff made wrong, not a survey of every artifact.
- [ ] **Merge and deploy went through the required human gates.**

That is the whole list. Everything else you owe a change is canonical in its own
rule and named, not restated here: comments, coverage, the changelog fragment,
the tracker ref and issue state, ADRs, high-risk scoping. Ceremony scales with
the change (Change classification). CI enforces only a thin floor - in
**solo-trunk** that floor (changed-line coverage, the changelog-fragment gate,
the advisory spec-drift warning) is the *only* automated backstop. Under a
declared production hotfix these are **deferred** to the mandatory follow-up,
never waived.

### Verify loop - iterate against the harness, don't flail

Before writing code, name the check that will prove the task done - a failing
test, a passing build, a command whose output you can read. A goal you can't
check is a goal you can't finish.

- **State the assumption, don't bury it.** Two readings of a request -> surface
  the one you're taking, or ask, **before** writing 200 lines against it.
- **Loop until green, then stop**, and **cap the loop**: run the harness, fix
  what it reports, re-run; if attempts stop converging, **report what blocked
  you** with the failing output. Never thrash, never paper over the check.
- **Never loop on uncheckable work** - judgment calls, design decisions and
  long-compute runs have no fast pass/fail.

### Drift gates - surface before merge

Drift - any mismatch along intent <-> spec <-> contract <-> tracker <-> app docs
<-> tests <-> delivered behavior - is resolved by **explicit human review, never
silently**: you surface it before merge, the reviewer resolves it. Flag these
classes in the PR description the moment you notice one (the scaffold's PR
template carries the checklist): **intent drift · contract drift · undocumented
behavior change · security-sensitive · compliance-impacting · operational
(deploy/CI/infra) · local setup or deployment changed · app docs invalidated ·
architecture/stack drift (`ARCHITECTURE.md`)**. A flagged class blocks merge
until the reviewer resolves it - you may not waive your own flag. The scaffold's
advisory `spec-drift` CI job warns when behavior changes without its
`contract.md`; a warning is a prompt, not a substitute for the flag. Sweeps:
`/steer:audit`. Mechanics: `/steer:reference traceability`.

### Audit-aligned delivery

The workflow is **aligned with** SOC 2 / ISO 27001 delivery expectations - say
"aligned", never "compliant": certification scope and production-readiness
approval stay with humans. The artifacts are the evidence, so keep the chain
intact - traceability, review evidence, change history, secure defaults.

### End-of-session checklist

Before wrapping up, run this and report **only the open items**, one line each -
a clean checklist is one sentence, never the list echoed back with ticks. Track
them with your todo tooling; if an item can't be satisfied, say so rather than
implying the work is complete.

- [ ] The five Definition of Done items hold for every change this session?
- [ ] Unfinished work and known gaps surfaced explicitly?
- [ ] Dev servers and watchers you started stopped? (Closing a worktree: `mise run docker:clean` - the hooks are best-effort.)
- [ ] GitHub-adopted repo: the active issue reflects progress, branch, blockers and validation; unrelated findings captured as linked issues; the PR references the issue with the right closing relation?
- [ ] Scaffold placeholders flagged or resolved? (Unbootstrapped repo: `/steer:init`.)
- [ ] Everything finished committed, and a complete change pushed with its PR open - or the trunk commit pushed in solo-trunk - with CI watched to green?
- [ ] Solo trunk, no graduation waiver, and the MVP works, you deployed, or a second contributor joined -> `/steer:protect`?


## Deployment & environments

How code reaches users is **declared by the repo, not imposed here**:
`policy/delivery.yml` names its environments, what merging deploys, how
production is approved (`production_gate`), whether review apps exist, and what
it reports to a human. Read it before saying anything about this repo's
delivery; if it is missing, ask and seed it from the bundled template. Deploy
and release logic is a high-risk area (see High-risk areas) - scope pipeline
changes with the dev, and validate in non-prod where the declared model has one.

- **Follow the declared model**, and never push directly to a protected branch
  whatever the gate. `/steer:protect` applies the GitHub side of it.
- **Merge and deploy stay human, in every model.** A gate declares *which*
  human step applies, never that there is none (Commit autonomy).
- **Observable by default** - logs, metrics with alarms, error tracking, health
  checks, alerting a human sees, wiring recorded in `ARCHITECTURE.md`. An empty
  `observability` list is allowed: unobservable is a **flag to raise**, not a
  rule to break.
- **Rollback** - every production deploy has a known one (revert the promotion,
  redeploy the prior SHA); migrations are expand/contract so the previous
  version survives the deploy (see High-risk areas).
- **Secrets at rest** - injected at deploy/runtime, never baked into images or
  CI logs (see Secrets handling).

The org's default shape, and why it gates prod on a branch, is the seeded
`policy/delivery.yml` plus `/steer:reference conventions`. A repo that delivers
differently edits that file; only a *weaker* gate needs an ADR.


## Autonomous loops - automate the navigation, never the authority

> **Applies only to a repo that has declared the automation opt-in** - `policy/automation.yml` with `loops: true`. A repo without that file runs no steer-scaffolded loop, so skip this section entirely.

An **autonomous loop** is a scheduled automation (a cron workflow, a Routine)
that wakes on its own, discovers work - CI failures, open issues, drift - and
drives it through steer's skills unattended. It removes the prompting, **not**
the responsibility: still ship code you *confirmed* works (Definition of done).

- **A loop closes only up to a human gate - never through one.** It may
  discover, triage, draft in an isolated worktree, verify, push its **own work
  branch**, and open a PR - the merge review is the human gate (Commit
  autonomy). It **stops** at every authority gate: issue creation beyond an
  explicit ask (Issue-first), ADR ratification (High-risk), and merge / deploy
  / push to `main` or any protected branch / real secrets. Loop-opened PRs are
  **drafts by convention** - the deliberate signal that nobody attended the
  run; a reviewer flips one to ready.
- **A loop presupposes PR flow.** Protect `main` first (`/steer:protect`);
  never point a loop at a solo-trunk repo - unattended direct-to-`main`
  delivery has no gate at all.
- **Split ideation from verification.** The drafting agent never clears its own
  change - route the check through an independent reviewer (`steer-reviewer`,
  `/steer:audit`, the test harness).
- **Keep durable state outside the model.** A loop's memory is the tracker +
  `/spec/**` (issues, `/spec/history/`), not chat context - record what it did and
  what's left so the next run resumes instead of repeating.
- **Only loop on checkable work.** Judgment calls, design decisions, and
  long-compute runs have no fast pass/fail - the loop surfaces them for a
  human, it never decides them.
- **Scaffold loops with `/steer:loop`** - never hand-roll an automation that
  can cross a gate.


## High-risk areas

These require **explicit dev scoping before broad changes** - do not propose
architectural changes here speculatively:

- **Auth & sessions** - sign-in/up, password reset, token issuance, session invalidation
- **Authorization & permissions** - role checks, access control, multi-tenancy boundaries
- **Database migrations** - schema changes, backfills, migration scripts
- **Infrastructure** - anything in `/infra`, especially networking, IAM, secret stores
- **Secrets handling** - anything reading, writing, or transmitting credentials/keys/tokens
- **Deletion logic** - hard deletes, cascading deletes, retention/cleanup jobs
- **Billing & payments** - pricing, charging, refunds, subscription state
- **Deployment & release logic** - CI/CD workflows, release scripts, feature-flag rollouts

Handling: scope with the dev **before** any code; contract or ADR first;
smaller PRs; line-by-line review; validate in non-prod before prod. `@claude
implement this` is not appropriate here without explicit in/out scope.

**Pre-production relaxation:** while a product is **pre-production** (nothing
deployed, no real users or data), these areas may be built for real locally
without prior dev scoping - document the choices as you go (`contract.md`, an
ADR for a hard-to-reverse pick, `## Open questions` for the rest) and list them
in the PR so dev review hardens them at productionization. "Pre-production" is a
property of the **product, not the laptop**: working locally in a deployed
product still produces migrations and deletions that reach real data on merge.
**Never relaxed**, even pre-production: real secrets or credentials, `/infra`,
deploys, real third-party calls.

### Secrets handling

- **Never commit a secret** - not in code, configs, `mise.toml`, specs, or
  commit messages. A committed one is compromised: stop, tell the dev, and
  rotate it; don't just delete the line.
- **Local development:** config lives in a git-ignored `.env` / `.env.local`.
  Make sure it exists with the variables the app needs to boot - local Compose
  service URLs and freshly generated local-only values, never anything copied
  from a deployed environment. Document the *names* in `.env.example`. A
  worktree starts from git refs only, so the repo-root `.worktreeinclude`
  carries `.env` into each new one.
- **Deployed environments:** secrets live in **the declared store** - the org
  pack's, or an ADR's if this repo chose another - injected at deploy/runtime,
  never baked into images or CI logs. No declared store yet is a question for
  the dev, not a default you pick. Non-secret config may live in `mise.toml`'s
  `[env]`; secrets may not.


## Answering a human gate in-session

A gate needs the deciding **human's** answer - not a particular channel. When that
human is in the session, don't send them out-of-band to edit a status field:
**ask, then act in the same pass.** Never ratify on your own initiative.

| Gate | Decides | On Approve |
|---|---|---|
| ADR `Proposed -> Accepted` | its `Deciders` | `/steer:adr accept <n>` |
| Intent `draft -> approved` | the PO | `/steer:spec approve <id>` |
| `--reviewed` plan sign-off | who asked | implement |

Ask once, three options - **Approve · Reject · Decide later**:

- **Show the tradeoff** - rejected alternatives, negative consequences, locked
  scope - never just a title; a human cannot decide what they cannot see.
- **Never pre-select, never infer.** An unambiguous answer *to the decision
  presented* ratifies it; ambient agreement ("ok", "thanks", silence, or sign-off
  on an earlier plan) does not. Never bundle two decisions into one prompt.
- **`Decide later` is always offered** and leaves every field untouched.
- **Record who decided, when, and that it was in-session**, plus the
  `/spec/history/` entry. Self-ratification is legitimate; the *unrecorded*
  kind is the audit hole this rule prevents.
- **Preconditions fire first** - never show a gate the human cannot legitimately
  pass (an unresolved blocking question -> `/steer:questions`).
- **Wrong decider?** Surface the mismatch and leave the state alone.
- **Never promptable, in any mode:** merge, deploy, real secrets, `/infra`,
  protected-branch pushes. These need a human acting in the real system - asking
  does not authorize them, and this rule never relaxes them.

Full protocol: `/steer:reference gates`.

### Hotfix / incident fast-path

A production incident is high-risk and time-critical at once - the only case
where ceremony and speed genuinely conflict, and the only sanctioned speed
lever. Run it via **`/steer:work --hotfix`**, which carries the procedure.

The lane opens on an objective condition, never a self-assessment: an
already-**deployed production** system with real users or data, **and** an
active incident, outage or regression. Urgent feature work, a looming demo and
a pre-MVP repo are not hotfixes.

It relaxes **ceremony and ordering, never authority**: the issue is backfilled
instead of filed first (work on `hotfix/<n>-slug`), one reviewer suffices
instead of high-risk scoping, and deploying the fix is policy-permitted. Merge
and deploy stay human-gated, as everywhere. Once the fire is out the follow-up
is **mandatory**: backfill the issue, write the spec or ADR if a durable
decision was made, and write the `/spec/history/` entry. Definition of Done is
deferred under this lane, never waived.


## Change classification

Three classes set per-change ceremony, and **Issue-first takes its threshold
from here**. The Definition of Done holds in full for every class - what the
class scales is the ceremony around the change, not what "done" means. Classify
by **what the change does**, never by how many lines it touches; when two
readings are arguable, take the heavier one.

- **Trivial** - no observable behavior change: copy, formatting, comments,
  a behavior-preserving refactor, generated output, lockfiles. Open a PR and
  stop - no issue, no spec, no ADR, no plan; **the PR is the work record**.
- **Behavioral** - observable behavior changes, for a user, a caller, or an
  operator. Carries tests in the same PR and updates the owning `contract.md`;
  a planned feature writes its `intent.md` first and gets PO approval (Spec
  workflow). Start in plan mode, or post the plan, whenever the approach is
  worth reviewing before it is written.
- **High-risk** - anything in the High-risk areas list, at any size. Scope with
  the dev before any code, contract or ADR first, smaller PRs, line-by-line
  review. Never Trivial, and never treated as merely Behavioral.

A choice that is **costly to reverse** - stack, data model, tenancy, deployment -
takes an ADR before the code (Spec workflow), whatever its class.


## Patterns we follow (baseline)

Org baseline stated as **principles**, so they hold on any stack; where an org
pack is delivered it names the concrete instance of each. A product's own
`CLAUDE.md` adds team-learned patterns on top. Full patterns + anti-patterns
prose: `/steer:reference conventions`.

- **Follow the patterns already in the touched app/package** - the local idiom
  wins over a better one introduced in passing; change the house style
  deliberately, in its own change.
- **Typed by default** - static typing on wherever the language supports it;
  model the type rather than reaching for an untyped escape hatch.
- **All data access goes through a parameterized query layer - never raw or
  string-interpolated SQL.** Schema is defined in code and changed via
  committed, reviewed migrations; no ad-hoc schema edits.
- **Validate every external input through a defined schema at the boundary
  before use** - request inputs, external API responses, config and data
  files, env vars - and derive types from that schema rather than hand-writing
  them. One validated config module, not scattered raw env reads.
- **Server-first** - secrets and DB access stay server-side; client code is
  explicit and lean; only genuinely public values reach the client.
- **Domain logic lives in shared, testable modules**, not in UI components or
  route handlers - keep handlers thin.
- **Slice work vertically** - thin end-to-end slices (schema to UI), not
  layer by layer; each merge leaves the product working.
- **Nothing silenced** - no empty `catch` / swallowed errors; an unexpected
  error reaches the error tracker with context. No escape hatch without a
  why-comment (`any` casts, `@ts-ignore`/`@ts-expect-error`, wholesale
  lint-rule disabling).
- **Lockfiles are maintained, not optional** - committed and updated in the
  same change that touches their config/deps; never deleted or ignored to
  dodge an error.
- **Every import resolves to a declared dependency** - added to the manifest
  (and lockfile) in the same change; a plausible-looking undeclared package
  name is a hallucinated dependency that breaks in a clean environment.
- **ASCII everywhere** - em/en dashes, curly quotes, ellipsis, arrows, bullets
  and non-breaking spaces never appear in anything you produce: not in code,
  config, identifiers or strings bound for an external API, and not in
  comments, specs, docs, commit messages, PR text or chat either. Write `-`,
  `'`, `"`, `...`, `*`, `->`; strict validators reject the rest. This is about
  those characters only - accented letters, guillemets and other non-English
  text are unaffected, and the apostrophe is `'` in every language, French
  included.


## Internal ids stay out of end-user surfaces

ADR ids, tracker refs, `Q-NNN` ids, feature slugs and `spec/**` paths are
internal traceability. Keep them out of **app UI copy** (titles, labels, badges,
tooltips, empty/error states, emails) and **`/spec/app/` guide copy and release
notes** - state what changed for the user, not the record behind it; use the
product's own domain language (`spec/glossary.md`, linked not copied). Refs
belong in intent, contracts, ADRs, history, runbook, PRs, commits.


## You are not the gate - the DEV is

You have no path-based permission boundary in managed product repos - propose
changes anywhere (`/apps`, `/packages`, `/configs`, `/spec`, `/infra`). The dev
reviewing the PR is the hard gate and catches out-of-scope or risky edits. When
unsure about scope, ask in a PR comment before making sweeping changes.


## When steer itself misbehaves, report it upstream

steer is maintained centrally in `element22llc/e22-plugins`. When the plugin's
**own machinery** misbehaves, treat it as a plugin defect to report - not a
thing to silently work around:

- A SessionStart **self-fault notice** flags recorded hook faults (Claude Code only).
- A skill or rule gives **contradictory or impossible** instructions.
- A referenced **template, script, or helper is missing, malformed, or crashes**.

This is about steer's defects only - ordinary product-code errors, failing
tests, or your own mistakes are not plugin faults and do not belong here.

On any of the above: surface it plainly, then file it upstream with
`/steer:report`. It **auto-files** after scrubbing and deduping - no confirmation
step - and the scrub **redacts or omits** anything it can't safely classify
(secrets, absolute paths, product code) rather than asking, so nothing sensitive
reaches the shared repo. If you only worked around the defect to keep going,
still report it so it gets fixed for everyone.
