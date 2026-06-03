# Design sources

How a design exploration becomes something Claude can actually read, and how to
reference it from a spec. The always-on rules keep only a short summary; this is
the full walkthrough, loaded on demand via `/e22-design-sources`.

Features in E22 products often originate from a **Claude Design** exploration by
the PO. There are two distinct artifacts and they are not interchangeable:

- **Claude Design URL** — traceability link only. Lets a human re-open the
  design in their browser. Claude **cannot** fetch it; the URL requires a
  signed-in session and returns `403 Forbidden` to automated tools.
- **Claude Design export (ZIP or extracted HTML)** — the actual extraction
  source. The PO clicks "Download zip" in Claude Design and commits the result
  to the repo so Claude can read it locally.

## Where each artifact lives

- **Greenfield (product-level):**
  - URL → `spec/design/source.md`
  - Export → `spec/design/claude-design/` (extracted HTML) or
    `spec/design/claude-design-export.zip`
- **Feature-level (Greenfield or Brownfield):**
  - URL → the originating GitHub issue, the PR description, and the
    `Design source` section of `/spec/features/[id]/intent.md`
  - Export → `/spec/features/[id]/design-export/` (extracted) or
    `/spec/features/[id]/design-export.zip`

If an export is ever committed loose at the repo root (or anywhere outside
`/spec`), move it under the right path above and update the referencing
`source.md` / `intent.md`. Exports belong under `/spec`, not loose in the tree.

## When you start work on a feature

1. Look for a **local export** first — that is what you can actually read. Check
   the Greenfield or Brownfield path above depending on the feature.
2. If no local export exists but a Claude Design URL is referenced, **do not try
   to fetch the URL**. Ask the PO or dev to run "Download zip" in Claude Design
   and commit the export.
3. Read only what is visible in the export: screens, flows, components, layout,
   labels and copy, forms and fields, visible states, navigation, user
   interactions.
4. Do not invent business rules, permissions, backend behavior, data models,
   validation rules, security requirements, or edge cases. Anything not visible
   in the export goes into `/spec/SPEC-QUESTIONS.md`.
5. When you write or update an `intent.md`, preserve both the URL (traceability)
   and the local export path (extraction source) in the `Design source`
   section. Do not drop either.
6. Treat the design as authoritative for **visual behavior and flow**, but defer
   to the spec for **what the system actually does**. If they conflict, flag the
   conflict in `/spec/SPEC-QUESTIONS.md` rather than silently picking one.

## DESIGN.md vs. intent.md

`DESIGN.md` (at the repo root, or `apps/<app>/DESIGN.md` for an app with a
distinct identity) holds reusable product-wide UI rules — layout, spacing,
typography, colors, components, forms, tables, navigation, empty/loading/error
states, accessibility, copy tone. Update it only when the design introduces a
reusable pattern. Feature-specific details stay in the feature's `intent.md`.

See the product's `DESIGN.md` for the format and the validation command.

## Other design tools

Other design tools (Figma, screenshots, walkthrough docs) follow the same shape
— a traceability link plus a locally-readable artifact. Claude Design is the
most common source, not the only one.
