<!-- steer:inject-when=code-project -->
## Parallel worktrees — isolate runtime, clean up after

You may be one of several agents working the same repo at once, each in its own
worktree; your local services must not collide with — or outlive — a sibling's.
(A repo with no `compose.yaml`/ports has nothing to isolate; the cleanup
discipline still applies to anything you start.)

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

**Clean up before the worktree closes.** Containers, volumes, and background
dev servers outlive the git worktree unless torn down:

- Run `mise run docker:clean` (down + volumes + orphans, scoped to this
  worktree's `COMPOSE_PROJECT_NAME` — it won't touch a sibling's stack).
- Stop any background dev server / watcher you launched, freeing its port.
- Leave no orphaned containers, volumes, processes, or held ports behind.
