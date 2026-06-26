# Presentation — Claude Code & `steer`

A [Slidev](https://sli.dev) deck for a live working session, in two parts:

1. **For everyone (PO-friendly):** what Claude Code is (in Anthropic's own framing),
   when to reach for it vs Claude Cowork, and how you set how hands-on it is
   (the permission modes — Desktop mode selector / CLI Shift+Tab).
2. **For developers:** a crash course on the `steer` plugin — architecture, the
   `spec → issues → work → PR` loop, what the hooks actually enforce, and the
   skills cheat-sheet.

> This deck **ships nothing**. It is not part of the `steer` plugin, touches no
> `plugins/steer/` file, and needs **no CHANGELOG entry**. It builds to a static
> site for Cloudflare Pages.

## Toolchain — mise + pnpm

Like the steer scaffold, this uses **[mise](https://mise.jdx.dev)** for the
toolchain and **pnpm** (not npm) for packages. `mise.toml` exact-pins **node
`24.16.0`** and **pnpm `11.5.2`**; `mise.lock` records platform checksums for
reproducible installs. Workspace deps auto-install via **`[deps.pnpm] auto`**
(+ `experimental`) — so `pnpm install` runs automatically before any `mise run`
task and is a no-op once the lockfile is satisfied. Needs mise **≥ 2026.6.14**.

```bash
cd presentation
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

## Deploy to Cloudflare Pages

Connect this repo as a Cloudflare Pages project and set:

| Setting | Value |
|---|---|
| **Production branch** | your release branch (e.g. `main`) |
| **Build command** | `pnpm run build` |
| **Build output directory** | `dist` |
| **Root directory (advanced)** | `presentation` |
| **Environment variable** | `NODE_VERSION = 24` |

Cloudflare detects `pnpm-lock.yaml` and installs with pnpm before the build
command. SPA routing is handled by [`public/_redirects`](public/_redirects)
(`/* → /index.html 200`), so deep links to a specific slide (e.g. `/12`) and
refreshes resolve correctly. (`NODE_VERSION` is also read from
[`.node-version`](.node-version).)

**Deploying under a sub-path** (e.g. `example.com/talks/steer/`)? Build with a base:

```bash
pnpm exec slidev build --base /talks/steer/
```

(The base must begin and end with `/`.) For a root `*.pages.dev` deploy, leave it off.

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
