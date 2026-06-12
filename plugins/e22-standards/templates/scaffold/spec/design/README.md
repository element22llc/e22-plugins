# Design source

A **readable home for a Greenfield product's design export** — the artifact
Claude reads to extract the spec — plus a traceability link back to where the
exploration happened. This is *not* a prototyping workspace: code exploration
happens on a branch under `/apps`, never here.

Feature-specific design exports live with their feature, at
`/spec/features/[id]/design-export/`. Use this folder for a **product-level**
export that isn't tied to a single feature (typically the initial Greenfield
exploration).

## Link, do not copy

Design explorations are disposable. Don't reconstruct the prototype's source
code here — copying it bloats the repo, creates two sources of truth, and tempts
devs to import it into `/apps` or `/packages` instead of reimplementing against
the spec. Link to the real artifact; the spec is what carries forward.

## What goes in `source.md`

`source.md` captures **two artifacts**:

1. **Traceability link** — where a human can re-open the design (e.g. a Claude
   Design URL). Claude cannot fetch authenticated URLs, so this is reference only.
2. **Extraction source** — a locally-committed artifact Claude can actually read.

Acceptable extraction sources:

- A **Claude Design ZIP/HTML export** committed at `spec/design/claude-design/`
  (extracted) or `spec/design/claude-design-export.zip`. Produced via the
  **Download zip** action in Claude Design.
- A separate prototype repo, ideally pinned to a commit hash if it matters
- A short screen-recording link
- Screenshots dropped in `spec/design/screenshots/`
- A written walkthrough by the PO

### Why both link and export?

Claude Design URLs (`https://claude.ai/design/...`) return `403 Forbidden` to
anonymous fetchers — they require a signed-in browser session. The URL is worth
keeping for human traceability, but it cannot be the thing Claude reads. The
committed export is.

## If an export was dropped in the wrong place

If a ZIP or export shows up at the repo root (or anywhere outside this folder),
move it under `spec/design/` and point `source.md` at it. The export should
always end up here, not loose in the tree.

## Lifecycle

1. **Greenfield start:** PO finishes exploration. Dev creates or updates
   `spec/design/source.md` pointing to it.
2. **Spec extraction:** Dev reads the export and talks with the PO, then writes
   specs in `/spec` and gets PO approval.
3. **Productionization:** Dev builds production code in `/apps` and `/packages`
   to satisfy the spec. The export is reference only — do not import from it.
4. **Archive:** Once the product ships, this folder can be removed from `main`
   (preserve it on a `design-archive` branch if you want the history).

## Brownfield

A purely Brownfield repo with no Greenfield exploration phase can delete this
folder. Per-feature design exports still live at
`/spec/features/[id]/design-export/`.
