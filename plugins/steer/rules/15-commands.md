## Useful commands

- **First-time setup:** `mise trust && mise install` (full mise setup in the
  product README), then `mise run dev:setup` — idempotent local env: services
  up → migrate → seed.
- **Develop:** `pnpm install && pnpm dev` (Node) / `uv sync && uv run <cmd>` (Python).
- **Test:** `pnpm test` (Vitest) / `uv run pytest`.
- **Deploy (devs only):** `pnpm deploy:nonprod` / `pnpm deploy:prod`.

Commands assume mise is activated in the shell; "tool not found" usually means
it isn't — see the product README.
