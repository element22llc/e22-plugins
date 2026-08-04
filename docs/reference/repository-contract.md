# Repository contract

When `steer` manages a repo, it expects a known shape. `/steer:init` and
`/steer:adopt` install it; `/steer:sync` keeps it current. The scaffold is bundled
in `plugins/steer/templates/scaffold/` and mapped to install paths by its
`MANIFEST.md`.

## What a managed repo carries

```mermaid
flowchart TD
    ROOT[Repo root] --> SPEC["/spec spine<br/>intent · contract · vision · glossary · history/ · tracker · ADRs · design · sources · .version"]
    ROOT --> MISE[mise.toml<br/>toolchain + tasks]
    ROOT --> CI[.github/ workflows + PR template]
    ROOT --> COMPOSE[compose.yaml]
    ROOT --> CLAUDE[CLAUDE.md<br/>product-specific context only]
    ROOT --> ARCH[ARCHITECTURE.md<br/>as-built system model]
    ROOT --> CODE[/apps · /packages — implementation/]
```

| Element | Source | Notes |
| --- | --- | --- |
| `/spec` spine | `templates/spec/` | Product truth. See [Product spine](../concepts/product-spine.md). |
| `mise.toml` | scaffold | Toolchain pins + dev-loop tasks. mise is the single task entry surface: tasks declare ordering with `depends` (never `run = ["mise run …"]` chains), and `[deps.pnpm]`/`[deps.uv]` (`auto = true`, gated by `[settings] experimental`) auto-install workspace deps on lockfile change — no hand-rolled install task (so never run a bare `pnpm install`; route a manual one through `mise exec -- pnpm install`). Because that runs non-interactively, the bundled `pnpm-workspace.yaml` sets `confirmModulesPurge: false`; and for the **pinned** pnpm to win, `mise activate` must be sourced after any nvm/asdf/volta in your shell rc — otherwise a global copy shadows it (`/steer:doctor` flags this). App-level Node scripts stay in `package.json`; a mise task may delegate to them, but delegation is **one-way** — a `package.json` script never shells out to `uv`/Python nor re-defines a mise task, and no task lives in both files. A polyglot app's Python backend (e.g. `apps/api`) is a mise/`uv run` task, composed with a `[tasks.dev]` `depends = ["dev:*"]` fan-out so mise stays the single entry point. Run `/steer:reference conventions` for the full task model. |
| `mise.lock` | created at pin time | The real version pin. The scaffold ships **no** lock — `/steer:init`/`/steer:adopt` create it when they pin the toolchain (`touch mise.lock`, `mise install`, then `mise lock --platform linux-x64,macos-arm64` so the lock carries per-platform URLs + checksums — CI runs `mise install --locked` on `linux-x64`, which fails on a host-only lock). Until a populated lock is committed, CI runs a plain unlocked install; never commit an empty / comment-only lock. Run `/steer:reference conventions` for the full toolchain rationale. |
| CI workflows + PR template | scaffold | Quality gates and review template. |
| `.gitattributes` | scaffold | **Normalizes line endings to LF** (`* text=auto eol=lf` plus per-extension pins) so a Windows contributor's `core.autocrlf=true` can't check the repo out — or commit into it — with CRLF. That matters more than whitespace: a CRLF shell script does not warn, it fails to *parse*, which takes out `scripts/*.sh` and every CI step that runs them, and makes a Docker image's entrypoint unrunnable. Marks binaries (images, fonts) `binary` so they are never newline-normalized, and lockfiles (`pnpm-lock.yaml`, `uv.lock`, `mise.lock`) `-diff` — so a dependency-bump PR shows `Binary files differ` rather than thousands of lines; that suppresses only the *rendered diff*, never the content, so any gate reading committed state is unaffected and a reviewer can still run `git diff --text`. Also marks `CHANGELOG.md merge=union` so concurrent PRs appending bullets under `### [Unreleased]` auto-resolve — git's built-in union driver keeps both sides' added lines instead of raising a conflict. `/steer:init` and `/steer:adopt` install it where absent and reconcile it additively where one already exists. `/steer:sync` covers both cases by different routes: its step-5 additive reconcile splices missing pins into a `.gitattributes` the repo already has, and its step-6 **capability repair** (`line-ending-normalization`) detects the file being absent entirely and *proposes* creating it from the scaffold, waiting for a yes — it never creates it unasked and never runs `git add --renormalize .`. See [Windows setup](../getting-started/windows-setup.md#line-endings). Adding it does **not** convert CRLF already committed to history; that needs a one-shot `git add --renormalize .`. |
| `compose.yaml`, README quickstart | scaffold | Local run + onboarding. Host ports are env-overridable so they don't collide across products or worktrees. |
| `.worktreeinclude` | scaffold | Carries git-ignored local config (`.env`, `.mise.local.toml`, `.claude/settings.local.json`) into each `claude --worktree` — worktrees start from git refs only, so without it the app can't boot there. Its header also documents worktree **`mise trust`**: trust is path-keyed, so a new worktree starts untrusted and every `mise run …` there fails on trust until someone trusts it. A Claude Code session started in a worktree inherits the primary checkout's trust automatically (the `check-worktree-trust` session check — see [Hooks](hooks.md)); a plain terminal, or a worktree created mid-session with `git worktree add`, needs one `mise trust` there. |
| `scripts/worktree-env.sh` | scaffold | Sourced by `mise.toml` (`[env]._.source`) so parallel Claude Code worktrees of the same repo don't collide at runtime: it gives each worktree a unique `COMPOSE_PROJECT_NAME` and a stable per-worktree host-port offset (`POSTGRES_PORT`, `WEB_PORT`, `DATABASE_URL`). The primary checkout gets offset 0 (ports unchanged) and keeps its bare directory name; a linked worktree's project name is `<repo>-<worktree>`, because a worktree basename alone is not unique across repos. **Re-taking this file renames an existing linked worktree's stack**, so tear a running one down first — under the new project name Compose no longer sees the old containers or volumes (recover with `docker compose -p <old-name> down -v`) — in a polyrepo the same feature branch runs in several members, and a shared project name meant one member's `docker:clean` tore down another's containers and volumes. `mise run docker:clean` tears down a worktree's services + volumes before it is removed, scoped to that worktree — spelled `mise run ws:docker:clean` in a **workspace** repo, whose profile replaces core `mise.toml` and prefixes every whole-product task. This `[env]._.source` line is also what makes a new worktree need `mise trust`: mise loads a data-only config untrusted but refuses one that executes code at load time (see the `.worktreeinclude` row above). See the always-on **Parallel worktrees** rule. |
| `CLAUDE.md` | product | **Only** product-specific context — standards prose is never duplicated here. Carries the `<!-- steer:profile=… -->` marker (see Repo profiles). |
| `ARCHITECTURE.md` | scaffold | The **as-built** system model at the repo root — narrative and tables only, linking rather than inlining the rendered diagram at `spec/design/architecture-diagram.md`. Its staleness is checked by `/steer:audit code` (the DX & docs dimension), not by `/steer:audit spec` — that mode is spec-vs-spec, diffing the as-built `/spec` spine against the tracker spec export and reading neither the code nor this file. Required at the root by rules `20-layout` and `32-living-docs`, and allowlisted there by `22-housekeeping` so `/steer:tidy` never proposes relocating it. |

