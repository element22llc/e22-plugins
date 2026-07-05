# Source documents (`spec/sources/`)

This is the **versioned home for PO-supplied documents** — the specs, roadmaps,
requirements decks, and spreadsheets a Product Owner hands over and keeps
re-sending with updates. It is maintained by `/steer:intake`.

Office documents are opaque binaries: git can't diff them and Claude can't read
them directly, so a re-sent file is otherwise a blob with no pointer to what
changed. `/steer:intake` fixes that by committing, for every version, **both** the
original binary **and** a normalized Markdown extraction — so a plain `git diff` of
successive extractions *is* the "what changed" the PO never spells out.

## Layout

```text
spec/sources/
  <source-id>/
    source.md                      # ledger: identity, versions, mapped features
    versions/
      v0001-2026-06-30/
        original.docx              # the committed binary — provenance, never edited
        extracted.md               # normalized Markdown — the diff surface
      v0002-2026-07-14/
        original.docx
        extracted.md
```

- **`<source-id>`** is a stable kebab-case slug for the *logical* document
  (`q3-roadmap`, `payments-spec`), **decoupled from the filename** — the PO can
  rename the file and it still maps to the same source.
- The binary is committed as provenance and **never edited**. The extraction is
  what gets diffed and read.
- The canonical "latest version" is the `Latest absorbed version` field in
  `source.md` (not a symlink — portable across checkouts).

## How it relates to the other source homes

| Home | Holds | Maintained by |
|---|---|---|
| `spec/sources/` | **Recurring, versioned** PO documents (this dir) | `/steer:intake` |
| `spec/design/` | UI/design exports (Claude Design ZIP, Figma, screenshots) | `/steer:spec`, `/steer:adopt` |
| `spec/reference/` | One-off source/research materials feeding the spec | `/steer:tidy` (filing), humans |

A document the PO sends **once** and never revises can stay loose under
`spec/reference/`; the moment it starts arriving in successive versions, it belongs
here so the changes between versions are visible. See
`/steer:reference design-sources` for the shared provenance model (a traceability
link plus a committed, Claude-readable extraction).
