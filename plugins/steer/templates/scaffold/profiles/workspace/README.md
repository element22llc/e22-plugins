# [Product Name] — workspace

This repo is the **spine host** for a product that spans several repos. It holds
the product `/spec`, including the `spec/workspace.yml` member manifest. It holds
no application code.

Prefer a monorepo whenever the split is not externally mandated. This topology
buys a single product spine across repos; it does **not** buy atomic cross-repo
commits, and it never will — a contract change across two members is still two
PRs that can merge out of order.

## Layout

```text
spec/                THE product spine — vision, users, glossary, HISTORY,
                     app docs, and every feature's intent.md + contract.md
spec/workspace.yml   the member manifest (repos, branches, profiles, paths)
spec/tracker.md      the tracker for the whole product
compose.yaml         include: one entry per member that runs local services
scripts/ws.sh        the member driver behind the mise ws:* tasks
[member dirs]/       git-ignored clones — NOT submodules
```

Member repos carry `spec/PRODUCT.md` pointing back here, their own
`spec/decisions/` and `ARCHITECTURE.md`, and their code. They never grow a second
copy of a product-level artifact.

## Quickstart

```sh
mise run ws:clone     # clone every member declared in spec/workspace.yml
mise run ws:code      # generate the multi-root <product>.code-workspace
mise run ws:dev       # boot every member's backing services (see note below)
mise run ws:status    # per-member branch/dirty/spine version + manifest drift
mise run ws:sync      # fast-forward each member to its manifest branch
```

**Every task here is `ws:`-prefixed**, including `ws:dev` and
`ws:docker:up`/`down`/`clean`. That is deliberate: members are cloned *inside* this
workspace and mise loads every ancestor config, so this repo's `mise.toml` is also
loaded in every member. A task name a member does not define falls through to this
file — so an unprefixed `dev` here would make `mise run dev` in a member boot the
whole product, and an unprefixed `docker:clean` in a member with no compose file
would drop every member's volumes. Prefixing makes both unreachable. The mirror
image holds too: `ws:*` tasks work from inside a member, and always act on the
workspace (mise runs a task in its own config root), so `cd backend && mise run
ws:status` is a legitimate way to report on the whole product.

The members are ordinary clones at the `path:` each declares in the manifest, and
git-ignored here — no SHA pinning, so a member commit never dirties this repo, and
you branch and push from inside the member as usual. `ws:sync` is
fetch + fast-forward only: it refuses a dirty tree, a detached HEAD, a branch other
than the declared one, or a divergence. Rebasing a member is yours to do.

**The manifest is the source of truth.** `spec/workspace.yml` drives the clones,
the generated `.code-workspace`, the `compose.yaml` include list, the `.gitignore`
entries, and `[monorepo].config_roots` in `mise.toml`. `mise run ws:status`
reports where those have drifted apart — fix the derived file, not the manifest.

Two constraints worth knowing before the first `mise run ws:dev`: Compose `include:`
**warns and takes one side** on a service-name collision instead of merging, so
namespace service names inside each member; and every member's scaffold publishes
the same default host ports, so give each a distinct base port in its own `.env`.
Details: `/steer:reference polyrepo`.

## Working across the members

- `/steer:next`, `/steer:status`, `/steer:audit` run from here and cover the
  members they can reach — each report names which those are. A member with
  neither a local checkout nor gateway access is reported **uncovered**, never
  silently dropped.
- `/steer:issues` decomposition works across repos: GitHub sub-issues may span
  repositories within an org (100 sub-issues per parent, 8 levels of nesting).
- A PR in a member repo **cannot** auto-close an issue here — GitHub honours
  closing keywords only within one repo. Use `Refs owner/repo#N` and close the
  issue explicitly after merge.

## What this does not buy

**Atomic cross-repo commits.** `mise run ws:dev` brings the members' services up together and
`mise //backend:test` addresses them as one tree, but a contract change across two
members is still two PRs that can merge out of order. This topology makes that
visible; it cannot make it atomic. If you need atomicity, you need a monorepo.

**Merge-time cross-repo drift gates.** CI here cannot see member code without
credentials for each member repo, so cross-repo drift is an interactive
`/steer:audit` concern, not something a gate catches on merge.
