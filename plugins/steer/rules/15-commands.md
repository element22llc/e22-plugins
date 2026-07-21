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
- **Deploy:** promotion via merge (`main` → non-prod, `prod` PR → prod) — see
  Deployment & environments; there is no `pnpm deploy` task.

The `pnpm`/`uv` lines above are the **app / service** profile. An **infra** repo
uses its own `mise` tasks instead (`mise run infra:fmt` / `infra:validate` /
`infra:plan`, or `tofu`/`terragrunt`/`ansible-playbook` directly) — see Stack —
infrastructure. The `mise trust && mise install` first step is universal.

Commands assume mise is activated and **wins PATH** over any other version
manager (nvm/asdf/volta/fnm) — otherwise bare `pnpm`/`node` silently run a
global version. "tool not found" → mise not activated; *wrong/old* version →
shadowed. Either way run `/steer:doctor`; activation-order rationale:
`/steer:reference conventions`.
