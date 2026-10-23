# Walkthrough recording templates

**On-demand, not bootstrap-installed.** Starting points for a captioned
walkthrough video of a running app, instantiated by `/steer:work walkthrough
<feature>` the first time a feature needs one and then owned by the product.
Nothing here is copied at `/steer:init` time.

## Pick by stack

| Template | Stack | Lands at |
|---|---|---|
| `walkthrough.ts` | Node / Next.js (the default) | `scripts/demo/<feature>_walkthrough.ts` |
| `walkthrough.py` | Python | `scripts/demo/<feature>_walkthrough.py` |

Both carry the same overlay (title and closing cards, a caption bar, highlight
rings), off-camera sign-in through saved storage state, one clip per persona and
an ffmpeg join to H.264 MP4. Replace every `<...>` placeholder and the sample
`scenes`; run the repo's formatter on the result.

## Wiring per stack

**Python** - a `demo` dependency group, so `uv sync` and CI stay lean:

```toml
[dependency-groups]
demo = ["playwright>=<current>"]
```

```toml
[tasks."demo:record"]
description = "Record the walkthrough videos into demo/ (app must be running)"
run = [
  "uv run --group demo playwright install chromium",
  "uv run --group demo python scripts/demo/<feature>_walkthrough.py",
]
```

**Node** - pnpm has no dependency groups, so `playwright` is a devDependency;
the browser download, the heavy part, still happens only in `demo:record`. The
script runs on Node's built-in type stripping (Node 22.18+), with no build step:

```toml
[tasks."demo:record"]
description = "Record the walkthrough videos into demo/ (app must be running)"
run = [
  "pnpm exec playwright install chromium",
  "node scripts/demo/<feature>_walkthrough.ts",
]
```

A second feature appends its script to the same task. Resolve the `playwright`
version through context7 at install time; never copy one from here.

**Ignore the output, anchored**: `/demo/` in `.gitignore`. A bare `demo/` also
matches `scripts/demo/` and hides the script. `demo/.auth/` holds saved sessions
(tokens), so it must never be committed; the anchored rule covers it.

**Base URL**: the scripts read `DEMO_BASE_URL` (default `http://localhost:3000`).
Where the dev server's port comes from a variable, set `DEMO_BASE_URL` from that
same variable in the task, so a worktree's port offset still works.

## Choosing the tool

| Need | Use | Why |
|---|---|---|
| Find pages, roles and stable locators | Playwright CLI (`@playwright/cli`) | Token-efficient snapshots and element refs; one shell command per step |
| The same, on a surface with no shell | Playwright MCP | Works without a shell, but tool schemas and accessibility trees cost context |
| The deliverable a client receives | A committed script in the repo's language | Linted, reviewed, and re-recorded with one command when data or UI change |
| A throwaway clip nobody will re-record | Playwright CLI `video-start --cursor` + `video-chapter` | Fast, but a shell transcript is not an artifact, and its default video size is small |

## Verify with a contact sheet

```sh
ffmpeg -y -loglevel error -i demo/<feature>_walkthrough.mp4 \
  -vf "fps=1/3,scale=480:-1,tile=4x3" demo/contact-%02d.png
```

One frame every three seconds, twelve per sheet. Read every sheet back and check
each scene shows what its caption claims. For a short scene, sample its window
instead: `-ss <start> -t <seconds> -vf "fps=2,scale=480:-1,tile=4x2"`.
