<!-- steer:inject-when=code-project -->
## Useful commands

- **First-time setup:** `mise trust && mise install` (full mise setup in the
  product README), then `mise run dev:setup` — idempotent local env: services
  up → migrate → seed.
- **Develop:** `pnpm install && pnpm dev` (Node) / `uv sync && uv run <cmd>` (Python).
- **Test:** `pnpm test` (Vitest) / `uv run pytest`.
- **Deploy (devs only):** `pnpm deploy:nonprod` / `pnpm deploy:prod`.

The `pnpm`/`uv` lines above are the **app / service** profile. An **infra** repo
uses its own `mise` tasks instead (`mise run infra:fmt` / `infra:validate` /
`infra:plan`, or `tofu`/`terragrunt`/`ansible-playbook` directly) — see Stack —
infrastructure. The `mise trust && mise install` first step is universal.

Commands assume mise is activated in the shell; "tool not found" usually means
it isn't — run `/steer:doctor` to detect and install missing prerequisites, or
see the product README.
