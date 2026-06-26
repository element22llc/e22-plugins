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

## Why the split

steer's value is the always-on standards, and those ride on the hook lifecycle.
The hooks are POSIX `sh` scripts (jq-free, by design), so they need a POSIX shell
present:

- **Git for Windows** supplies exactly that shell — enough for the Desktop Code
  tab to run hooks and to build locally.
- **WSL2** supplies a full Linux userland — worth it when you live in the CLI/IDE
  toolchain, overkill when you drive from the desktop app.

Once a POSIX shell is present, the same hooks run identically either way.
