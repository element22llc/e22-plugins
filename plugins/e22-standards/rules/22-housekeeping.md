## Keep the repo tidy

The repo **root** holds scaffolding and config only — the known dirs (`apps/`,
`packages/`, `configs/`, `infra/`, `spec/`) plus root config files
(`package.json`, `compose.yaml`, `mise.toml`, `biome.json`, lockfiles, dotfiles,
`CLAUDE.md`, `README.md`, `DESIGN.md`).

Loose **source/research materials** — spreadsheets, inventories, vendor
metadata, schema/DDL dumps, discovery docs, PII/CMDB documents — do **not**
belong at the root. Their home is `/spec/reference/`; architecture and flow
diagrams go to `/spec/design/`.

When you notice stray non-code files sitting at the root, **propose** sorting
them into the right home — moving, and **renaming** cryptic or inconsistent
names to clear ones as you go. Don't silently act, and don't leave the mess. Run
**`/e22-tidy`** for a full sweep. A confusing or duplicate-looking name
(`Copy of …`, coded names) does not mean a file is disposable — **ask what it's
for** before deciding, never auto-delete, and only ever remove true junk
(`desktop.ini`, `.DS_Store`) on confirmation — adding its pattern to
`.gitignore` so it can't return.
