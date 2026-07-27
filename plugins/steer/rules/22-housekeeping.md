<!-- steer:inject-when=code-project -->
## Keep the repo tidy

The repo **root** holds scaffolding and config only — the known dirs (`apps/`,
`packages/`, `configs/`, `infra/`, `scripts/`, `spec/`) plus root config files
(`package.json`, `compose.yaml`, `mise.toml`, lockfiles, dotfiles,
`CLAUDE.md`, `README.md`, `ARCHITECTURE.md`, `DESIGN.md`).

Loose **source/research materials** — spreadsheets, inventories, vendor
metadata, schema/DDL dumps, discovery docs, and **specification /
requirements documents** (a `.pdf`, `.docx`, or deck spec, brief, RFP/SOW) —
never sit at the root: their home is `/spec/reference/`; architecture and
flow diagrams go to `/spec/design/`. A spec *document* is source material
feeding the spine, not the structured spec itself.

A stray root file you can **confidently classify** into one of those homes →
**move it there immediately** (keep its filename; `git mv` for tracked files
so history follows) — don't wait for a yes. Hold for confirmation only where
judgment or loss is at stake:

- **Renaming** a cryptic name — **propose** it; move the file now under its
  existing name and offer the rename separately.
- **Ambiguous** files (unclassifiable at a glance, or `Copy of …` look-alike
  pairs where picking wrong loses work) — **ask**, never guess.
- **Deleting** — never automatic. Only true junk (`desktop.ini`,
  `.DS_Store`), only on confirmation, plus a `.gitignore` pattern so it can't
  return.
- **Polyrepo member** (`spec/PRODUCT.md` present): `spec/reference/`,
  `spec/sources/`, `spec/features/` and `spec/app/` are the **workspace's** —
  never create one locally for a stray; report it and name the workspace as its
  home. `spec/design/`, `spec/decisions/` are the member's own — handle normally.

Run **`/steer:tidy`** for a full sweep.
