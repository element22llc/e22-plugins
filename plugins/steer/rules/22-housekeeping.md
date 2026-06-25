<!-- steer:inject-when=code-project -->
## Keep the repo tidy

The repo **root** holds scaffolding and config only — the known dirs (`apps/`,
`packages/`, `configs/`, `infra/`, `spec/`) plus root config files
(`package.json`, `compose.yaml`, `mise.toml`, `biome.json`, lockfiles, dotfiles,
`CLAUDE.md`, `README.md`, `DESIGN.md`).

Loose **source/research materials** — spreadsheets, inventories, vendor
metadata, schema/DDL dumps, discovery docs, PII/CMDB documents, and
**specification / requirements documents** (a `.pdf`, `.docx`, or deck spec,
brief, RFP/SOW) — do **not** belong at the root. Their home is
`/spec/reference/`; architecture and flow diagrams go to `/spec/design/`. A spec
*document* is **source material** feeding the spec spine — not the structured
spec itself — so it belongs under `/spec/reference/`, never loose at the root.

When you notice a stray non-code file at the root that you can **confidently
classify** into one of those homes, **move it there immediately** (preserving
its filename) — don't wait for a yes. Use `git mv` for tracked files so history
follows. This is the default for the obvious cases; the mess never lingers and
you never block on a confirmation for a move that was never in doubt.

Hold for confirmation only where judgment or loss is at stake:

- **Renaming** a cryptic or inconsistent name to a cleaner one — **propose** it,
  never rename silently; move the file now under its existing name and offer the
  rename separately.
- **Ambiguous** files — a name or purpose you can't classify from a quick look,
  or `Copy of …` / look-alike pairs where picking wrong loses real work —
  **ask** what it's for before moving; never guess.
- **Deleting** — never auto-delete. Only true junk (`desktop.ini`, `.DS_Store`)
  is a candidate, only on confirmation, and add its pattern to `.gitignore` so
  it can't return.

Run **`/steer:tidy`** for a full sweep.
