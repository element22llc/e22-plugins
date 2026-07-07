# Repo housekeeping

How to keep a product repo's root clean by sorting loose files into their
correct home under `/spec`. The always-on rule keeps only a short summary; this
is the full sweep procedure, loaded on demand via `/steer:tidy`.

Products are internal monorepos (see the layout rule). The **root** is for
scaffolding and config — not a dumping ground for the spreadsheets, decks,
diagrams, and documents that feed the spec. A PO building from the template
often commits a pile of source material at the root; this sweep **relocates,
renames, and (with confirmation) removes** it so the tree reflects what each
file actually is.

The three actions differ in how much they wait on you:

- **Move** — a clearly-named file you can confidently classify goes to its
  correct home **immediately**, under its existing name, no confirmation. The
  obvious strays just get sorted; you never block on a yes for a move that was
  never in doubt.
- **Rename + move** — a file whose name is cryptic, inconsistent, or misleading
  gets moved now under its current name, and a cleaner name is **proposed**
  separately (never renamed silently). A bad name is not a reason to bury or
  delete a file; it's a reason to rename it — with a yes.
- **Delete** — only true junk, and only after the user confirms. Never
  automatic.

Anything you **can't confidently classify** — an unfamiliar purpose, a
`Copy of …` / look-alike pair — is **not** auto-moved: ask first (see "Unclear
names" below). Confidence is the gate on the automatic move; absent it, you ask.

## Root allowlist — leave these in place

These belong at the root. Never propose moving them:

- **Known dirs:** `apps/`, `packages/`, `configs/`, `infra/`, `spec/`.
- **Root config:** `package.json`, `pnpm-workspace.yaml`, `pnpm-lock.yaml`,
  `biome.json`, `compose.yaml`, `mise.toml`, `mise.lock`, `tsconfig*.json`.
- **Root docs:** `CLAUDE.md`, `README.md`, `DESIGN.md`.
- **Dotfiles:** `.gitignore`, `.github/`, `.mise/`, etc.

**Never touch** `node_modules/`, `.git/`, or any lockfile — and never reach
*inside* the known dirs during a tidy; the sweep only sorts what is loose at the
root (the one exception is folding a stray top-level metadata folder, below).

## Destination taxonomy

Classify each loose root entry into one of these. When a file fits more than one
row or none, ask rather than guess (see "Unclear names" below).

| Material | Destination |
|---|---|
| Inventories, vendor/system metadata spreadsheets, discovery questions, PII asset lists, CMDB docs, SQL DDL / schema dumps | `/spec/reference/` |
| Specification / requirements documents — a `.pdf`, `.docx`, or deck spec, brief, RFP/SOW (source material feeding the spec, not the structured spec spine itself) | `/spec/reference/` |
| An existing top-level `Technical Metadata/` (or similarly-named source) folder | `/spec/reference/technical-metadata/` |
| Architecture diagrams, flow diagrams (`.svg`, "Flows for Review" `.pptx`) | `/spec/design/` |
| A Claude Design export (ZIP or extracted HTML) | `/spec/design/` — defer to `/steer:reference design-sources` for the exact path |
| Code / config that lives at root | leave in place (allowlist) |

`/spec/reference/` is the catch-all home for durable source material the spec is
built from. Group related files into subfolders by source system or topic when
that makes the pile easier to navigate (e.g. `technical-metadata/`,
`architecture/`).

**Already-absorbed sources are the exception — delete, don't move.** Before
routing a spec/requirements doc to `/spec/reference/`, check whether its bytes
match a committed `spec/sources/**/original.*` — a source `/steer:intake` has
already absorbed. If so, the stray at the drop location is a redundant duplicate:
its content is preserved in the committed source, so **propose deleting it** rather
than moving it (moving would just create a second copy of an already-absorbed
source). Like every delete, it waits for a yes. This is the counterpart to
`/steer:intake` relocating the file into `spec/sources/` when it absorbs a *new*
version — between the two, an absorbed document never stays stalled where it was
dropped.

## Renaming as you move

A clear filename is part of a tidy repo. When you move a file, propose a better
name if the current one is:

- **Cryptic or coded** — `OPCO PI Logical Elements 03_29_2021.xlsx`,
  `CIDRS_Data_Details-updated.xlsx`.
- **Prefixed with cruft** — `Copy of …`, `Final_v3_FINAL`, trailing `(002)`,
  `-updated`, dates that aren't meaningful.
- **Inconsistent** — spaces vs underscores, mixed case, against the convention
  the sibling files in that folder already follow.

Keep the file extension. Match whatever naming pattern the destination folder
already uses (if `/spec/reference/` holds `kebab-case.xlsx`, follow it; if it
holds source-system names, follow that). Propose the rename in the plan — never
rename silently, and don't drop information the name actually carries (a real
`as-of` date, a source system) just to make it shorter.

