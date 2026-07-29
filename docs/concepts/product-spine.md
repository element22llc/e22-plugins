# The product spine (`/spec`)

Every managed repo carries a **`/spec` spine** — the in-repo, version-controlled
source of product truth. Code is the implementation; `/spec` is the intent the
code is measured against. Skills read and write the spine; the issue tracker
references it.

## What lives in the spine

The spine is materialized from `plugins/steer/templates/spec/` and includes,
among others:

| Artifact | Role |
| --- | --- |
| `intent.md` (per feature) | The feature's purpose, acceptance criteria, tracker ref, and `## Open questions`. |
| `contract.md` | The feature's externally observable contract. |
| `vision.md`, `users.md`, `glossary.md` | Product-level framing shared across features. |
| `HISTORY.md` | Append-only log of what shipped, with tracker `Refs:`. |
| `tracker.md` | Declares the issue-tracking system and ref format. |
| `design/` | Design-export home: `README.md`, product-level `source.md` provenance (greenfield), and the living global `architecture-diagram.md` that the root `ARCHITECTURE.md` links to. |
| `sources/` | Versioned home for recurring PO source documents, maintained by [`/steer:intake`](../workflows/intake.md). |
| `reference/` | Catch-all home for durable **one-off** (non-versioned) source/research material feeding the spec — inventories, vendor metadata, schema/DDL dumps, discovery docs. Created on demand by [`/steer:tidy`](../workflows/index.md); a document sent once can stay here, but the moment it starts arriving in versions it belongs under `sources/`. |
| ADRs | Ratified, hard-to-reverse decisions (see [Decisions](../decisions/index.md)). |
| `.version` | Stamps the plugin version the spine was reconciled against. |

## Spec vs tracker vs ADR

These three layers are deliberately distinct:

- **`/spec`** is the durable *record* of product truth.
- The **issue** is the *workflow* — where a decision or unit of work is driven.
- An **ADR** is the durable record of a hard-to-reverse *decision*.

A question lives in a spec's `## Open questions` (as `Q-NNN`) and is additionally
**promoted to an issue** when it needs a named owner, blocks multiple features,
needs stakeholder input, or could outlive the session. Promotion does not move it
out of the spec: the `Q-NNN` block stays and gains a `tracker:` ref, the issue
carries the same id via `<!-- steer:question-id=Q-NNN -->`, and that pair is the
bidirectional link — `/steer:spec validate` flags a promoted question with no
`tracker:` ref back. A
blocking question still open after 14 days has, by definition, outlived the
session: the SessionStart hook escalates it, and promotion assigns it to its
`owner:` role via the `owners:` map in `tracker.md`. So questions get *pushed*
at a named human rather than rotting in markdown — without every question
becoming an issue.

!!! warning "Reverse-engineering never invents decisions"
    `/steer:adopt` builds a spine from existing code, but it must **never infer a
    ratified ADR from code**. ADRs record human decisions; an as-built spine
    captures what *is*, not a decision that was never made.

## Decisions land in the spine, not in side-channels

A durable design decision — the stack, an auth model, a data model, a locked MVP
scope — belongs in the spine: a feature's `intent.md`, a `contract.md`, or an
ADR. Conversation, chat summaries, and assistant memory are working notes, not
the record; a decision that survives only there leaves the repo with no trace of
it, and a teammate cloning the repo inherits nothing.

This has a sharp edge on a **brand-new repo with no spine yet**. The scoping
dialogue that shapes a product is expected — but bootstrap is the *first move*,
not a closing step: run [`/steer:init`](../workflows/index.md) (greenfield) or
[`/steer:adopt`](../workflows/adopt.md) (existing code) before persisting any
decision, so the scoping folds into the setup interview and each choice lands as
an ADR or `vision.md` entry, reviewable in the bootstrap PR. Capturing decisions
to memory or prose *instead of* a spine that doesn't exist yet is the
single-source-of-truth break the always-on `31-decision-capture` rule exists to
prevent.

The same logic applies to **everything a working session surfaces**, not just
formal decisions. Claude Code's private session memory survives compaction, but
it is invisible to the repo, the PR, and every teammate — so steer does not offer
to "remember" a finding there. The always-on `26-context-hygiene` rule routes
each fact to its canonical on-disk home **by type** instead: a **bug fix** → a
regression test; an **operational or behavioral fact** → the app guide or
`/spec/HISTORY.md`; an **unresolved bug or follow-up** → a
[linked tracker issue](../workflows/issues.md); a **durable design decision** →
the spine. Each fact lands in exactly one home, and that capture is surfaced as
part of the work rather than offered as an optional "want me to remember this?".

