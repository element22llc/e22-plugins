# 0001 — Polyrepo support via a workspace repository

> Status: Proposed
> Date: 2026-07-26
> Deciders: [to be ratified — e22-plugins maintainers]

## Context

steer is **repo-scoped by construction**: one repo = one product = one `/spec`
spine. Every skill anchors on the work-tree root (`hooks/lib/repo-root.sh`), and
every spine artifact is read relative to it.

Some clients cannot use a monorepo — the split is mandated by separate
deployment, ownership, or compliance boundaries. Their products arrive as
`frontend` + `backend` + `infra` repos. Today steer *runs* on each of those repos
without error, because **profiles are already the polyrepo primitive**: a
polyrepo product is profile `app` + profile `service` + profile `infra`, each
bootstrapping with the right scaffold overlay, and rules self-gate on filesystem
**traits** rather than the profile marker, so each repo's rule context already
matches its disk.

What breaks is not execution — it is that **the product spine fragments N ways**:

1. **Split-brain spine.** `vision.md`, `users.md`, `glossary.md`, `HISTORY.md`
   and `spec/app/` are *product*-level. Three repos produce three of each, each
   diverging. Feature specs fare worse: rule `20-layout` already allows a feature
   to span several apps/packages, but in a polyrepo it spans several *repos*, and
   `spec/features/<id>/intent.md` can live in only one — so `/steer:work` in a
   sibling repo has no intent to load.
2. **Cross-repo closing keywords silently fail.** `/steer:work`, the PR template,
   and the issue-workflow reference all emit `Closes #N`. GitHub honors closing
   keywords **only within the same repository**. The tracker contract
   (`templates/spec/tracker.md`) already exposes `repository:` as a free field, so
   centralizing issues is permitted today — and the moment anyone does it, every
   merge leaves its issue open and the lifecycle transition never fires. This is a
   live defect independent of any polyrepo feature.
3. **Drift gates go blind at the repo edge.** `55-drift-gates` and
   `/steer:audit spec` compare as-built against intended within one tree. A
   backend contract change that invalidates a frontend assumption is invisible to
   both repos' audits — the canonical polyrepo failure mode. Likewise
   `ARCHITECTURE.md` is root-level and per-repo, so no repo holds the system model.
4. **N× duplicated, drifting scaffold.** Each repo carries its own `mise.toml`,
   `policy/versions.yml`, `policy/branch-protection.yml`, `ci.yml`, generated
   Copilot artifacts, and `/spec/.version` stamp. `/steer:sync` re-stamps per repo,
   so N repos settle on N plugin versions.
5. **Partial reports presented as whole.** `/steer:status`, `/steer:next` and
   `/steer:roadmap` walk one spine and would hand a client a fraction of the
   product without saying so.
6. **No cross-repo local dev.** `scripts/worktree-env.sh` isolates ports and
   Compose project names *within* a repo; running frontend + backend + database
   together across repos has no story at all.

## Decision

Support polyrepo as a **first-class topology built around a workspace
repository**, where the workspace repo is *also* the product spine repo. Member
repos are **gitignored sibling clones driven by a manifest**, never submodules.

```text
<product>-workspace/
├── spec/                      # THE product spine — vision, users, glossary, HISTORY, app/, features/
├── workspace.yml              # manifest: member repos, profiles, default BRANCHES (not SHAs)
├── mise.toml                  # monorepo_root = true; ws:clone / ws:sync / ws:status / dev
├── compose.yaml               # include: each member's compose.yaml
├── <product>.code-workspace   # GENERATED from workspace.yml
├── .claude/settings.json      # adds the member dirs to the session; enables steer
├── .gitignore                 # ignores the member checkout dirs
└── frontend/ backend/ infra/  # gitignored clones — not submodules
```

The manifest declares **branches, not SHAs**, because members are peer repos
under active development rather than vendored dependencies. `ws:clone`
materializes it, `ws:sync` pulls every member, `ws:status` reports per-member
branch / dirty / ahead-behind.