## Unclear names and purpose — ask, don't assume

A confusing or duplicate-looking name does **not** mean a file is disposable.
`Copy of ICA_cadata.xlsx` may be the authoritative cut, an edited variant, or a
true leftover — the name alone can't tell you, and deleting or misfiling it
loses real work.

For any file whose **purpose or correct home you can't determine from its name
and a quick look**:

1. **Ask the PO/dev what it is and how it's used** — what the file is for, which
   is the current version, whether a near-duplicate supersedes it.
2. Use the answer to decide the action: move it to the right folder, rename it to
   reflect its actual content/role, or (only if they confirm it's a leftover)
   delete it.
3. Never silently pick a winner between look-alike files, and never delete the
   odd-named one just because a "cleaner" sibling exists.

## Junk — flag, never auto-delete, and gitignore the pattern

Only **true junk** is a deletion candidate, and even then you ask first:

- **OS/junk:** `desktop.ini`, `.DS_Store`, `Thumbs.db`.

When you delete a junk file, **also add its pattern to `.gitignore`** so it
doesn't get re-committed and re-introduced later — deleting the file alone is
half the fix. Use a broad pattern, not the one path (`.DS_Store`, `Thumbs.db`,
`desktop.ini` — these match anywhere in the tree). Only add a pattern that isn't
already present, and keep them under a clearly-labelled section (e.g. a
`# OS junk` comment) so the additions are obvious in review.

Everything else that looks redundant — `Copy of …`, `(002)`, case- or
separator-variant pairs (e.g. `OpCo Architecture Recommendations.pptx` vs
`OpCo_Architecture_Recommendations.pptx`) — goes through the "ask, don't assume"
step above before any move/rename/delete. Surface which copy *looks* canonical,
but let the PO/dev confirm. Don't gitignore these — they're content decisions,
not recurring junk.

## Procedure

1. **List** the repo root (one level). Drop everything on the allowlist and the
   known dirs — what remains are the strays.
2. **Classify** each stray into the taxonomy table. Sort each into one of three
   buckets:
   - **Confident + clear name** → an automatic move.
   - **Confident + cryptic/inconsistent name** → an automatic move *plus* a
     proposed rename. Note the cleaner name.
   - **Can't confidently classify, or look-alike/duplicate** → a **questions**
     list; do not move yet.
3. **Auto-move the confident strays now**, before asking anything:
   - Tracked files: `git mv <src> <dest>` under their **existing** filename
     (history follows). Untracked files: plain `mv`.
   - Create destination folders (`/spec/reference/…`, `/spec/design/…`) as needed.
   - If a moved file is referenced by a spec (`source.md`, an `intent.md` `Design
     source` section), update the reference so the link still resolves.
4. **Ask** the PO/dev about the questions list — what each unclear or
   duplicate-looking file is for and which version is current — before moving it.
5. **Present a plan** for the gated work only: a table with an action column —
   `rename` (for files already auto-moved), `move` (for the now-answered
   ambiguous ones), or `delete` — showing source → destination/new name. Include
   junk and confirmed leftovers as `delete` rows. Do not rename or delete
   anything yet.
6. **On approval**, apply the gated actions:
   - Renames and answered moves: `git mv` (tracked) / `mv` (untracked); create
     folders as needed; fix any spec references.
   - Handle approved deletions only after the moves. For each deleted junk file,
     add its pattern to `.gitignore` (if not already there) so it can't return.
7. **Report** what was auto-moved, what renamed/moved/deleted on approval, and
   what you left in place or flagged ambiguous.
8. **Don't commit** until the user approves the result.
