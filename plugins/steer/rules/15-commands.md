<!-- steer:inject-when=org-e22 -->
## Useful commands (e22 org pack)

- **First-time setup:** `mise trust && mise install` (full mise setup in the
  product README), then `mise run dev:setup` - idempotent local env: services
  up -> migrate -> seed.
- **Develop:** `pnpm dev` (Node) / `uv run <cmd>` (Python) - with mise activated,
  bare `pnpm`/`uv` resolve to the **pinned** runtime. The scaffold's `[deps]`
  auto-install runs `pnpm install` / `uv sync` before any `mise run ...` on lockfile
  change, so you almost never install deps by hand; if you must, route it through
  mise - `mise exec -- pnpm install` - so it can't pick up a global/nvm copy.
- **Test:** `pnpm test` (Vitest) / `uv run pytest`.
- **Deploy:** promotion via merge (`main` -> non-prod, `prod` PR -> prod) - see
  Deployment & environments; there is no `pnpm deploy` task.

The `pnpm`/`uv` lines are the **app / service** profile. An infra repo uses
`mise run infra:*` instead, and a workspace repo's tasks are all `ws:`-prefixed;
`mise trust && mise install` is universal, and `mise tasks` lists what a repo
really has.

Commands assume mise is activated and **wins PATH** over any other version
manager - otherwise a bare `pnpm` or `node` silently runs a global version.
"Tool not found" means mise is not activated; a *wrong* version means it is
shadowed. Either way, run **`/steer:setup doctor`**.
