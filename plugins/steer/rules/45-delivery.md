<!-- steer:inject-when=code-project -->
## Commit autonomy

Commits are cheap and local - the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Never pause work to ask
"should I commit / push / open the PR?". This deliberately overrides a surface's
default to commit, push or open a PR only when asked (CLI, web, GitHub Action).

Delivery has **two modes**, keyed to the product `CLAUDE.md` marker
`<!-- steer:delivery-mode=solo-trunk -->` (absent -> pr-flow);
`/steer:setup protect` moves a repo between them.

- **PR flow (the default).** Branch off the default branch - never commit or
  push to `main` - by the repo's convention, else `feat/*` / `fix/*`
  (`/steer:work`: `issue/<number>-<slug>`). When the work is **complete**,
  **push the branch and open the PR without asking**. **Merging the PR is the
  one step that waits for the dev; everything before it does not.** Stack on
  another work branch only for its unmerged code, saying why in the PR; land
  many fixes as one merge through sibling PRs into a `batch/<slug>` branch. An
  unprotected `main` is a gap, not a mode: recommend `/steer:setup protect`
  (an ADR where protection is unavailable).
- **Solo trunk (declared, pre-MVP).** Commit **directly to `main` and push
  without asking**; spine, tests and Definition of Done are unchanged.
  **Graduate via `/steer:setup protect`** once the MVP works, you deploy, or a
  second contributor joins (`/steer:reference gates`).
- **Commit without asking** whenever a coherent unit of work is done - tests
  pass, lint clean, builds. Small commits, **Conventional Commits** subjects
  (`type(scope): summary`, `!` for breaking). A shipping change adds a changelog
  **fragment** (`mise run changelog:new`); `CHANGELOG.md` is generated, never
  hand-edited.
- **Get the local gates green before you push**: CI confirms, it is not the
  loop you iterate in. `/steer:work` opens its PR as a **draft** (a hotfix's
  opens ready); its author marks it ready, and CI runs then. Watch every run that follows - a ready PR's, a trunk push's -
  to conclusion and fix a red build before the work counts as complete. **Merge and deploy stay human-gated in every mode** -
  never `gh pr merge`, never deploy, never push to a protected `prod` branch.

### Deployment & environments

`policy/delivery.yml` declares how this repo delivers - environments, what
merging deploys, the production gate, review apps. Read it before saying
anything about delivery; if it is missing, ask and seed it. A gate names
*which* human step applies, never that there is none, and only a gate weaker
than the seeded one needs an ADR. In every model the environment is
**observable**, each production deploy has a **known rollback** with
expand/contract migrations, and secrets are **injected at deploy time**, never
baked into an image or a CI log. Detail: `/steer:reference conventions`.

### Parallel worktrees

Sibling agents may share this repo through worktrees. Start services only via
`mise run ...`, never a bare `docker compose up` or a hardcoded port, and clean
up with `mise run docker:clean`. A new worktree takes `mise trust` only when the
primary checkout is trusted; never create trust - ask the human. Worktrees
another tool manages (Orca, Conductor) need `/steer:setup worktrees`.
Mechanics: `/steer:reference conventions`.
