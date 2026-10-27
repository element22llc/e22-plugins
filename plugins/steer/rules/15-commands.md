<!-- steer:inject-when=org-e22 -->
## Useful commands (e22 org pack)

- **First-time setup:** `mise trust && mise install`, then `mise run dev:setup`.
- **Develop / test:** `pnpm dev`, `pnpm test` (Node) / `uv run <cmd>`, `uv run
  pytest` (Python). Dependencies install on the next `mise run` after a lockfile
  change; by hand, `mise exec -- pnpm install`, never a global copy.
- **Deploy:** whatever `policy/delivery.yml` declares; there is no `pnpm
  deploy` task.

Those lines are the app profile: an infra repo uses `mise run infra:*`, a
workspace repo's tasks are all `ws:`-prefixed, and `mise tasks` lists what a
repo really has. Commands assume mise is activated and **wins PATH**; a missing
tool or a wrong version means run **`/steer:setup doctor`**.
