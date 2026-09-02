# Polyrepo — one product, several repos

Loaded on demand by `/steer:reference polyrepo`; costs nothing in a single-repo
product.

There is deliberately **no always-on rule** for this topology. The always-on
ruleset is capped on its on-disk total, which every consumer pays even for a rule
scoped to a minority of repos. Instead `orient-session.sh` emits a short,
role-specific note at SessionStart in a repo that actually carries
`spec/workspace.yml` or `spec/PRODUCT.md`, and points here.

Both markers live under `spec/` deliberately. The manifest is product-level
truth — which repos this product is made of — so it belongs with the rest of the
spine rather than loose at the root, where it would be steer's only unnamespaced
root file and would sit one rename away from moon's `.moon/workspace.yml`.

## Recommend a monorepo first

steer is repo-scoped by construction: one repo, one product, one `/spec` spine.
That is the better arrangement and this reference does not change it. Adopt this
topology only when the split is **externally mandated** — separate deployment,
ownership, or compliance boundaries — and say so out loud before anyone adds a
repo. "We already have three repos" is not a mandate; it is a migration you have
not costed yet.

What this buys: a single product spine across repos, and reports that know how
much of the product they actually covered.

What it does **not** buy, ever: **atomic cross-repo commits**. A frontend/backend
contract change is still two PRs that can merge out of order. This topology makes
that visible; it cannot make it atomic. If you need atomicity, you need a
monorepo.

## The two roles

| | **workspace** | **member** |
| --- | --- | --- |
| Marker | `spec/workspace.yml` | `spec/PRODUCT.md` |
| Trait | `has-workspace-manifest` | `has-product-pointer` |
| Profile | `workspace` | `app` / `service` / `infra` / `library` / `cli` |
| Holds | THE product `/spec` spine | code, tests, CI |
| Code | none | all of it |

Both roles match the `polyrepo` trait, which is what gates the SessionStart note.
A repo carrying both markers is malformed; `workspace` wins and `/steer:audit`
reports the contradiction.

## Where each artifact lives

**In the workspace, once:**

- `vision.md`, `users.md`, `glossary.md`, `spec/history/`, `spec/app/`
- `spec/tracker.md` — the tracker for the whole product
- **all** of `spec/features/**` — every `intent.md` and `contract.md`
- `spec/sources/` and `spec/reference/` — PO source documents and research feed
  the *product*, so `/steer:intake` lands them here, not in the member it ran from

**In each member:**

- `spec/PRODUCT.md` — the pointer, and the thing that makes the repo a member
- `spec/decisions/` — ADRs about *this repo's* internals
- `spec/design/` and `DESIGN.md` — this repo's own design sources and system design
- `ARCHITECTURE.md` — how *this repo* is built
- the code

The split is not "product files vs. the rest" but **product truth vs. this
repo's internals**: anything a sibling repo would need to read lives once in the
workspace; anything that only describes *this* codebase stays here. A spine
directory absent from both lists above follows that same test — and `/steer:tidy`
must not create a product-level one locally in a member.

Feature specs live in the workspace because that is the whole point. The
layout conventions already let a feature span apps and packages; in a polyrepo it spans
*repos*, and an `intent.md` can only live in one of them. Put it above the repos
and a cross-repo feature has exactly one intent. Put it in a member and every
sibling working that feature has no intent to load — which is the split-brain
this topology exists to prevent.

A member's spine is therefore **partial by design**, and the tooling knows it:
`steer_spine_state` requires only `PRODUCT.md` when the pointer is present, so a
member reports `managed` rather than `damaged`. Do not "fix" a member by adding
product-level files — that recreates the fragmentation.

## Resolving the spine from a member

1. `workspace.path` in `spec/PRODUCT.md` is set **and `spec/workspace.yml` is
   present at that path** → read the spine from there.
2. Otherwise → read `workspace.repository` at `workspace.branch` over the GitHub
   gateway (`/steer:tracker-sync`). No local clone required.
3. Neither → say the spine is unreachable and **stop**. Do not proceed on a guess
   and do not create local product-level files to fill the gap.

Absent local intent is never "no intent". It means the workspace has not been
read yet.

**Step 1 tests for the manifest, not for a directory, and resolves against the
primary checkout.** Both halves exist because of worktrees. `workspace.path` is
relative to the checkout it was written against, and a linked worktree
(`.claude/worktrees/<name>`) is a different root — so the `..` this topology
recommends resolves from a worktree to `<member>/.claude/worktrees`, which
*exists*. A step 1 that accepted any existing directory therefore read an empty
tree, reported every product-level spec as absent, and never reached the gateway
in step 2 — silently, in the repos holding all the code. `steer_workspace_root`
(`hooks/lib/scope.sh`) implements both halves for the hooks; skills resolving the
spine themselves must apply the same two tests.

## Reporting across members

`/steer:next`, `/steer:status`, `/steer:audit`, `/steer:roadmap` and
`/steer:protect` walk one tree by default. In a polyrepo that would hand a client
a fraction of the product with no indication it was a fraction — worse than a
smaller, honest answer.

Every such report must:

- name the members it covered and how (local checkout / gateway), and
- name any member it could reach **neither** way as **uncovered** — explicitly,
  never by omission.

Naming the uncovered members is **unconditional** — every report does it, and no
setting turns it off. `spec/workspace.yml` → `reporting.require_all_members`
records that expectation explicitly for the humans and audits reading the
manifest; it is a declaration, not a switch the skills branch on. Silence must
never read as "nothing there".

## Tracker behaviour across repos

- **Sub-issues cross repositories.** GitHub supports a parent and child in
  different repos within an org — 100 sub-issues per parent, 8 levels of nesting.
  `/steer:issues` decomposition works across members unmodified.
- **Projects v2 is already cross-repo**, so a roadmap spans a polyrepo for free.
- **Milestones are per-repo.** Release grouping must move to a Project
  iteration or single-select field; a milestone cannot span members.
- **Closing keywords do not cross repos.** A PR in a member cannot auto-close an
  issue in the workspace's tracker — GitHub honours `Closes #N` only within one
  repository, and a cross-repo form renders as a plain reference. Write
  `Refs owner/repo#N` and close the issue explicitly after merge.

## Drift crosses the repo edge; the gates do not

Rule `55-drift-gates` and `/steer:audit spec` compare as-built against intended
**within one tree**. A contract change in one member that invalidates another
member's assumption is invisible to both. No gate catches this for you.

When you change a shared contract, flag the drift class as usual **and name the
affected sibling** in the PR description. Each member's `ARCHITECTURE.md`
describes how *that repo* is built; the **cross-member** model — how the members
fit together — belongs in the workspace's.

CI is blind here too: the workspace repo cannot see member code without cloning
it, which needs credentials for each private member. Treat cross-repo drift as an
interactive `/steer:audit` concern, not a merge-time gate, until that is wired.

## Scaffold duplication is real and only partly solvable

Each member carries its own `mise.toml`, `policy/versions.yml`,
`policy/branch-protection.yml`, CI workflow, and `/spec/.version`. `/steer:sync`
runs per repo, so N members can settle on N plugin versions. Mitigations:

- **Reusable workflows** for CI, referenced by each member instead of copied.
- **Org-level rulesets** instead of N branch-protection applications — but note
  these require **GitHub Team or Enterprise**. On Free, `/steer:protect` still
  runs per member and the copies stand.
- Sync the members deliberately, in one pass, and check `/spec/.version` agrees
  across them.

## Running the whole product locally

The members are cloned **inside** the workspace, at the `path:` each declares in
the manifest, and git-ignored there. They are ordinary clones, not submodules:
nothing pins a SHA, so no member commit ever dirties the workspace, and each
member stays a normal repo you branch and push from directly.

```text
acme-workspace/
├── spec/                  THE product spine (+ workspace.yml)
├── mise.toml              ws:* tasks only, monorepo config_roots
├── compose.yaml           include: one entry per member that runs services
├── scripts/ws.sh          the member driver behind the ws:* tasks
├── .gitignore             /frontend/ /backend/ *.code-workspace
└── frontend/ backend/     git-ignored clones — NOT submodules
```

| Task | What it does |
| --- | --- |
| `mise run ws:clone` | Clone every member that declares a `path:`, at its manifest branch. Idempotent. |
| `mise run ws:sync` | Fetch + **fast-forward only**. Refuses a dirty tree, a detached HEAD, a branch other than the declared one, or a divergence — it never rewrites a member's history. |
| `mise run ws:status` | Per member: branch, dirty, `/spec/.version`, and drift between the manifest and `compose.yaml` / `.gitignore`. |
| `mise run ws:code` | Generate `<product>.code-workspace` (multi-root VS Code). Generated + git-ignored: edit the manifest, not the output. |
| `mise run ws:list` | List every member the manifest declares — name, repo, branch, profile, local path. |
| `mise run ws:dev` | Boot every member's services via Compose `include:`. As shipped that is all it does — the dev-server half needs monorepo mode (uncomment `[monorepo]`) plus one `depends` entry per member with a `dev` task; `/steer:init` resolves those from the manifest. |
| `mise run ws:docker:up` / `ws:docker:down` / `ws:docker:clean` | The aggregated stack alone: start it and wait for health, stop it, or tear it down with its volumes. |

### Every workspace task is `ws:`-prefixed — and must stay that way

The workspace `mise.toml` defines **no unprefixed task** except `convert:doc`. That
is an invariant the topology depends on, not a naming preference.

Members are cloned inside the workspace, and mise loads **every ancestor config** —
so the workspace's `mise.toml` is loaded in every member and every member worktree
(`cd backend && mise config ls` lists both). This is plain config-hierarchy
behaviour, present whether or not monorepo mode is on. For a name the member also
defines, the nearest config wins and the member's own task runs. The bite is names
the member does **not** define: they fall through to the workspace's file, silently
and with nothing in the output saying the task came from another repo.

Unprefixed, that turned two ordinary commands into cross-repo surprises:

- `mise run dev` in a member — the most natural command in the repo, and one the
  core scaffold does not define (a Node-only member runs `pnpm dev`) — booted the
  **whole product's** aggregated Compose stack.