## Repo profiles

Not every managed repo is an app monorepo. A repo carries a **profile** —
`app` (default), `infra`, `service`, `library`, `cli`, or `workspace` — recorded
as a `<!-- steer:profile=… -->` marker on the `CLAUDE.md` `## Profile` section (a
sibling of the delivery-mode marker; **absent ⇒ `app`**, for back-compat).

`workspace` is the odd one out: it hosts a [polyrepo](../concepts/product-spine.md)
product's `/spec` spine and owns **no application code**. Its topology is derived
from disk (`spec/workspace.yml` at the host, `spec/PRODUCT.md` at each member),
never from this marker — so the marker follows the topology rather than declaring
it.

The profile is a **bootstrap-time** choice that selects an **additive** set of
scaffold layers `/steer:init` / `/steer:adopt` lay down (later layers only *add*):

- **Layer 0 — Core** (every profile): `mise.toml` toolchain pinning
  (`node`/`python`/`uv` mandatory — agent tooling needs them), the `/spec` spine,
  stack-agnostic CI hygiene, dotfiles, `policy/`, the version-pin scripts, and —
  deliberately for every profile — `compose.yaml` + `scripts/worktree-env.sh` (the
  containerize-by-default surface, so devs run backing services in Docker rather
  than on the host).
- **Layer 1 — Node baseline** (`profiles/_node/`, Node-stack profiles only):
  `package.json`, `pnpm-workspace.yaml`, `biome.json`, `configs/`, `packages/`.
  Every Node profile is a pnpm workspace (monorepo-by-default). The root
  `package.json` ships a `packageManager` placeholder that `/steer:init` stamps
  with the mise-pinned pnpm version, so corepack (e.g. in a Docker build) uses
  the same pnpm that wrote `pnpm-lock.yaml`. Skipped for
  `infra`, and replaced by `pyproject.toml`/Ruff for a Python-only product.
