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
   in the export goes into the feature's `intent.md` → `## Open questions`.
5. When you write or update an `intent.md`, preserve both the URL (traceability)
   and the local export path (extraction source) in the `Design source`
   section. Do not drop either.
6. Treat the design as authoritative for **visual behavior and flow**, but defer
   to the spec for **what the system actually does**. If they conflict, flag the
   conflict in the feature's `intent.md` → `## Open questions` rather than
   silently picking one.

## Realizing the design vs. serving the prototype

A Claude Design export (and most front-end design bundles) is **two things welded
together**, and only one of them is durable:

- **The design** — layout, components, design tokens (color/type/spacing), copy,
  states, flows. This is the valuable, long-lived artifact.
- **The delivery tech** — React over UMD `<script>` tags, Babel-standalone
  compiling JSX *in the browser at runtime*, a hand-rolled CSS file, no build, no
  types, no tests, no dependency management. This is disposable scaffolding,
  optimized for "open it in a browser instantly" — **not** for maintenance.

The export is a **spec to realize**, not code to ship. Decide by one question —
*is this surface going to be maintained?*

- **Default — maintained surface → realize the design in the standard stack.**
  Treat the export as spec + pixel reference (committed under `spec/design/`), and
  rebuild the UI in Next.js + TypeScript + Tailwind (per Stack). This is
  *following* the standard, so it needs **no ADR**. The bar that matters is a real
  build with types, a bundler, and tests — Next is E22's path of least resistance
  to that, not the point in itself.
- **Deviation — keep the prototype's runtime → ADR with a kill date and a named
  trigger.** Legitimate only for genuine throwaways (a demo, a spike, a pitch with
  a known death, or an explicitly time-boxed pre-production stage). The ADR
  (`/e22-adr`) must state the lifespan and the condition that forces the port. Even
  then, runtime Babel + UMD should move to a real build (e.g. Vite + React + TS)
  before it is anyone's daily front-end.
- **Never** let "temporary" prototype hosting silently become the permanent
  front-end with no tracked trigger — that is the real failure mode.

The old "rewriting 250 KB of JSX is too expensive" objection assumed a human
re-typing it by hand. The port is now a mechanical agent task, and the original
prototype is the **pixel-diff oracle** to verify against — so the cost that used
to justify serving-as-is is much smaller than it looks.

## DESIGN.md vs. intent.md

`DESIGN.md` (at the repo root, or `apps/<app>/DESIGN.md` for an app with a
distinct identity) holds reusable product-wide UI rules — layout, spacing,
typography, colors, components, forms, tables, navigation, empty/loading/error
states, accessibility, copy tone. Update it only when the design introduces a
reusable pattern. Feature-specific details stay in the feature's `intent.md`.

`DESIGN.md` has **two legitimate origins** — a design export is *not* a
prerequisite:

- **Distilled from a design export** (Greenfield / feature flow): the PO's
  Claude Design export, Figma, or screenshots are the source of the reusable
  patterns.
- **Reverse-engineered from the as-built UI** (Brownfield `/e22-adopt`): the
  running code *is* the source. `/e22-adopt` reads the Tailwind theme, CSS
  custom properties, fonts, the palette/spacing/radius scales in use, and
  recurring component styling, then writes `DESIGN.md` directly — no export
  needed.

Either way the file follows the same format and the same "promote only what
recurs (3+ places)" rule. See the product's `DESIGN.md` for the format and the
validation command.

## Other design tools

Other design tools (Figma, screenshots, walkthrough docs) follow the same shape
— a traceability link plus a locally-readable artifact. Claude Design is the
most common source, not the only one.
