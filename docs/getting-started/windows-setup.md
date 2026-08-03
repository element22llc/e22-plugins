# Windows setup

`steer` runs on Windows — the setup depends on **which surface you use**. The
deciding factor is one technical fact: every steer hook is invoked through `sh`
(`SessionStart` injects the rules, `PreToolUse` runs the guardrails), and native
Windows has no `sh`. What supplies that shell differs by surface.

## Pick your surface

| You use… | Install | WSL2? |
|---|---|---|
| **Claude Desktop** — the app's **Code** tab | **Git for Windows** (+ Docker Desktop to build) | No |
| **Claude Code CLI** or an **IDE** extension (VS Code / JetBrains) | **WSL2** | Yes |
| Claude Desktop **Chat** tab / claude.ai web | — (hooks don't run on any OS; run `/steer:standards`) | No |

### Claude Desktop (Code tab) → Git for Windows

This is the lightest path and the right one for product owners and anyone driving
work from the desktop app. [Git for Windows](https://gitforwindows.org/) ships a
POSIX `sh` plus the `grep`/`sed`/`awk` the hooks use, so steer's `SessionStart`
and `PreToolUse` hooks fire and the always-on rules inject. **No WSL2 required** —
and that includes building: `/steer:build` and `mise run dev:setup` run locally
under Git Bash (mise ships a native Windows binary and manages node/pnpm/uv; add
**Docker Desktop** if the repo declares backing services).

1. Install Git for Windows — `winget install Git.Git`, or the installer from
   <https://gitforwindows.org/>. Accept the defaults.
2. *(Only if you'll build apps with services)* install
   [Docker Desktop](https://www.docker.com/products/docker-desktop/).
3. Restart Claude Desktop so it picks up the new shell.
4. Run `/steer:doctor` — it confirms the shell is live and the toolchain is ready.

!!! warning "Without a shell the hooks fail silently"
    Without Git for Windows the Desktop Code tab still opens, but the hooks can't
    run — the always-on rules never inject and the guardrails never fire. The
    session looks normal but is running **without the standards**.

### CLI / IDE → WSL2

If you work through the Claude Code **CLI** or an **IDE extension**, develop inside
**WSL2** (Ubuntu recommended). It's the smoothest environment for the full
toolchain — POSIX path handling, line-ending parity, and a Linux that matches CI.

1. In an elevated PowerShell: `wsl --install`, then reboot.
2. Open your repo *inside* WSL2 (not via `\\wsl$\` from the Windows side) and run
   everything there — Claude Code CLI, `/steer:setup`, `mise install`.

Run [`/steer:doctor`](../reference/skills.md) for the guided per-machine path, and
follow the scaffold `README.md` quickstart once you're inside WSL2.

!!! note "WSL2 is the recommended dev environment, not a requirement"
    WSL2 is the smoothest path for CLI/IDE *development* — it is **not** required
    to run steer or to build. The Desktop Code tab path above is fully supported on
    its own.

### Chat tab / web → no hooks anywhere

The Claude Desktop **Chat** tab and claude.ai web chat don't run plugin hooks on
*any* OS, so the rules never auto-inject there. Start such a session with
`/steer:standards`. This is an OS-independent surface limit — see
[Known limitations](../reference/known-limitations.md).

## Line endings

`core.autocrlf=true` is the Git for Windows default, which means a plain checkout
rewrites text files to CRLF. That matters more than it sounds: **a CRLF shell
script does not warn, it fails to parse.** The shell reads the trailing `\r` as
part of the token, so `steer_repo_root() {` becomes
`syntax error near unexpected token $'{\r'` and the script never runs at all.

Both sides of this are handled, but they arrive by different routes:

- **The plugin** ships a `.gitattributes` pinning `* text=auto eol=lf`, so the
  bundled hooks and scripts check out as LF no matter what `core.autocrlf` says
  on the host. You get this automatically with any install or reinstall.
- **Your repo** gets the same normalization from the bundled scaffold, so a
  Windows contributor can't commit CRLF into `scripts/*.sh`, a Docker
  entrypoint, or the generated `.github/` Copilot surface. `/steer:init` and
  `/steer:adopt` install it outright. For a repo **already** managed by steer,
  `/steer:sync` reconciles it *additively* into an existing `.gitattributes` —
  the scaffold has carried one since 3.12.0, so most managed repos have the
  file, and the merge adds the new pins without removing your own lines.
  The gap is a repo with **no** `.gitattributes` at all: sync only splices into
  files that already exist, and nothing creates this one, so copy
  `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/gitattributes` in by hand.

!!! note "Normalization applies going forward, not retroactively"
    Adding `.gitattributes` to a repo that already has CRLF **committed** does
    not rewrite that history — git only normalizes what it is asked to stage
    again. Convert the existing content once, in its own commit, with
    `git add --renormalize . && git commit -m "chore: normalize line endings to LF"`.
    Do it on a quiet branch: it touches every affected file, so it will collide
    with anything in flight.

!!! warning "An older install may predate the fix"
    `.gitattributes` only governs *future* checkouts, so a plugin installed
    before this fix shipped can still be sitting on disk with CRLF. The symptom
    is unmistakable once you know it: **every** steer script fails at once with a
    `syntax error near unexpected token` — most visibly `/steer:sync`, which
    breaks on its opening move.

    `/steer:doctor` checks for this **first**, before anything else, and names
    it as a plugin-install fault rather than a missing prerequisite. The fix is
    to reinstall the plugin so it re-clones with normalization applied.

    One failure here is quiet rather than loud, so it is worth knowing about:
    under CRLF, `template-reconcile.sh` could still *run* and report every
    heading in a bundled template as a missing gap — because the CR-suffixed
    anchors could never match your LF file. It now strips CR from both sides,
    so it compares content and not line endings.

## Why the split

steer's value is the always-on standards, and those ride on the hook lifecycle.
The hooks are POSIX `sh` scripts (jq-free, by design), so they need a POSIX shell
present:

- **Git for Windows** supplies exactly that shell — enough for the Desktop Code
  tab to run hooks and to build locally.
- **WSL2** supplies a full Linux userland — worth it when you live in the CLI/IDE
  toolchain, overkill when you drive from the desktop app.

Once a POSIX shell is present, the same hooks run identically either way.
