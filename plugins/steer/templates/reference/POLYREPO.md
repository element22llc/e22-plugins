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

- `vision.md`, `users.md`, `glossary.md`, `HISTORY.md`, `spec/app/`
- `spec/tracker.md` — the tracker for the whole product
- **all** of `spec/features/**` — every `intent.md` and `contract.md`

**In each member:**

- `spec/PRODUCT.md` — the pointer, and the thing that makes the repo a member
- `spec/decisions/` — ADRs about *this repo's* internals
- `ARCHITECTURE.md` — how *this repo* is built
- the code

Feature specs live in the workspace because that is the whole point. Rule
`20-layout` already lets a feature span apps and packages; in a polyrepo it spans
*repos*, and an `intent.md` can only live in one of them. Put it above the repos
and a cross-repo feature has exactly one intent. Put it in a member and every
sibling working that feature has no intent to load — which is the split-brain
this topology exists to prevent.

A member's spine is therefore **partial by design**, and the tooling knows it:
`steer_spine_state` requires only `PRODUCT.md` when the pointer is present, so a
member reports `managed` rather than `damaged`. Do not "fix" a member by adding
product-level files — that recreates the fragmentation.

## Resolving the spine from a member

1. `workspace.path` in `spec/PRODUCT.md` is set and the directory exists → read
   the spine from there.
2. Otherwise → read `workspace.repository` at `workspace.branch` over the GitHub
   gateway (`/steer:tracker-sync`). No local clone required.
3. Neither → say the spine is unreachable and **stop**. Do not proceed on a guess
   and do not create local product-level files to fill the gap.

Absent local intent is never "no intent". It means the workspace has not been
read yet.

## Reporting across members

`/steer:next`, `/steer:status`, `/steer:audit` and `/steer:roadmap` walk one tree
by default. In a polyrepo that would hand a client a fraction of the product with
no indication it was a fraction — worse than a smaller, honest answer.

Every such report must:

- name the members it covered and how (local checkout / gateway), and
- name any member it could reach **neither** way as **uncovered** — explicitly,
  never by omission.

`spec/workspace.yml` → `reporting.require_all_members: true` makes the uncovered
case loud rather than silent. Silence must never read as "nothing there".

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
affected sibling** in the PR description. The workspace `ARCHITECTURE.md` — not
any member's — is where the system-level model belongs.

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

## Not in scope here

Running the whole product locally — mise `monorepo_root` task addressing, Compose
`include:` to boot every member with one command, a generated `.code-workspace` —
is deliberately absent. It is generic multi-repo devx rather than spine
management, and it carries upstream churn this reference does not want to inherit
(mise's monorepo discovery is migrating to explicit `[monorepo].config_roots`,
and `[monorepo].lockfile` changes default in a future release). Clone the members
wherever you like and run them as they stand.
