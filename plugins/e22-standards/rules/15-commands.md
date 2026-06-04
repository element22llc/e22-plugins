## Useful commands

```bash
# First-time setup
mise trust && mise install     # see the product README for the full mise setup
mise run dev:setup             # local env in one command: Docker services up,
                               # migrations applied, dev data seeded (idempotent)

# Local development — pnpm (Node) / uv (Python) are the defaults
pnpm install && pnpm dev       # Node apps/packages
uv sync && uv run <cmd>        # Python apps/packages

# Testing
pnpm test                      # Vitest (Node) — or: uv run pytest (Python)

# Deploy — devs only
pnpm deploy:nonprod
pnpm deploy:prod
```

All commands assume mise is activated in your shell. If a tool is not found,
mise may not be activated — see the mise setup in the product README.
