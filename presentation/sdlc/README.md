# SDLC deck — building software with `steer`

The client-facing [Slidev](https://sli.dev) deck: how software gets built on the
steer standards. One narrative, two depths — every slide leads with the
plain-language point for non-technical stakeholders, with the machinery
(artifacts, gates, hooks) in the cards and fine print for developers:

1. The problem: AI-assisted development is fast but chaos-prone without records.
2. The invariant: spec = product truth, tracker = work layer, human review = the gate.
3. The six-phase lifecycle (Shape → Plan → Build → Verify → Deliver → Maintain).
4. Traceability, the human authority gates, and what clients/devs each gain.
5. Cross-surface: the same standards in Claude Code **and** GitHub Copilot.
6. A concrete end-to-end example ("add CSV export") and the three entry doors.

> This deck **ships nothing**. It is not part of the `steer` plugin, touches no
> `plugins/steer/` file, and needs **no CHANGELOG entry**. It builds to a static
> site published with the docs on GitHub Pages.

Decks live under `presentation/<slug>/` (one self-contained deck per subfolder)
so the site can host more than one — this is the `sdlc` deck; the team-internal
crash course is the sibling [`onboarding`](../onboarding/) deck.

## Toolchain — mise + pnpm

Same setup as the onboarding deck (see its
[README](../onboarding/README.md#toolchain--mise--pnpm) for the full rationale):
**mise** exact-pins node `24.16.0` + pnpm `11.5.2` (`mise.toml` / `mise.lock`),
and workspace deps auto-install via `[deps.pnpm] auto` — don't run
`pnpm install` by hand. Needs mise **≥ 2026.6.14**.

```bash
cd presentation/sdlc
mise install        # node 24 + pnpm (first time only)
mise run dev        # installs deps, then serves http://localhost:3030 with live reload
```

Presenter view + speaker notes: press `p`, or open `/presenter`. Overview of all
slides: press `o`.

## Edit it

Everything is one Markdown file: [`slides.md`](slides.md). Slides are separated
by `---`; animations use `<v-click>` / `<v-clicks>`, diagrams are ` ```mermaid `
fences, per-slide front-matter sits between the `---` fences. Slidev docs:
<https://sli.dev/guide/>

**Grounding:** the content is sourced from the docs site's concept pages
(`docs/concepts/sdlc.md`, `product-spine.md`, `copilot-support.md`) and
`plugins/steer/templates/reference/TRACEABILITY.md`. If the lifecycle, gates, or
Copilot parity story changes there, re-check the corresponding slides. Two
wording rules the deck deliberately follows: compliance claims say **"aligned
with SOC 2 / ISO 27001 expectations"** (never "compliant"), and merge/deploy
are always described as **human decisions**.

## Build (static site)

```bash
mise run build      # → dist/  (runs `pnpm exec slidev build`)
```

### Export to PDF (optional, for handouts)

```bash
pnpm exec playwright install chromium   # one-time
mise run export                          # → slides-export.pdf
```

## Deploy (GitHub Pages, via the docs site)

Published automatically as part of the documentation site. The repo-root
`.github/workflows/docs-deploy.yml` build job runs (after the Zensical docs
build):

```bash
pnpm exec slidev build --base /presentation/sdlc/ --out ../../site/presentation/sdlc
```

so the deck lands at `site/presentation/sdlc/` and is served at
**<https://ai.element-22.com/presentation/sdlc/>** alongside the docs (one
GitHub Pages artifact). The docs nav links to it ("SDLC deck"). The `--base`
must match the serving sub-path and begin and end with `/`.

> **Routing — hash mode + the `vite.config.ts` patch.** Identical to the
> onboarding deck: `routerMode: hash` in the headmatter (GitHub Pages has no
> nested SPA fallback, so history mode would 404 on deep links), plus the
> build-time transform in [`vite.config.ts`](vite.config.ts) that fixes Slidev
> 52.16.0's double-prepended base in hash-mode slide navigation. See the
> onboarding [README](../onboarding/README.md#deploy-github-pages-via-the-docs-site)
> for the full explanation; remove the patch if upstream makes `getSlidePath`
> hash-aware.

## Pinned versions

Deps are exact-pinned in [`package.json`](package.json) for reproducible builds:
Slidev `52.16.0`, theme-seriph `0.25.0`, Vue `3.5.38`. Toolchain exact-pinned in
[`mise.toml`](mise.toml) / [`mise.lock`](mise.lock): node `24.16.0`, pnpm
`11.5.2`. [`pnpm-workspace.yaml`](pnpm-workspace.yaml) approves
`playwright-chromium`'s browser download (for the optional export) and pins the
Vue family via `overrides` — all mirrored from the onboarding deck.
