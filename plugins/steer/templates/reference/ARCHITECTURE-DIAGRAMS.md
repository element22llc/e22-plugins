# Architecture diagrams

The full-detail companion to the always-on living-docs rule (`32-living-docs`) and
the `spec/design/` layout. It explains how to give a repo an **easily-viewable global
architecture picture** without letting that picture drift from reality.

Loaded on demand via **`/steer:reference architecture-diagrams`**.

This doc covers two **complementary** diagram-as-code artifacts, both living under
`spec/design/`:

- **The architecture picture** — the C4-altitude "how the pieces fit" view (apps,
  services, datastores, and the calls between them). Mermaid by default (Tier 1),
  graduating to a LikeC4 model (Tier 2) when it stops scaling. This is most repos'
  only diagram.
- **The infrastructure / network topology** — an *optional* literal view of the
  deployed network (VPCs, subnets, availability zones, load balancers, gateways) with
  cloud-vendor icons, authored in **D2**. Reach for it only when you need real
  topology fidelity — typically an `infra`/`service` repo, or a client asking for a
  visual of the deployment.

They are **siblings, not competing tiers**: LikeC4/Mermaid answer *what the system
is*; D2 answers *how it's wired in the cloud*. Most repos need only the first.

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

Every supported tool is **text**, so the diagram is git-diffable, reviewable in a
PR, and authorable/updatable by Claude in the same change as the code. That rules out
GUI-first tools as the *source of truth*:

- **Mermaid** and **LikeC4** — text, diff-friendly, render where people look. Chosen
  for the architecture picture.
- **D2** — also text and diff-friendly; it's the tool for the *separate* infra/network
  topology artifact (its own section below), not a competitor for the architecture
  picture's source of truth. Preferred there because Mermaid's `subgraph` nesting lays
  out poorly past a couple of levels and LikeC4 sits at the wrong (conceptual, not
  topological) altitude.
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

## Infrastructure / network topology (D2)

The tiers above draw the *architecture* — apps, services, datastores, how they call
each other. When you instead need the **literal deployed network** — VPCs, subnets,
availability zones, load balancers, NAT/gateways, security-group boundaries — with
recognisable cloud-vendor icons, that is a different picture at a different altitude,
and **D2** is the better-adapted tool. Typical triggers: an `infra` or `service`
repo with real topology, or a client asking for a visual of the deployment.

It is a **separate, optional artifact** — it does not replace `architecture.md`:

```text
spec/design/infrastructure.d2     # source (hand-authored, diff-reviewed)
spec/design/infrastructure.svg    # rendered output (generated; committed for sharing)
```

**No permanent tool pin — same opt-in as LikeC4.** D2's renderer is a Go binary (its
npm package `@terrastruct/d2` is a WASM *library*, not a CLI), but you don't pin it.
Nothing lands in `[tools]` because the task runs D2 on demand with `mise x` (exec)
rather than `mise use` (which writes the pin) — exactly the way `diagrams:render` uses
`pnpm dlx` and `convert:doc` uses `uvx`. `mise x` fetches the D2 binary (via its aqua
backend) the first time the task runs.

**Activate the render task.** The scaffold `mise.toml` ships an inert (commented)
`diagrams:infra` task next to `diagrams:render`. Uncomment it:

```toml
[tasks."diagrams:infra"]
description = "Render the D2 network/infra topology to SVG (spec/design/infrastructure.d2)"
run = "mise x d2@latest -- d2 --layout=elk spec/design/infrastructure.d2 spec/design/infrastructure.svg"
```

`--layout=elk` (bundled) handles dense, deeply-nested topology far better than the
default `dagre`. **SVG is the default and the right choice** — crisp at any zoom and the
one file you hand a client. PNG/PDF are possible (just change the output extension) but
pull in a headless browser (Playwright, auto-downloaded on first run), so add them only
if a client specifically needs a raster.

For repeat use you may instead **pin D2 in `/infra/mise.toml`** (where infra tooling
like OpenTofu/Terragrunt already lives) rather than the repo root — so only contributors
working under `/infra` install it. The `mise x` task above needs no pin at all and is
the right default.

**Author the `.d2` — nested containers are the whole point.** D2 nests with dot notation and
draws connections across containers, which maps directly onto network topology:

```d2
users: Users { shape: person }

aws: AWS Cloud {
  vpc: VPC 10.0.0.0/16 {
    alb: Application Load Balancer
    az_a: AZ us-east-1a {
      web: Web tier (ECS)
      db: Postgres (RDS) { shape: cylinder }
    }
  }
}

users -> aws.vpc.alb
aws.vpc.alb -> aws.vpc.az_a.web
aws.vpc.az_a.web -> aws.vpc.az_a.db
```

Cloud icons attach via the `icon:` attribute — either a URL or a **committed local
path** (`icon: ./icons/rds.svg`) if the render must work offline / air-gapped.
Terrastruct hosts an icon set at `icons.terrastruct.com`; verify the exact
per-provider icon URLs there.

## Choosing a tool

- **Start on Tier 1.** A `flowchart` + `sequenceDiagram` is the 80% solution and
  costs nothing.
- **Move to Tier 2** only when the model — not the rendering — is what's getting hard
  to keep consistent. Many repos never need it.
- **Add the D2 infra diagram** only when you need literal network topology (above).
  It's orthogonal to Tier 1/2 — an extra artifact for a different question, not a step
  past them — so don't reach for it unless the deployed topology is worth maintaining.

## Drift discipline (single source of truth)

A diagram that lies is worse than none. The rule (`32-living-docs`): the same PR that
changes the stack, adds/removes/renames an app or package, or reshapes
cross-component data flow **updates the diagram too**.

- **Tier 1:** `spec/design/architecture.md` is hand-authored — edit the Mermaid
  directly in that PR.
- **Tier 2:** `spec/design/architecture.md` is **generated** from the `.likec4`
  model — treat it as a build artifact. Edit the model, re-run `mise run
  diagrams:render`, and commit both. Never hand-edit the generated Mermaid.
- **D2 infra diagram:** `spec/design/infrastructure.d2` is the source;
  `infrastructure.svg` is **generated** — same rule. Edit the `.d2`, re-run `mise run
  diagrams:infra`, and commit both. Never hand-edit the SVG.

If you later want an automated render-vs-source gate (regenerate in CI and diff the
committed output, the way this plugin keeps its Copilot mirror in sync), model it on
the generate-and-compare validators — but the living-docs rule plus PR review is the
baseline discipline and is enough for most repos.