- **Layer 2 — Profile extras** (`profiles/<profile>/`): `app` adds `apps/`,
  `DESIGN.md` and `.claude/launch.json` (the Claude Desktop **Code tab**
  preview-server config — convenience only, never overwritten if the repo already
  has one); `service` adds `apps/`; `library`/`cli` add nothing (the skill
  adapts `package.json`); `infra` substitutes a tofu/terragrunt/ansible-flavored
  **root** `mise.toml` (which still pins `node`, sources `worktree-env.sh`, and
  defines the core `docker:up`/`docker:down`/`docker:clean` tasks the always-on
  worktree rules mandate — it keeps the core `compose.yaml`) and
  gets CI that auto-detects `*.tf`/Ansible and runs `tofu fmt` / `ansible-lint`;
  `workspace` **replaces** the core `README.md`, `mise.toml` and `compose.yaml`
  and adds `scripts/ws.sh` plus a `.gitignore` fragment. Its `mise.toml` drops
  pnpm/biome (no code here), keeps the agent-runtime baseline and `convert:doc`
  (PO documents land at the spine host), and adds the `ws:*` member tasks —
  including `ws:dev`, which as shipped boots the members' backing **services**
  via Compose `include:`; the *app* half (each member's own dev server) needs
  mise monorepo mode enabled plus one `depends` entry per member with a `dev`
  task, which `/steer:init` resolves from the manifest. Every task the workspace
  profile defines is `ws:`-prefixed (bar `convert:doc`) so that it cannot shadow
  a member's own task; its `compose.yaml` declares **no services**
  and `include:`s each member's file. The member checkouts are git-ignored
  clones, not submodules, so nothing pins a member SHA.

So a non-app repo is never skipped at bootstrap — it shares all of Core, and an
`infra`, `library` or `cli` repo that genuinely runs no local services simply
deletes the core `compose.yaml`. That deletion is what licenses pruning the
`docker:*`/`db:*` tasks: keep the compose file and you keep the tasks, because the
always-on worktree and end-of-session rules mandate `mise run docker:clean`. An `infra`
repo may drop the paired `scripts/worktree-env.sh` (and its `mise.toml`
`[env]._.source` line) too; a `library`/`cli` should keep it, since
`worktree-port-isolation` reports `n/a` only when the stack is `none`. The **installed** repo layout is unchanged by this organization;
only the plugin's bundle and the init/adopt composition differ.

Always-on **rules** do not read the marker — they self-gate on filesystem
**traits** via the `inject-when` mechanism, so the injected rule context always
matches what is on disk. Only four expressions actually gate a
shipped rule: `code-project` (19 rules), `has-iac` (`12-stack-infra`),
`tracker-github` (`36-issue-first`) and the composite `has-iac|has-apps`
(`52-deployment`) — so `has-apps` appears only inside that composite.
`lib/scope.sh` also defines `has-compose`, `has-infra`, `polyrepo`,
`has-workspace-manifest` and `has-product-pointer`, all of which are
**available but carry no rule today** — the polyrepo topology is deliberately
delivered by a SessionStart note rather than an always-on rule, so the existence
of the `polyrepo` token is not evidence that a `21-polyrepo` rule exists. A monorepo that *also* has a nested `/infra` dir stays profile `app` and
still gets the infra-stack rule automatically because `/infra` exists. The
deployment rule reaches it either way: it gates on `has-iac` **or** `has-apps`,
since any app/service repo deploys — with or without an `/infra` dir. The
profile is read by `/steer:sync` and `scripts/scan-capabilities.sh`
(an informational `profile` fingerprint) for reporting and overlay decisions.

## Root housekeeping

The root holds scaffolding, config, and the four standing documents the rules
require there — `README.md`, `CLAUDE.md`, `ARCHITECTURE.md` and `DESIGN.md` — not
the spreadsheets, decks,
diagrams, and **specification / requirements documents** (`.pdf`, `.docx`, decks
— specs, briefs, RFP/SOW) that feed the spec. Those are **source material**:
their home is `/spec/reference/`; architecture and flow diagrams go to
`/spec/design/`.

`DESIGN.md` is not documentation for humans only — it is **read**. A skill that
renders a shareable Claude Artifact styles the page from the tokens `DESIGN.md`
declares (root, or `apps/<app>/DESIGN.md`), falling back to the house default
only when the repo declares none — rule `88-artifacts` and, in practice,
[`/steer:explain`](skills.md). Populate it and stakeholder-facing pages carry the
product's own palette, type scale, and spacing; leave it empty and they carry the
generic look. Never an invented brand either way.

Steer keeps the root clean as it works. When a session notices a loose root file
it can **confidently classify**, it **moves it to the right home immediately**
(`git mv`, filename preserved) — no confirmation for a move that was never in
doubt. Confirmation is reserved for where judgment or loss is at stake:
**renaming** a cryptic name to a cleaner one is *proposed* (the file still moves
now, under its existing name); a file whose purpose or correct home is
**ambiguous** — or a `Copy of …` / look-alike pair — is **asked about** before
anything happens; and **deletion** is never automatic, always waits for a yes,
and covers only two cases — true OS junk like `.DS_Store` (which also gets a
`.gitignore` pattern so it can't return), and an **already-absorbed source**, a
spec/requirements doc whose bytes match a committed `spec/sources/**/original.*`,
where deleting the redundant duplicate beats filing a second copy (no
`.gitignore` pattern there — it isn't junk, and a later version is expected). Run
[`/steer:tidy`](skills.md) for a full sweep of an accumulated pile.

## Scaffold storage convention

Scaffold dotfiles are stored in the plugin **without the leading dot**
(`gitignore`, `env.example`, `github/`, `claude/`, …) so they don't act on the
plugin repo itself. `MANIFEST.md` maps each stored file to its installed path
(adding the dot back). When a standard implies concrete scaffolding, the scaffold
bundle is updated in the **same change** as the rule.

When `/steer:init`, `/steer:adopt`, or `/steer:sync` install a scaffold file that
already exists in the target repo, they **merge additively and never clobber**:
Markdown spec files reconcile on heading/checklist anchors (`template-reconcile.sh`),
and the structured-config files — the line-based `.gitignore` / `.gitattributes` /
`.worktreeinclude` and the JSON configs `.claude/settings.json`, `biome.json` and `tsconfig` —
reconcile with `scaffold_reconcile.py`, which unions
JSON arrays and adds missing keys/lines without overwriting, reordering, or
removing any existing value.

The committed editor configs (`.vscode/extensions.json`, `.vscode/settings.json`,
and `.vscode/mcp.json` — the last being how Copilot/VS Code teammates get the same
MCP servers) are **merged by hand**, not by that script: all three templates carry
`//` comments, and `scaffold_reconcile.py` parses with strict JSON, so it refuses
them. They are yours once installed — merge additively, drop what you don't use.
VS Code is the default editor; see the Stack rule / `/steer:reference conventions`.

The one exception is the `.claude/settings.json` `permissions` block, which
Claude Code evaluates by precedence **deny > ask > allow**. There, the same
pattern in two tiers is a contradiction rather than a choice (the
lower-precedence copy never governs), so after merging, the reconcile keeps each
permission pattern only in its most-restrictive tier and drops the others —
preventing a sync from leaving, say, `Bash(git push)` in both `allow` and `ask`,
and healing a repo already in that state. Because the surviving tier is the one
that already governed, effective behavior is unchanged.

## Versioning the contract

`/spec/.version` records the plugin version the spine was last reconciled
against. After a plugin release, `/steer:sync` applies pending structural
migrations from the ledger, reconciles additively, and re-stamps `.version`.
Ledger migrations cover the non-additive changes reconciliation cannot express
— renames and moves (`git mv`), deletions (`git rm`), **in-file token
rewrites** (replacing a string that already exists in a materialized file, e.g.
the `e22-standards` → `steer` rebrand), and **whole-file or whole-section
re-takes** (the file's content, or one bounded region of it, has moved past any
enumerable set of old→new pairs, so the current template replaces it; a section
re-take states its region boundaries) — each applied read-then-propose,
never clobbering filled-in content, and each carrying the consumer's own edits
forward rather than discarding them.

Two ledger entries landed in **3.23.0**: the living global architecture diagram is renamed
`spec/design/architecture.md` → **`spec/design/architecture-diagram.md`** (a
`git mv` plus an enumerated in-file token rewrite, so history follows the file
and the links to it are updated), and the retired `markitdown` MCP server is
cleared from `.mcp.json` / `.vscode/mcp.json` (harmless until the migration
runs — the converter is now the on-demand `mise run convert:doc` task). Neither
requires manual work; `/steer:sync` proposes both.

**Six** further entries landed in **3.24.0**. Four are non-additive
edits to materialized files that reconciliation cannot carry: `scripts/worktree-env.sh`
gains a repo prefix on `COMPOSE_PROJECT_NAME` in a linked worktree (a whole-section
re-take — and **tear any running linked-worktree stack down first**, or its containers
and volumes are orphaned under the new project name); `spec/tracker.md`'s promoted-
question rule is reversed (the `### Q-NNN` block now *stays*, with the ref in its
`tracker:` field); a polyrepo member's `spec/PRODUCT.md` spine-resolution ladder now
requires `spec/workspace.yml` to be **present at** `workspace.path` rather than merely a
directory (resolved against the primary checkout — from a linked worktree the
recommended relative `..` otherwise lands on a real but empty directory and the
product's specs read as absent); and `spec/PRODUCTIONIZATION.md`'s open-question seed
becomes a `### Q-NNN` field block, because the SessionStart hook and `/steer:questions`
count only those, so the old bullet seed modelled a shape neither one sees. The fifth
covers the workspace task rename. The workspace profile's
whole-product tasks are now `ws:`-prefixed (`ws:dev`, `ws:docker:up` / `down` /
`clean`), because an unprefixed name in the workspace's `mise.toml` is an ancestor
config in every member cloned inside it and shadows any member that does not define
that name. `mise.toml` is materialized and product-owned, so additive
reconciliation cannot carry a *rename* — it splices in what is missing and would
leave both the old and the new names in place. That is exactly the case a ledger
entry exists for, so the rename ships as one: `/steer:sync` proposes the four task
headers, repoints every reference to a renamed task (including the live `ws:dev`
`depends`, which resolves in the *caller's* task set and would otherwise bind to a
member's `docker:up`), **re-takes `scripts/ws.sh`** whole — the new script carries
the `preflight` subcommand the rename points a task at, plus its own stale `mise run
dev` header comment and `ws:`-prefixed failure messages, so no enumerable pair set
describes it; a consumer's added `ws:` subcommands carry forward —
replaces `ws:docker:up`'s first `run` element with that `preflight` guard while
leaving the line that boots the stack alone, and relocates the whole commented
monorepo section above `[settings]` where mise will actually accept the key. The entry is precondition-gated to `workspace`-profile
repos, so member repos and non-workspace profiles are untouched.

The sixth is an in-file token rewrite in the scaffold's `infra/README.md` — the copy
materialized into **a monorepo with a nested `/infra` dir**, which stays profile `app`,
*not* the `infra` profile (a root-level infra repo keeps these conventions in its own
README, which this entry leaves alone). Its
state-backend prose named **S3 + DynamoDB locking** and told the reader to bootstrap a
bucket *and lock table*, while rule `12-stack-infra` mandates S3 with the native
`use_lockfile` lock (S3 conditional writes replace the table). Both lines are
procedural — a human follows one to bootstrap an environment and the other to write
`root.hcl` — so a repo still carrying them provisions a lock table the standard no
longer wants. The entry rewrites **only those two lines** and is precondition-gated on
one of the stale tokens still being present. It deliberately stops at the prose: moving
a *live* state backend off a DynamoDB lock table is an infrastructure change with its
own plan, review, and blast radius, so if the repo's `root.hcl` still configures
`dynamodb_table`, `/steer:sync` lands the prose fix, says so, and hands the backend
migration to a dev as separate work.

One further entry landed in **4.0.0**, and it makes the action history a **directory of
immutable per-entry files**, `spec/history/YYYY-MM-DD-HHMM-<slug>.md`, replacing the
single append-only `spec/HISTORY.md`. It is the most consequential entry for an adopted repo,
and it is deliberately not a move: the old file is **frozen in place** as the
pre-migration archive and is **never split** into per-entry records, because those
entries are immutable review evidence that a bulk rewrite would re-date and risk
mangling. The entry creates the directory (materializing `spec/history/README.md`, the
format doc), adds the frozen banner to the archive's header prose without touching a
single entry below `## Entries`, and rewrites the old path in the live instruction
surfaces reconciliation cannot reach — `ci.yml`'s `spec-drift` filter (which matches
date-named entries only, so editing the directory's `README.md` format doc does not
clear the gate, and keeps `^spec/HISTORY\.md$` alongside the new pattern so a repo
mid-migration is not flagged),
the PR template's living-docs checkbox, `README.md`, `CLAUDE.md`, `spec/tracker.md`,
each `spec/sources/*/source.md`, and a polyrepo member's `spec/PRODUCT.md`. It leaves
`.github/copilot-instructions.md` and `.github/prompts/*` alone — those are re-copied
from the plugin on the same sync — and a false-positive guard keeps it away from
provenance prose, where a mention of `spec/HISTORY.md` is a legitimate record of where
something was written at the time. In a polyrepo the history belongs to the
**workspace**, so a member gets no local `spec/history/` and only four of those
rewrites — `CLAUDE.md`, `spec/PRODUCT.md`, the PR template and `ci.yml`.
Finally the migration logs itself as the directory's first entry, which both satisfies
the living-docs rule for the migration PR and proves the new path works.

The newest entry, keyed **5.0.0**, narrows a feature's spec
`> Status:` from five values to **`draft · approved · live`**. `implemented` and
`validated` are retired — they were pure mirrors of the issue's `validate`/`done`,
a derived value stored in a second file that nobody recomputed. The entry applies
only if some `spec/features/*/intent.md` still carries a retired value or still
prints the five-value enum hint; a spine already on three values is skipped. It
rewrites `implemented` → `approved` (the build is the issue's business; scope
approval is what the spec holds) and `validated` → `approved` **unless the feature
is genuinely released**, in which case `live` — and where release state is not
evident from the repo, it deliberately takes `approved` and **says so in the sync
PR** for a human to promote, rather than guessing `live`. It **touches no issue**:
an intent reading `approved` beside an issue reading `done` is the intended
pairing, not drift. The PO-acceptance checkboxes, including *PO validated the
working demo*, are left alone — that record now carries the acceptance that
`Status: validated` used to imply. In a polyrepo `spec/features/**` belongs to the
**workspace**, so a member applies none of it locally.

Ledger entries are keyed by the release that **introduced** them, and `/steer:sync` skips
every entry at or below a repo's `spec/.version` stamp. An entry authored but not yet cut
is keyed `[Unreleased]` — never a guessed number, since an implementation PR merges before
the release that names it — and the release PR renames it. A `[Unreleased]` heading is
never "at or below" any stamp, so such an entry is always walked by its precondition
rather than silently skipped.

Because the history is now append-only *per file*, a **correction is a new entry**
carrying `- **Corrects:** <filename>` — never an edit to the entry it corrects.
