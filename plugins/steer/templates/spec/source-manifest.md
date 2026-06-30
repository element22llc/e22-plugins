# Source document — [Source title]

> One PO-supplied document tracked across its successive versions. Instantiated by
> `/steer:intake` as `spec/sources/<source-id>/source.md`. The committed binary +
> its normalized extraction live under `versions/`; this file is the ledger that
> binds them to a stable identity and records what each version was absorbed into.
>
> Identity is the `Source ID` below — **not** the filename. A PO who renames the
> document still maps to the same source; the rename is recorded under Filenames.

- **Source ID:** [kebab-case slug, stable across versions — e.g. `q3-roadmap`]
- **Title:** [human title of the document]
- **Owner:** [@po-handle who supplies this document]
- **Origin:** [delivery channel — e.g. email, shared drive, chat]
- **Traceability link:** [URL a human can open; reference only — Claude cannot fetch authenticated links, mirroring design-sources]
- **Format:** [docx | pptx | xlsx | pdf | other]
- **Filenames seen:** [comma-separated history of filenames this document has arrived under]
- **Latest absorbed version:** [vNNNN-YYYY-MM-DD, or "none yet"]

## Versions

> Append-only, newest first. One row per received version. "Extraction" is `ok`
> when the converter produced text, or `none` (with a reason) when it did not.
> "Absorbed" flips to `yes` once the diff has been routed into the spine/tracker.

| Version | Received | Binary | Extraction | Absorbed | Refs |
|---|---|---|---|---|---|
| [vNNNN-YYYY-MM-DD] | [YYYY-MM-DD] | [versions/<v>/original.<ext>] | [ok \| none — reason] | [yes \| no] | [HISTORY entry · #issue · spec/features/<id>/] |

## Mapped features

> Which `spec/features/<id>/` this document feeds. Many-to-many: one document may
> drive several features, and one feature may draw from several documents. When two
> documents make conflicting claims about the same feature, `/steer:intake` raises a
> single Open question naming both — it never auto-picks a winner.

- [spec/features/<id>/ — what part of this document maps here]

## Notes

[Anything a human needs to know to read this source correctly — e.g. "section 4 is
aspirational, not committed", "the spreadsheet's pricing tab is the source of
truth for `billing`". Keep it short; durable decisions belong in the owning
feature's intent/contract, not here.]
