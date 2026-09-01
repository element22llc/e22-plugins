---
paths:
  - "**"
---
<!-- steer:managed 24-worktrees v6.0.0 body-cksum:1309786579 — installed by /steer:init / /steer:adopt and reconciled by /steer:sync. Edit the rule in the steer plugin, not here: a local edit is detected and preserved, but it will not reach any other repo. -->

## Parallel worktrees — isolate runtime, clean up after

You may be one of several agents working the same repo at once, each in its own
worktree; your local services must not collide with — or outlive — a sibling's.
(A repo with no `compose.yaml`/ports has nothing to isolate; the cleanup
discipline still applies to anything you start.) Task names below are the core
scaffold's; a **workspace** repo prefixes its own `ws:` — see Useful commands.

**Trust a worktree before you run `mise` in it.** `mise trust` is path-based, so a
new worktree is untrusted and every `mise run …` there fails on *trust*, not on the
task. Run `mise trust` in the worktree first — it is idempotent, so it costs
nothing when a steer check already inherited the primary checkout's trust (Claude
Code only). That first decision is the user's, not yours: `mise trust && mise
install` if the repo was never trusted, `mise trust` if it has no `mise` config
at all — a first-time trust decision is not yours to make.

**Isolate runtime resources.** The scaffold handles this automatically: `mise`
sources `scripts/worktree-env.sh`, giving each worktree a unique
`COMPOSE_PROJECT_NAME` and a stable per-worktree host-port offset
(`POSTGRES_PORT`, `WEB_PORT`, `DATABASE_URL`; the primary checkout keeps the
defaults). So:

- Start services and the dev server through `mise run …` (`docker:up`,
  `dev:setup`, the app's dev task) so the per-worktree env applies — never a
  bare `docker compose up` or a hardcoded port.
- Don't pin a fixed `container_name` or a literal host port in `compose.yaml`,
  and don't hardcode `localhost:5432`/`localhost:3000` in app config — read
  the env vars.
- If two worktrees still draw the same offset, set
  `STEER_WORKTREE_OFFSET=<n>` for one of them rather than editing shared
  files.

**Clean up before the worktree closes.** On Claude Code, steer's `WorktreeRemove`
hook runs `docker:clean` on this worktree's stack — containers, **volumes** and
orphans, scoped to its `COMPOSE_PROJECT_NAME`, so its data goes with it. The
`SessionEnd` hook does the lesser `docker:down`: containers stopped, **volumes
kept**, and often cut short, so never count on it. Yours regardless: stop the dev servers and watchers
you launched, freeing their ports — and run `mise run docker:clean` yourself when
removing a worktree by hand or on any other surface, where no hook fires.