- `mise run docker:clean` in a member that ships no `compose.yaml` (a library or cli
  member, which the core scaffold lets you strip) tore down **every** member's
  containers *and volumes* — while rule `24-worktrees` tells every agent to run
  exactly that command before removing a worktree.

`ws:`-prefixing removes the fall-through by construction: no member scaffold defines
a `ws:*` name, so nothing the workspace defines can shadow a member's task.
`convert:doc` is the one exception and is safe because its `run` command is identical
to the core scaffold's — falling through to it converts the same way. Only `run` has
to match: the descriptions differ, and that is all a `check_standards.py` guard
asserts, because the command is the only load-bearing half.

Two corollaries:

- **`ws:*` from inside a member is legitimate.** mise runs a task in its own
  config root, so `cd backend && mise run ws:status` reports on the workspace, which
  is what you asked for. Reachability was never the defect; shadowing was.
- **Cross-boundary `depends` must use the `ws:` name.** `depends` resolves by name
  in the *caller's* task set, so `ws:dev`'s dependency is spelled `ws:docker:up`; a
  bare `docker:up` would bind to the **member's** task whenever `ws:dev` is invoked
  from inside a member, booting one member's services and calling it the product.

**mise monorepo mode** makes each member's own `mise.toml` a config_root, so
`mise //backend:test`, `mise '//...:lint'`, cross-project `depends`, and shared
`[task_templates]` all work from the workspace, and trust propagates from the
workspace root down to the members (not to a *linked worktree* — its root is a new
path, trusted separately). It also seals bare-name fall-through on its own: with it
on, `mise run dev` inside `backend` resolves as `//backend:dev` rather than reaching
the workspace, and the workspace's own tasks are addressed `mise run //:ws:dev`. The
`ws:` prefixes do not depend on that and are not made redundant by it — they hold
before any member is cloned, which is exactly when a fresh workspace is most
exposed.

Monorepo mode is **off in the shipped scaffold** and turned on once members are
cloned — the workspace `mise.toml` carries the block to uncomment. Three things to
get right:

- `monorepo_root = true` is a **top-level key**, not a `[settings]` entry. Nested
  under `[settings]`, mise reports `unknown field: settings.monorepo_root` and
  monorepo mode simply never turns on — that warning is the only signal you get.
  TOML puts a bare key in the table above it, so the scaffold keeps the commented
  line above `[settings]`; uncomment it in place.
- List the member dirs in `[monorepo].config_roots` **explicitly** — filesystem
  auto-discovery of subdirectory configs is deprecated upstream.
- Leave `[monorepo].lockfile` **unset** unless your mise release accepts it: the
  current release rejects the key (`unknown field: monorepo.?.lockfile`) and warns on
  every invocation. Per-member locks — what a polyrepo wants, since a member must
  stay buildable standalone — are today's default. When you do set it, set `false`.

**Compose `include:` does not merge on a name collision** — it warns and takes one
side, so two members that both ship a service called `postgres` give you one
database and a warning, not two. Namespace service, volume and network names in
each *member's* compose file. Host ports are a separate problem the topology does
not solve: every member's scaffold publishes `${POSTGRES_PORT:-5432}`, so give
each member a distinct base port in its own `.env`. Container/volume/network names
do not clash between a member's worktrees or across members — mise sources
`scripts/worktree-env.sh`, which sets `COMPOSE_PROJECT_NAME` to the repo's
directory name for a primary checkout and `<repo>-<worktree>` inside a linked
worktree. Two *primary* checkouts sharing a directory name (two products each
with a member called `backend`) still share one Compose project: clone them under
distinct names, or set `COMPOSE_PROJECT_NAME` in one repo's `.env`. The repo prefix is load-bearing
here and not in a single-repo product: a polyrepo runs the same feature branch in
several members at once, so a name taken from the worktree basename alone put
`memberA`'s `feat-x` and `memberB`'s `feat-x` in the *same* Compose project — and
`mise run docker:clean` in one then tore down the other's containers and volumes.

## Worktrees of the workspace repo have no members

Members are git-ignored clones, and a worktree is populated from git refs, so a
worktree of the workspace is a spine host with **zero members**: `ws:status`
reports `NOT CLONED` for every one, and `mise run ws:dev` cannot boot anything.
`.worktreeinclude` cannot fix this — a member is a whole repo with its own `.git`,
not local config to copy.

Do spine work in a workspace worktree freely; run the *product* from the primary
checkout. `mise run ws:clone` does work inside a worktree if you want a second set
of clones, but they land at the manifest branch, not the worktree's, and they cost
a full duplicate of every member. `mise run ws:status`, and the `ws.sh`
subcommands behind it (`sh scripts/ws.sh check`, `sh scripts/ws.sh preflight` —
neither has a `mise` task wrapper), all name this state explicitly rather than
reporting an absent member as drift.

This is a **partial monorepo simulation** and worth naming as such: coupled local
development without atomic cross-repo commits. Nothing above changes the fact
that a contract change across two members is two PRs.
