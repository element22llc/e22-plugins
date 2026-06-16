# Design sources

How a feature's UI gets designed and built to a uniform standard — whether it
starts from a design export, a partial sketch, or nothing at all. The always-on
rules keep only a short summary; this is the full walkthrough, loaded on demand
via `/steer:design-sources`.

**Set expectations first: most features have no design export, or only a partial
one.** A committed export is a useful input when it exists, but its absence is
the normal case, not a blocker — see "Building UI without a (full) export" below.
The constant across every path is the product's **`DESIGN.md`**, which keeps the
UI uniform feature to feature regardless of where any one screen came from.

When a feature *does* originate from a **Claude Design** exploration by the PO,
there are two distinct artifacts and they are not interchangeable:

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
  build with types, a bundler, and tests — Next is the path of least resistance
  to that, not the point in itself.
- **Deviation — keep the prototype's runtime → ADR with a kill date and a named
  trigger.** Legitimate only for genuine throwaways (a demo, a spike, a pitch with
  a known death, or an explicitly time-boxed pre-production stage). The ADR
  (`/steer:adr`) must state the lifespan and the condition that forces the port. Even
  then, runtime Babel + UMD should move to a real build (e.g. Vite + React + TS)
  before it is anyone's daily front-end.
- **Never** let "temporary" prototype hosting silently become the permanent
  front-end with no tracked trigger — that is the real failure mode.

The old "rewriting 250 KB of JSX is too expensive" objection assumed a human
re-typing it by hand. The port is now a mechanical agent task, and the original
prototype is the **pixel-diff oracle** to verify against — so the cost that used
to justify serving-as-is is much smaller than it looks.

## Building UI without a (full) export

This is the common path — a `/steer:build` idea with no mockup, a feature the PO
described in prose, or an export that covers one screen but not the five around
it. Do **not** fall back to generic, default-looking AI UI. Build deliberately:

- The marketplace re-lists Anthropic's **`frontend-design`** plugin alongside
  `steer` (`/plugin install frontend-design@e22-plugins`). Its skill
  activates automatically on frontend work and supplies the craft layer:
  intentional typography, a committed color system, motion, considered layout,
  and an explicit list of generic-AI anti-patterns to avoid (Inter/Roboto
  defaults, purple-on-white gradients, cookie-cutter sections).
- **Scope it deliberately.** `frontend-design` defaults to "pick the most extreme
  aesthetic." For a financial-services context, keep the *discipline*
  (intentional, cohesive, non-generic, accessible) but default to a
  professional/enterprise register unless the PO asks otherwise. Build in the
  standard stack — Next.js + TypeScript + Tailwind — not the plugin's example
  HTML/CSS. The cookbook it links
  (`prompting_for_frontend_aesthetics`) is the deeper reference.
- **A committed export still wins where it exists.** `frontend-design` fills the
  *gap* — it does not override a screen the PO actually designed. Realize the
  export for the screens it covers; design the rest deliberately around it so the
  whole flow reads as one product.
- **Capture as you go.** Every reusable decision you make while building —
  palette, type scale, spacing, component shapes, states — goes into `DESIGN.md`
  immediately (see below), so the next feature inherits it instead of
  re-deciding and drifting.

## DESIGN.md vs. intent.md

`DESIGN.md` (at the repo root, or `apps/<app>/DESIGN.md` for an app with a
distinct identity) holds reusable product-wide UI rules — layout, spacing,
typography, colors, components, forms, tables, navigation, empty/loading/error
states, accessibility, copy tone. Update it only when the design introduces a
reusable pattern. Feature-specific details stay in the feature's `intent.md`.

`DESIGN.md` has **three legitimate origins** — a design export is *not* a
prerequisite:

- **Distilled from a design export** (Greenfield / feature flow): the PO's
  Claude Design export, Figma, or screenshots are the source of the reusable
  patterns.
- **Reverse-engineered from the as-built UI** (Brownfield `/steer:adopt`): the
  running code *is* the source. `/steer:adopt` reads the Tailwind theme, CSS
  custom properties, fonts, the palette/spacing/radius scales in use, and
  recurring component styling, then writes `DESIGN.md` directly — no export
  needed.
- **Established while building without an export** (the common path, above):
  there is nothing to distill or reverse-engineer yet, so `DESIGN.md` *is* the
  record of the design decisions you make — seed it from the first feature's
  deliberate choices and grow it as patterns recur. This is what keeps an
  export-less product from drifting into five differently-styled screens.

Whatever the origin, the file follows the same format and the same "promote only
what recurs (3+ places)" rule. See the product's `DESIGN.md` for the format and
the validation command.

## Other design tools

Other design tools (Figma, screenshots, walkthrough docs) follow the same shape
— a traceability link plus a locally-readable artifact. Claude Design is the
most common source, not the only one.
