---
name: tidy
description: Sweep loose files out of the repo root into their correct home — source/research materials to /spec/reference, diagrams to /spec/design — moving, renaming, and (with confirmation) deleting. Proposes a plan first and never acts without a yes.
when_to_use: Use when the repo root is cluttered with spreadsheets, docs, diagrams, exports, or other non-code files, or the user asks to organize, clean up, or tidy the repo.
---

# Repo housekeeping (`/steer:tidy`)

Read the full sweep procedure bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/HOUSEKEEPING.md`

Key points (read the file for the full detail):

- The repo **root** holds scaffolding + config only. Everything on the **root
  allowlist** (and the known dirs `apps/ packages/ configs/ infra/ spec/`) stays
  put. **Never touch** `node_modules/`, `.git/`, or lockfiles.
- Loose **source/research materials** (spreadsheets, inventories, vendor
  metadata, schema/DDL dumps, discovery docs, PII/CMDB files) → `/spec/reference/`.
  An existing `Technical Metadata/`-style folder → `/spec/reference/technical-metadata/`.
- **Architecture/flow diagrams** (SVG, "Flows for Review" decks) → `/spec/design/`.
  A **Claude Design export** also → `/spec/design/` — defer to `/steer:design-sources`.
- Three actions, all proposed first: **move** (clear name), **rename + move**
  (cryptic/inconsistent name → a clear one in the right home), and **delete**
  (only true junk, only on confirmation). A bad filename is a reason to rename,
  not to bury or delete.
- **Ask before assuming.** A confusing or duplicate-looking name (`Copy of …`,
  coded names, `(002)`, case-variant pairs) does **not** mean a file is junk —
  it may be the important one. For anything you can't confidently classify or
  tell apart, **ask the PO/dev what the file is for and which version is
  current**, then move + rename (or, only if they confirm, delete).
- **Always propose before acting.** List root strays, classify them, ask about
  the unclear ones, then present a plan table with a `move` / `rename + move` /
  `delete` action column (source → destination/new name) for approval.
- Use **`git mv`** for tracked files (moves *and* renames; history follows);
  plain `mv` for untracked ones. Create destination folders as needed.
- **Never auto-delete.** Only true OS junk (`desktop.ini`, `.DS_Store`,
  `Thumbs.db`) is a deletion candidate, and even that waits for a yes. When you
  do delete junk, **also add its pattern to `.gitignore`** (broad, tree-wide,
  only if not already present) so it can't be re-committed later.
- If a moved/renamed file is referenced by a spec (`source.md`, an `intent.md`
  `Design source`), update the reference so the link still resolves.