### Mechanisms, all of them pre-existing

**mise `monorepo_root = true`** carries the task layer natively. Each member
clone's `mise.toml` becomes a `config_root`, which yields `mise //backend:test`,
`mise //...:lint` across every member, cross-project `depends`, shared
`[task_templates]` with pinned tools, subdirectory tasks inheriting parent-config
tools, and — the quiet win — **implicit trust of all descendant configs when the
root is trusted**, so cloned members need no `mise trust`. This feature is
experimental upstream; it is the one component of this decision expected to churn.

**Compose `include:`** gives one-command whole-product boot. The long syntax
(`path` + `project_directory` + `env_file`) resolves an included file's relative
paths against *its own* directory, so member Compose files stay valid standalone,
and inclusion is recursive. Two constraints follow: `include` **warns on service
name collisions and does not merge them**, so member service names must be
namespaced; and the workspace needs its own `COMPOSE_PROJECT_NAME` so it cannot
collide with a member's standalone `mise run docker:up` under the existing
`worktree-env.sh` scheme.

**A generated `.code-workspace`** provides multi-root editing, per-folder
settings, and one search across members. It is editor sugar only and is generated
from the manifest, never hand-maintained. Claude Code does not read it; the
Claude-side equivalent is adding the member directories to the session, which
belongs in the workspace `.claude/settings.json`.

**Org-level GitHub mechanisms** retire most of gap 4:

| Mechanism | Replaces |
|---|---|
| Org-level repository rulesets | N copies of `policy/branch-protection.yml`; upgrade path for `/steer:protect` |
| Reusable workflows (`uses: org/repo/.github/workflows/ci.yml@v1`) | N drifting copies of `ci.yml` and the generated Copilot artifacts |
| Projects v2 (already cross-repo) | Nothing — `/steer:roadmap` already spans a polyrepo. But **Milestones are per-repo**, so release grouping must move to a Project iteration or single-select field |
| Org `.github` repository | Default issue forms and health files for members that carry none |

### Consequent changes to the plugin

- **A sixth profile, `workspace`** — spine plus orchestration; no Node layer, no
  `apps/`.
- **Topology markers** on the product `CLAUDE.md`, siblings of `steer:profile`:
  `<!-- steer:topology=polyrepo -->` and `<!-- steer:spine=owner/repo -->`.
  Absent means `monorepo`, mirroring the profile marker's absent-means-`app`
  back-compat rule.
- **A `spec/PRODUCT.md` in each member repo** naming the workspace repo, the
  sibling repos with their profiles, and this repo's published and consumed
  contract surface — the file that makes a member self-describing and gives the
  audits something to diff across the boundary.
- **A `has-workspace-manifest` trait.** `steer_repo_root` walks up to the nearest
  `.git`, so a session inside `backend/` correctly anchors on the member and gets
  member-appropriate rules. A session started at the **workspace root**, however,
  sees workspace traits (no `apps/`, no `package.json`) and would inject a thin,
  wrong ruleset. The trait resolves this consistently with the existing
  traits-not-markers discipline.
- **Fix the cross-repo closing keyword unconditionally**, independent of the rest
  of this ADR: when the tracker's `repository:` differs from the code repo, emit a
  plain `Refs owner/repo#N` and close the issue via `/steer:tracker-sync` after
  merge.

## Alternatives considered

