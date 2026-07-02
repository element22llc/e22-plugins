# Architecture diagrams

The full-detail companion to the always-on living-docs rule (`32-living-docs`) and
the `spec/design/` layout. It explains how to give a repo an **easily-viewable global
architecture picture** without letting that picture drift from reality.

Loaded on demand via **`/steer:reference architecture-diagrams`**.

## Where the diagram lives, and why

`ARCHITECTURE.md` (repo root) is the engineer's system model, and it is deliberately
**narrative and tables only** — it *links to* the diagram, it does not embed one.
The canonical home for the diagram is:

```text
spec/design/architecture.md
```

Two reasons for a separate file rather than inlining Mermaid into `ARCHITECTURE.md`:

- **`ARCHITECTURE.md` stays prose.** Its value is the written system model — the
  tech stack, the apps/packages map, cross-cutting concerns. A large diagram buried
  in the middle fights that.
- **One canonical, renderable home.** `spec/design/architecture.md` renders on its
  own in GitHub's file view and in the docs site, and it is the single place the
  living-docs rule points at for "keep the diagram current."

`spec/design/` also holds disposable UI/UX design *exports* (Claude Design, Figma);
the architecture diagram is the opposite — a **living, maintained** artifact. See
`/steer:reference design-sources` for the export side.

## Diagram-as-code is the whole point

Both supported tiers are **text**, so the diagram is git-diffable, reviewable in a
PR, and authorable/updatable by Claude in the same change as the code. That rules out
GUI-first tools as the *source of truth*:

- **Mermaid** and **LikeC4** — text, diff-friendly, render where people look. Chosen.
- **Excalidraw / draw.io** — GUI whiteboards; their files are JSON/XML that neither a
  human nor Claude edits meaningfully in review. Fine for throwaway sketching, wrong
  for a living artifact.
- **ReactFlow** — a React *library for building* node-based editors, not a diagram
  format. Wrong altitude: you would be maintaining app code or hand-written node/edge
  JSON, not a diagram.
- **Structurizr** — a strong C4 tool, but rendering needs Structurizr Lite (Docker)
  or the paid cloud. Reasonable only if the org already lives in Structurizr;
  otherwise LikeC4 gives the same C4 model with far lighter, self-hosted rendering.

## Tier 1 — Mermaid (default, zero toolchain)

For most repos this is the whole feature. Hand-author two blocks in
`spec/design/architecture.md`; they render natively in GitHub and in the Zensical docs
site with **nothing to install**.

- **System context & containers** — a `flowchart` (or Mermaid's C4-style blocks)
  showing users, deployable containers (group them in `subgraph`s), datastores, and
  external systems. Keep it to what a reader can hold in their head.
- **Request → response flow** — a `sequenceDiagram` for the primary path through the
  layers (UI → server → services → data).

`flowchart` + `sequenceDiagram` are the safe, always-render choices; Mermaid's
dedicated `C4Context` is still experimental and lays out less reliably, so prefer a
plain `flowchart` with subgraphs for the container view unless you specifically want
C4 notation.

Keep the global view small. Push deeper, per-area diagrams into their own files under
`spec/design/` and link them from the bottom of `architecture.md` — don't grow one
unreadable mega-diagram.

## Tier 2 — LikeC4 (opt-in, when Mermaid stops scaling)

When a hand-drawn diagram can no longer stay consistent — many containers, several
views that must agree, elements that appear in more than one diagram — graduate to
**LikeC4**: a text DSL where you define the C4 *model once* and derive multiple views
(context → container → component) plus an interactive, navigable viewer.

It is **opt-in by adoption** — nothing is installed until a repo adds a model:

1. **Add a model** under `spec/design/architecture/` (e.g.
   `spec/design/architecture/model.likec4`). LikeC4 needs only Node, which the
   standard scaffold already pins — no new tool pin.
2. **Activate the render task.** The scaffold `mise.toml` ships an inert (commented)
   `diagrams:render` task. Uncomment it; it runs LikeC4 on demand via `pnpm dlx`
   (the same on-demand pattern as `convert:doc`), with no permanent dependency:

   ```toml
   [tasks."diagrams:render"]
   description = "Generate Mermaid + PNG from the LikeC4 model (spec/design/architecture/)"
   run = [
     "pnpm dlx likec4 gen mermaid spec/design/architecture --output spec/design",
     "pnpm dlx likec4 export png spec/design/architecture -o spec/design",
   ]
   ```

   (`gen mermaid` — alias `gen mmd` — emits Mermaid; `export` handles PNG/JPG, not
   SVG. Both take the model folder as a positional path.)

3. **Compose with Tier 1.** `likec4 gen mermaid` **emits Mermaid**, so the generated
   views can be folded straight into `spec/design/architecture.md` — the file
   `ARCHITECTURE.md` already links to. Nothing downstream changes; the diagram just
   gains a model behind it.

Optionally serve the interactive view locally (`pnpm dlx likec4 serve
spec/design/architecture`) or publish a static site (`likec4 build`) alongside the
docs site.

## Choosing a tier

- **Start on Tier 1.** A `flowchart` + `sequenceDiagram` is the 80% solution and
  costs nothing.
- **Move to Tier 2** only when the model — not the rendering — is what's getting hard
  to keep consistent. Many repos never need it.

## Drift discipline (single source of truth)

A diagram that lies is worse than none. The rule (`32-living-docs`): the same PR that
changes the stack, adds/removes/renames an app or package, or reshapes
cross-component data flow **updates the diagram too**.

- **Tier 1:** `spec/design/architecture.md` is hand-authored — edit the Mermaid
  directly in that PR.
- **Tier 2:** `spec/design/architecture.md` is **generated** from the `.likec4`
  model — treat it as a build artifact. Edit the model, re-run `mise run
  diagrams:render`, and commit both. Never hand-edit the generated Mermaid.

If you later want an automated render-vs-source gate (regenerate in CI and diff the
committed output, the way this plugin keeps its Copilot mirror in sync), model it on
the generate-and-compare validators — but the living-docs rule plus PR review is the
baseline discipline and is enough for most repos.
