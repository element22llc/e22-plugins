# Design source

> Replace this placeholder with links to the actual exploration artifacts.

## Traceability link

Where a human can re-open the design in their browser. A Design Artifact link (`claude.ai/artifact/...`) is readable with the `Artifact` tool in a session that has one; a standalone Claude Design URL (`claude.ai/design/...`) and other authenticated URLs return `403 Forbidden` to automated tools. Either way the link is **reference only** - the committed extraction below is the record.

- **Type:** [Design Artifact link | Claude Design URL | Figma | prototype repo | external link]
- **Link:** [paste URL - never a share key (`?sk=...`)]
- **Captured by:** [@po-handle]
- **Date:** YYYY-MM-DD

## Extraction source (what Claude actually reads)

A locally-committed artifact that Claude can open directly. For a Design Artifact, commit the canvas files Claude reads from the link; for standalone Claude Design, click **Download zip** in the design and commit the result here.

- **Type:** [Design Artifact canvas files | Claude Design ZIP/HTML export | screenshots | screen recording | walkthrough doc]
- **Path:** [e.g., `spec/design/claude-design/` or `spec/design/claude-design-export.zip`]
- **Captured by:** [@po-handle]
- **Date:** YYYY-MM-DD

## Design system

Optional - fill it only where a Design System Artifact holds this product's (or its brand's) identity. A product without one, or a team that does not use Claude Artifacts, leaves this section unfilled. Where one is recorded, `DESIGN.md` is distilled from it and stays the record the code builds against, complete on its own for anyone who cannot open the link (`/steer:reference design-sources`).

- **Link:** [Design System Artifact link without any share key, or "none"]
- **Upstream:** [the Design System | the code]
- **Last read:** [YYYY-MM-DD, or "not yet"]

## Supporting material

- [Optional: walkthrough video URL]
- [Optional: screenshots in `spec/design/screenshots/`]
- [Optional: notes from PO conversation]

## Status

- [ ] Extraction source committed and readable by Claude
- [ ] Design reviewed by dev
- [ ] Spec extracted into `/spec`
- [ ] PO approved spec
- [ ] Production implementation started
- [ ] Production deployed - this folder is ready to archive
