<!-- steer:inject-when=code-project -->
## Commit autonomy

Commits are cheap and local - the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Never pause work to ask
"should I commit / push / open the PR?".

Delivery runs in exactly **two modes**, keyed to what the repo **declares**: the
product `CLAUDE.md` `## Delivery mode` marker
(`<!-- steer:delivery-mode=solo-trunk -->` -> solo trunk; anything else, absent
included -> pr-flow). Branch protection *enforces* pr-flow rather than defining
it, and `/steer:protect` moves a repo between them. There is no third mode.

- **PR flow (the default).** Work on a branch off `main` - never commit or push
  to `main` directly. Use the repo's branch convention, else `feat/*` / `fix/*`
  (`/steer:work` defaults to `issue/<number>-<slug>`). On `main` with changes?
  Create the branch first, then commit. When the work is **complete**, **push
  the branch and open the PR without asking** - announce it, don't request
  permission. **Merging the PR is the one step that waits for the dev;
  everything before it does not.**
- **Solo trunk mode (declared, pre-MVP).** Commit **directly to `main` and push
  without asking** - no branch, no per-feature PR. CI still runs; the spine,
  tests and Definition of Done are **unchanged**, and on a GitHub-adopted repo
  the issue is still closed from the trunk commit (`Closes #N`) where
  Issue-first requires one. **Graduate via `/steer:protect`** the moment the MVP
  works, you first deploy, or a second contributor joins. Until then a local
  graduation signal makes the session's first trunk push wait for a human yes,
  unless the dev recorded a waiver - mechanics in `/steer:reference gates`.
- **Declared-but-unprotected PR flow is a gap, not a mode.** The flow above
  applies unchanged - you still never merge - but say the wall is missing and
  recommend `/steer:protect`; where protection is genuinely unavailable, record
  the exception in an ADR.
- **Commit without asking** whenever a coherent unit of work is done - tests
  pass, lint clean, builds. Keep commits small, with a
  **[Conventional Commits](https://www.conventionalcommits.org/)** subject:
  `type(scope): summary`, imperative mood; `!` or a `BREAKING CHANGE:` footer
  for a breaking change. Commit messages are **not** the release changelog: a
  shipping change also adds a **changelog fragment** (`mise run changelog:new`,
  one file under `.changes/unreleased/`), and `CHANGELOG.md` is generated from
  those - never edited by hand.
- **After pushing, watch CI to conclusion and fix a red build before treating
  the work as complete** - don't hand the dev a running or red PR and stop.
  (**Merge and deploy stay human-gated in every mode** - never `gh pr merge`,
  never deploy, never push to a protected `prod` branch.)

### Deployment & environments

How code reaches users is **declared by the repo, not imposed here**:
`policy/delivery.yml` names its environments, what merging deploys, how
production is approved (`production_gate`), whether review apps exist, and what
it reports to a human. Read it before saying anything about this repo's
delivery; if it is missing, ask and seed it from the bundled template. Deploy
and release logic is a high-risk area - scope pipeline changes with the dev, and
validate in non-prod where the declared model has one.

- **Follow the declared model**, and never push directly to a protected branch
  whatever the gate. `/steer:protect` applies the GitHub side of it.
- **Merge and deploy stay human, in every model.** A gate declares *which*
  human step applies, never that there is none.
- **Observable by default** - logs, metrics with alarms, error tracking, health
  checks, alerting a human sees, wiring recorded in `ARCHITECTURE.md`. An empty
  `observability` list is allowed: unobservable is a **flag to raise**, not a
  rule to break.
- **Rollback** - every production deploy has a known one (revert the promotion,
  redeploy the prior SHA); migrations are expand/contract so the previous
  version survives the deploy.
- **Secrets at rest** - injected at deploy/runtime, never baked into images or
  CI logs (Secrets handling).

A repo that delivers differently edits `policy/delivery.yml`; only a *weaker*
gate than the seeded one needs an ADR.

### Parallel worktrees

Several agents may work one repo at once, each in its own worktree, so local
services must not collide with or outlive a sibling's. Run `mise trust` in a new
worktree before any `mise run ...` (it is path-based, and an untrusted worktree
fails on trust, not on the task), and start services only through `mise run ...`
so the scaffold's per-worktree `COMPOSE_PROJECT_NAME` and host-port offset
apply - never a bare `docker compose up`, a pinned `container_name` or a
hardcoded port. Clean up what you started: `mise run docker:clean` on the way
out, since the lifecycle hooks are best-effort and fire on Claude Code only.
Isolation mechanics and the `STEER_WORKTREE_OFFSET` escape hatch:
`/steer:reference conventions`.