## One product, several repos

steer is repo-scoped by construction: one repo, one product, one spine. That is
the better arrangement, and a monorepo is the recommended answer whenever the
split is not **externally mandated** — separate deployment, ownership, or
compliance boundaries. "We already have three repos" is not a mandate.

When the split *is* mandated, the spine would otherwise fragment N ways: three
`vision.md`s drifting apart, and a feature spanning repos whose `intent.md` can
only live in one of them, leaving every sibling with nothing to load. So a
polyrepo product splits into two roles:

| | **workspace** | **member** |
| --- | --- | --- |
| Marker | `spec/workspace.yml` | `spec/PRODUCT.md` |
| Holds | THE product spine, including **all** of `spec/features/**` and `tracker.md` | code, tests, CI, its own ADRs and `ARCHITECTURE.md` |
| Code | none | all of it |

A member's spine is therefore **partial by design** — never "repaired" by adding
product-level files back, which would recreate the split. A missing local
`intent.md` means the workspace has not been read yet, so the skills resolve it
first: `workspace.path` when a checkout exists, else over the GitHub gateway,
else stop rather than guess. "A checkout exists" means `spec/workspace.yml` is
present at the resolved path, and a relative path resolves against the repo's
primary checkout — not against a linked worktree, where the recommended `..`
points at a real but empty directory.

Two consequences worth knowing before adopting the topology:

- **Reports must state their scope.** `/steer:next`, `/steer:status`,
  `/steer:audit`, `/steer:roadmap` and `/steer:protect` name the members they
  covered and flag any they could reach neither way as **uncovered** — a fraction
  of a product presented as the whole is worse than a smaller, honest answer.
  `/steer:protect` in particular names the sibling repos still unprotected, so a
  one-repo verdict never reads as product-wide.
- **Some things do not cross the repo edge.** Sub-issues and Projects v2 do;
  Milestones, closing keywords (`Closes #N`), and the merge-time drift gates do
  not. `/steer:roadmap` moves the release axis onto a Project field for that
  reason, and a member PR closes its workspace issue explicitly instead of
  relying on GitHub.

Members are cloned **inside** the workspace and git-ignored there — ordinary
clones, not submodules, so nothing pins a SHA and a member commit never dirties
the workspace. From the workspace, `mise run ws:clone` / `ws:sync` / `ws:status`
/ `ws:code` / `ws:list` manage them as a set. `mise run ws:dev` brings up the
product's backing services via Compose `include:` as soon as `compose.yaml` lists
the members' compose files; the *app* half — each member's own dev server — needs
mise monorepo mode enabled (uncomment the `[monorepo]` block in the workspace
`mise.toml`) plus one `depends` entry per member that has a `dev` task, so a fresh
workspace boots services only. Every task the workspace profile defines carries
that `ws:` prefix on purpose — `convert:doc` is the one deliberate exception,
unprefixed so `/steer:intake` keeps one vocabulary and safe because its `run`
command is identical to the core scaffold's. The reason is mise's config
hierarchy: it loads every *ancestor* config, so the workspace's `mise.toml` is
loaded inside each member too, and an unprefixed name there would shadow any member
that does not define it — an unprefixed `dev` made `mise run dev` in a member boot
the whole product instead of that member's server. Because those clones are git-ignored, a **worktree**
of the workspace has none of them: do spine work there, but run the product from
the primary checkout — `mise run ws:status`, and the `ws.sh` `check` and
`preflight` subcommands behind it, say so explicitly rather than reporting an
absent member as drift. What this never buys is **atomic cross-repo commits**: a contract
change across two members is still two PRs that can merge out of order. The
topology makes that visible; it cannot make it atomic.

!!! info "Full topology reference"
    `/steer:reference polyrepo` loads the complete treatment — artifact homes,
    spine resolution, the local runtime, and the constraints (Compose service-name
    collisions, host ports, org-ruleset licensing) — on demand. A single-repo
    product pays zero always-on bytes for any of it.

## How the spine stays current

- [`/steer:audit spec`](../workflows/index.md) compares the as-built spine against the
  tracker's intent (read-only).
- [`/steer:sync`](../workflows/index.md) reconciles the materialized spine and
  scaffold against the current plugin templates after a release.

Next: how work moves through the [lifecycle](lifecycle.md).