- **Git submodules** — rejected. Submodules pin SHAs, but peer repos under active
  development want "current branch". Every member commit dirties the workspace
  repo, so the team either commits pin bumps constantly (noise, plus a "product
  version" that is really just whoever committed last) or lives permanently dirty.
  Detached HEAD by default is the most common way people lose work in submodules,
  and that cost lands hardest on product owners entering through `/steer:build`,
  who are least equipped to recover. Add a standing tax of `--recurse-submodules`
  on clone and pull. Submodules *would* be right for pinning "the whole product at
  v1.4.0" as audit evidence — but a `releases/v1.4.0.yml` recording SHAs achieves
  that without infecting daily development.
- **Status quo (full spine in every repo)** — rejected. It is what clients get
  today and it is precisely gaps 1, 3 and 5: N visions, N glossaries, N histories,
  and audits that stop at the repo edge.
- **Pointer-only satellites with no workspace repo** — a designated existing repo
  (usually the backend) holds the spine, and satellites carry only a
  `spec/PRODUCT.md` pointer. Rejected as the primary answer because it solves the
  spine split but nothing about local dev, and it burdens one product repo with
  cross-product concerns. It survives as the **degenerate case** of this ADR: a
  team unwilling to add a repo can designate an existing member as the spine and
  skip the orchestration files.
- **Google `repo`, `vcstool`, `meta`, `mu-repo`, `gita`** — rejected. `repo` is
  heavy, Android-flavored and weak on Windows; `vcstool` is decent but adds a
  Python dependency for what ten lines of a mise task already do; the rest are
  thin wrappers with maintenance risk. The manifest plus mise tasks covers the
  same ground with no new dependency.
- **Tilt / Skaffold / DevSpace** — rejected at this scale. They are the correct
  answer for many services on Kubernetes, and they duplicate what Compose
  `include` already provides for a handful of services.
- **Nx / Turborepo** — rejected; neither has a real polyrepo story.
- **Migrate the client to a monorepo** — the *preferred* answer whenever the
  split is not externally mandated, and it should be recommended out loud before
  this topology is adopted. Rejected as the general answer only because the
  mandate is often real and outside the team's control.

## Consequences

**Positive:**

- One product spine, one board, one architecture document; `/steer:status`,
  `/steer:next` and `/steer:audit` regain a whole-product view.
- `mise run dev` boots the entire product, closing the largest day-one gap for a
  developer joining a polyrepo client.
- Org-level rulesets and reusable workflows collapse the N× scaffold duplication
  into one enforcement point, which also fixes the N-plugin-versions drift.
- Members stay independently clonable, buildable and deployable — a member repo
  in isolation is unchanged and still valid.
- The cross-repo closing-keyword fix removes a live defect that today silently
  breaks issue lifecycle for anyone using the existing `repository:` field.

**Negative:**

- This is a **partial monorepo simulation**. It delivers monorepo-style coupled
  development without atomic cross-repo commits: a frontend/backend contract
  change is still two PRs that can merge out of order. The workspace makes that
  visible; it cannot make it atomic.
- The manifest is a new artifact that can rot, and the workspace repo is one more
  thing to keep in sync.
- Dependence on mise's experimental monorepo mode accepts upstream churn risk.
- Meaningful surface area: a new profile, a new template, a new trait, two rule
  paragraphs, and changes across `/steer:setup`, `/steer:init`, `/steer:adopt`,
  `/steer:next`, `/steer:status`, `/steer:audit`, `/steer:work`, `/steer:protect`
  and `/steer:roadmap`.

**Neutral:**

- Monorepo users are unaffected: absent markers mean `monorepo`, the trait gates
  the polyrepo rule text to zero always-on bytes, and no existing repo changes.
- Compose `include` and mise monorepo mode are upstream features, so the plugin
  ships configuration rather than machinery.

## Open questions

- **Q-001** — Does the workspace repo hold `spec/features/**` for *every* feature,
  or do repo-local contracts stay in the member that implements them? Owner:
  development.
- **Q-002** — Does `/steer:sync` gain a workspace mode that syncs all members in
  one pass, or does each member sync independently? Owner: development.
- **Q-003** — Should cross-repo reads for `/steer:next` and `/steer:audit` go
  through the GitHub MCP server (no local clone required) or assume the workspace
  checkout is materialized? Owner: development.
- **Q-004** — Does GitHub's sub-issue API support a cross-repository parent? This
  determines whether `/steer:issues` decomposition works across members
  unmodified. Owner: development.
