<!-- steer:inject-when=code-project -->
## Parallel worktrees — isolate runtime, clean up after

You may be one of several agents working the same repo at once, each in its own
worktree. Your local services must not collide with — or outlive — a sibling's.
(This matters for repos with local backing services — the **app / service**
profile. A **library**, **cli**, or **infra** repo with no `compose.yaml`/ports
has nothing to isolate; the cleanup discipline below still applies to anything
you start.)

**Isolate runtime resources.** Two worktrees that both bind host port 5432
(Postgres) or 3000 (dev server), or share a Docker container/volume name, will
break each other. The scaffold prevents this automatically: `mise` sources
`scripts/worktree-env.sh`, which gives each worktree a unique
`COMPOSE_PROJECT_NAME` and a stable per-worktree host-port offset
(`POSTGRES_PORT`, `WEB_PORT`, `DATABASE_URL` — primary checkout keeps the
defaults). So:

- Start services and the dev server through `mise run …` (`docker:up`,
  `dev:setup`, the app's dev task) so the per-worktree env applies — never with a
  bare `docker compose up` / hardcoded port that ignores it.
- Don't pin a fixed `container_name` or a literal host port in `compose.yaml`,
  and don't hardcode `localhost:5432`/`localhost:3000` in app config — read the
  env vars. Hardcoding defeats the isolation and reintroduces the clash.
- If two worktrees still draw the same offset (a host port is already in use),
  set `STEER_WORKTREE_OFFSET=<n>` for one of them rather than editing the
  shared files.

**Clean up before the worktree closes.** Containers, volumes, and background
dev servers you start outlive the git worktree unless you tear them down — the
worktree's removal does **not** stop them. Before closing or removing a
worktree:

- Run `mise run docker:clean` (down + volumes + orphans, scoped to this
  worktree's `COMPOSE_PROJECT_NAME`) — it won't touch a sibling's stack.
- Stop any background dev server / watcher you launched, freeing its port.
- Leave no orphaned containers, volumes, processes, or held ports behind.
