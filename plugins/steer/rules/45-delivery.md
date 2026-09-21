<!-- steer:inject-when=code-project -->
## Commit autonomy

Commits are cheap and local - the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Never pause work to ask
"should I commit / push / open the PR?".

Delivery runs in exactly **two modes**, keyed to the product `CLAUDE.md`
`## Delivery mode` marker (`<!-- steer:delivery-mode=solo-trunk -->` -> solo
trunk; anything else, absent included -> pr-flow). Branch protection *enforces*
pr-flow rather than defining it, and `/steer:protect` moves a repo between them.

- **PR flow (the default).** Work on a branch off `main` - never commit or push
  to `main` directly. Use the repo's convention, else `feat/*` / `fix/*`
  (`/steer:work` defaults to `issue/<number>-<slug>`); on `main` with changes,
  branch first, then commit. When the work is **complete**, **push the branch
  and open the PR without asking**. **Merging the PR is the one step that waits
  for the dev; everything before it does not.**
- **Solo trunk mode (declared, pre-MVP).** Commit **directly to `main` and push
  without asking**. CI still runs; the spine, tests and Definition of Done are
  **unchanged**, and the issue is still closed from the trunk commit where
  Issue-first requires one. **Graduate via `/steer:protect`** the moment the MVP
  works, you first deploy, or a second contributor joins; until then a local
  graduation signal makes the session's first trunk push wait for a human yes,
  unless the dev recorded a waiver (`/steer:reference gates`).
- **Declared-but-unprotected PR flow is a gap, not a mode**: the flow above
  applies unchanged, but say the wall is missing and recommend `/steer:protect`
  (an ADR where protection is genuinely unavailable).
- **Commit without asking** whenever a coherent unit of work is done - tests
  pass, lint clean, builds. Keep commits small, with a **Conventional Commits**
  subject (`type(scope): summary`, imperative; `!` for a breaking change).
  Commit messages are **not** the changelog: a shipping change also adds a
  **fragment** (`mise run changelog:new`), and `CHANGELOG.md` is generated from
  those, never hand-edited.
- **After pushing, watch CI to conclusion and fix a red build before treating
  the work as complete** - don't hand the dev a running or red PR and stop.
  (**Merge and deploy stay human-gated in every mode** - never `gh pr merge`,
  never deploy, never push to a protected `prod` branch.)

### Deployment & environments

How code reaches users is **declared by the repo, not imposed here**:
`policy/delivery.yml` names its environments, what merging deploys, how
production is approved, whether review apps exist, and what it reports to a
human. Read it before saying anything about this repo's delivery; if it is
missing, ask and seed it. Deploy and release logic is a high-risk area - scope
pipeline changes with the dev and validate in non-prod where there is one.

**Follow the declared model**, never pushing directly to a protected branch
whatever the gate says, and remember that a gate declares *which* human step
applies, never that there is none. Three baselines hold in every model: the
environment is **observable** (an empty `observability` list is a flag to raise,
not a rule to break), every production deploy has a **known rollback** and
migrations are expand/contract, and secrets are **injected at deploy time**,
never baked into an image or a CI log. A repo that delivers differently edits
`policy/delivery.yml`; only a *weaker* gate than the seeded one needs an ADR.
Full shape and rationale: `/steer:reference conventions`.

### Parallel worktrees

Several agents may work one repo at once, each in its own worktree, so local
services must not collide with or outlive a sibling's. Run `mise trust` in a new
worktree before any `mise run ...` - it is path-based, so an untrusted worktree
fails on trust, not on the task. Start services only through `mise run ...` so
the per-worktree project name and port offset apply, never a bare `docker
compose up` or a hardcoded port. Clean up what you started (`mise run
docker:clean`); the lifecycle hooks are best-effort and Claude-Code-only.
Mechanics: `/steer:reference conventions`.
