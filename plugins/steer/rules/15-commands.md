<!-- steer:inject-when=code-project -->
## Useful commands

- **First-time setup:** `mise trust && mise install` (full mise setup in the
  product README), then `mise run dev:setup` — idempotent local env: services
  up → migrate → seed.
- **Develop:** `pnpm dev` (Node) / `uv run <cmd>` (Python) — with mise activated,
  bare `pnpm`/`uv` resolve to the **pinned** runtime. The scaffold's `[deps]`
  auto-install runs `pnpm install` / `uv sync` before any `mise run …` on lockfile
  change, so you almost never install deps by hand; if you must, route it through
  mise — `mise exec -- pnpm install` — so it can't pick up a global/nvm copy.
- **Test:** `pnpm test` (Vitest) / `uv run pytest`.
- **Deploy (devs only):** `pnpm deploy:nonprod` / `pnpm deploy:prod`.

The `pnpm`/`uv` lines above are the **app / service** profile. An **infra** repo
uses its own `mise` tasks instead (`mise run infra:fmt` / `infra:validate` /
`infra:plan`, or `tofu`/`terragrunt`/`ansible-playbook` directly) — see Stack —
infrastructure. The `mise trust && mise install` first step is universal.

Commands assume mise is activated in the shell, and that `mise activate` is
sourced **after** any other version manager (nvm/asdf/volta/fnm) in your rc file
— whichever loads last wins PATH, and mise must win or bare `pnpm`/`node` silently
run a global version instead of the pinned one. "tool not found" usually means
mise isn't activated; a *wrong/old* version usually means it's shadowed. Either
way run `/steer:doctor` (it flags a shadowed runtime and names the conflicting
manager), or see the product README.
