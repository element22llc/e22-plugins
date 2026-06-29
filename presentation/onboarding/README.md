# Onboarding deck — Claude Code & `steer`

The team-onboarding [Slidev](https://sli.dev) deck, in two parts:

1. **For everyone (PO-friendly):** what Claude Code is (in Anthropic's own framing),
   when to reach for it vs Claude Cowork, and how you set how hands-on it is
   (the permission modes — Desktop mode selector / CLI Shift+Tab).
2. **For developers:** a crash course on the `steer` plugin — architecture, the
   `spec → issues → work → PR` loop, what the hooks actually enforce, and the
   skills cheat-sheet.

> This deck **ships nothing**. It is not part of the `steer` plugin, touches no
> `plugins/steer/` file, and needs **no CHANGELOG entry**. It builds to a static
> site published with the docs on GitHub Pages.

Decks live under `presentation/<slug>/` (one self-contained deck per subfolder)
so the site can host more than one — this is the `onboarding` deck.

## Toolchain — mise + pnpm

Like the steer scaffold, this uses **[mise](https://mise.jdx.dev)** for the
toolchain and **pnpm** (not npm) for packages. `mise.toml` exact-pins **node
`24.16.0`** and **pnpm `11.5.2`**; `mise.lock` records platform checksums for
reproducible installs. Workspace deps auto-install via **`[deps.pnpm] auto`**
(+ `experimental`) — so `pnpm install` runs automatically before any `mise run`
task and is a no-op once the lockfile is satisfied. Needs mise **≥ 2026.6.14**.

```bash
cd presentation/onboarding
mise install        # node 24 + pnpm (first time only)
mise run dev        # installs deps, then serves http://localhost:3030 with live reload
```

Presenter view + speaker notes: press `p`, or open `/presenter`. Overview of all
slides: press `o`.

> Don't run `pnpm install` by hand — `[deps.pnpm] auto` does it for you. If you
> prefer raw pnpm anyway, `pnpm install && pnpm dev` works too.

## Edit it

Everything is one Markdown file: [`slides.md`](slides.md). Slides are separated by
`---`. Animations use Slidev directives:

- `<v-click>` / `<v-clicks>` — reveal elements step by step
- `v-mark` — highlight/circle inline
- ` ```mermaid ` — diagrams (the decision + core-loop flows)
- per-slide front-matter (`transition:`, `layout:`) between the `---` fences

Slidev docs: <https://sli.dev/guide/>

## Build (static site)

```bash
mise run build      # → dist/  (runs `pnpm exec slidev build`)
```

`dist/` is a self-contained static SPA.

### Export to PDF (optional, for handouts)

```bash
pnpm exec playwright install chromium   # one-time
mise run export                          # → slides-export.pdf
```

## Deploy (GitHub Pages, via the docs site)

The deck is published automatically as part of the documentation site. The
repo-root `.github/workflows/docs-deploy.yml` build job runs (after the Zensical
docs build):

```bash
pnpm exec slidev build --base /presentation/onboarding/ --out ../../site/presentation/onboarding
```

so the deck lands at `site/presentation/onboarding/` and is served at
**<https://ai.element-22.com/presentation/onboarding/>** alongside the docs (one
GitHub Pages artifact). The docs nav links to it ("Onboarding"). No separate
Cloudflare Pages project or manual deploy is needed.

The `--base` must match the serving sub-path and begin and end with `/`. For a
local preview at the root, run `mise run dev` (or `mise run build` with no
`--base`, output in `dist/`).

> **Routing — why hash mode.** The deck sets `routerMode: hash` in
> [`slides.md`](slides.md) headmatter, so slides are addressed as
> `/presentation/onboarding/#/2` and every navigation stays inside `index.html`.
> The default history mode would request `/presentation/onboarding/2`, a path
> with no static file — and GitHub Pages serves the **site-root** `404.html`
> (the docs 404) for any missing path, never `/presentation/onboarding/404.html`,
> so deep links and
> next-slide navigation would 404. Hash routing needs no SPA fallback at all and
> is the recommended mode for subdirectory static hosts.

> `public/_redirects` is a Cloudflare-Pages SPA-fallback file and is inert on
> GitHub Pages; with hash routing it is no longer needed for any host and is
> kept only as a harmless artifact — it can be removed.

## Pinned versions

Deps are exact-pinned in [`package.json`](package.json) for reproducible builds:
Slidev `52.16.0`, theme-seriph `0.25.0`, Vue `3.5.38`. Toolchain exact-pinned in
[`mise.toml`](mise.toml) / [`mise.lock`](mise.lock): node `24.16.0`, pnpm `11.5.2`.
Deps auto-install via the scaffold-native `[deps.pnpm] auto` (mise ≥ 2026.6.14).

[`pnpm-workspace.yaml`](pnpm-workspace.yaml) carries two pnpm-11 settings: it
approves `playwright-chromium`'s browser-download build script (used by the optional
`mise run export`), and it `overrides` the whole Vue family to `3.5.38` — `3.5.39`
was published the same day this was built and trips a `minimumReleaseAge`
supply-chain cooldown, so the older patch keeps installs clean and deterministic.
