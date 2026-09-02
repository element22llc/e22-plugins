---
name: doctor
description: Detect the local prerequisites a managed repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), Docker — flagging shadowed runtimes; installs mise + runtimes on confirmation, GUI and `sudo`/host steps (git, Docker Desktop) handed over.
when_to_use: >-
  Use on a fresh machine, or whenever a tool is missing ("command not found",
  "tool not found", mise/docker errors), before /steer:init, /steer:build, or
  `mise run dev:setup`. Also when steer's own scripts fail to run at all
  ("syntax error near unexpected token", every hook broken at once) — §0 checks
  whether the plugin install itself is corrupt.
allowed-tools:
  - Bash(grep -rl *)
  - Bash(git rev-parse *)
  - Bash(git --version)
  - Bash(mise --version)
  - Bash(mise doctor *)
  - Bash(mise ls *)
  - Bash(docker --version)
  - Bash(docker info *)
  - Bash(sh *scripts/scan-prereqs.sh*)
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

# Prerequisite doctor

Get a blank or half-set-up machine to the point where `/steer:init`,
`/steer:build`, and `mise run dev:setup` actually work. This is the one place
the toolchain-install logic lives; `/steer:init` and `/steer:build` call here
rather than carrying their own copies.

**What a skill cannot do — the manual floor.** Installing **Claude Code** itself,
**adding the `e22-plugins` marketplace**, and the **Docker Desktop** app are GUI/host
steps no skill can perform (a skill can't run before its host exists). **`git` is on
the floor too**, for a different reason: installing it is a `sudo`/host command
(`xcode-select --install`, `sudo apt-get install git`), which this skill presents for
you to run rather than running itself. This skill
*detects* and *links* everything on the floor; for everything below it — mise and the
runtimes it manages — it installs with your confirmation.

## 0. Plugin integrity — is steer itself intact?

Run this **first**, before the detector below. It is the one check that cannot
be delegated to a bundled script, because the fault it looks for is what stops
bundled scripts from running at all:

```sh
grep -rl "$(printf '\r')" "${CLAUDE_PLUGIN_ROOT}/hooks" "${CLAUDE_PLUGIN_ROOT}/scripts"
```

**Any output means the installed plugin has CRLF line endings** — the checkout
was made on a host with `core.autocrlf=true` (the Git for Windows default; a WSL
session reading a Windows-side plugin directory hits it too). A CRLF shell
script does not warn, it fails to **parse**, so every hook lib and scan script
is dead and the symptom reaching the user is an opaque
`syntax error near unexpected token $'{\r'` from whichever script sourced a lib
first.

Report it as a **plugin-install fault, not a missing prerequisite**, and stop —
none of the checks below are meaningful until it is fixed. The repair:

```sh
# Re-clone the marketplace with normalization applied (preferred).
/plugin uninstall steer@e22-plugins   # then re-install; steer ships .gitattributes with eol=lf
```

If reinstalling is not immediately possible, the in-place unblock is:

```sh
find "${CLAUDE_PLUGIN_ROOT}" -type f \( -name '*.sh' -o -name '*.md' \) \
  -exec sed -i 's/\r$//' {} +          # on macOS: sed -i ''
```

**Print this for the dev to run — never run it yourself.** This skill disallows
`Edit`/`Write` for the same reason it refuses to touch a shell rc: rewriting
files inside an installed plugin directory is the dev's call, not the skill's.
Say plainly that it is a workaround on an installed copy which `/plugin update`
will overwrite, and that re-installing is the real fix.

Silence here is the pass — say nothing about it and move to §1.

## 1. Detect — run the scan, don't eyeball

Run the read-only detector and act on its output (never guess what's installed):

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-prereqs.sh" .
```

It prints an `os` fingerprint line, then one TAB line per tool —
`<tool>\t<status>\t<detail>`. Statuses:

| status | meaning | what to do |
|---|---|---|
| `ok` | installed (detail = version) | nothing |
| `missing` | not installed | resolve (§3) — a blocker for required tools |
| `down` | docker present, daemon not running | start the daemon (§3) |
| `via-mise` | runtime absent but mise present | one `mise install` provides it (§3) |
| `unmanaged` | runtime absent and mise absent | install mise first, then `mise install` |
| `shadowed` | runtime present but a non-mise copy (nvm/asdf/volta/fnm/system) is masking mise's pinned one | advisory — surface it and fix activation (§3) |
| `n/a` | not used by this repo's stack | nothing |

The `detail` column carries requiredness for `docker` (`required (compose.yaml)`
vs `advisory`), so a `missing`/`down` docker is only a blocker when this repo
declares backing services.

## 2. Report

Summarize the state plainly. When you arrived here from `/steer:build`, speak in
the PO's plain language (no git/stack jargon — see the "Who you are working with"
rule); for a dev, the tool names are fine. Name what's green, what's a blocker,
and what you're about to do.

## 3. Resolve — offer to install, gated on confirmation

Install scriptable tools **only after the user says yes** (Commit-autonomy
applies to system changes too). GUI/host steps are always handed over as
instructions — never automated. Use the `os` line to pick the right command;
these mirror the scaffold README quickstart (the static source of the same
commands).

- **`mise` missing** — the gateway; resolve this first.
  - macOS: `brew install mise`
  - Linux / WSL2: `curl https://mise.run | sh`
  - Then activate it in the shell and persist it to the rc file:
    `eval "$(mise activate zsh)"` (or `bash`), and add that line to
    `~/.zshrc` / `~/.bashrc` so new shells have it. **Print this for the dev to
    run — never edit their shell rc yourself:** this skill disallows `Edit`/`Write`
    precisely because a dotfile outside the repo is the dev's to change.
- **`node` / `pnpm` / `uv` (`via-mise` or `unmanaged`)** — do **not** install
  these separately. Once mise is present, run `mise install` from the repo
  (and `cd infra && mise install` if they'll touch infra); it provisions every
  pinned runtime. Then verify each `mise.lock` gained real `[[tools.*]]` entries
  (the canonical pin procedure: `/steer:reference conventions` → "Toolchain:
  `latest` in config, pinned in the lockfile"). Report the lockfile as needing
  to be committed — this skill never commits (see Guardrails); the caller does.
- **`node` / `pnpm` / `uv` `shadowed`** — mise's pinned runtime exists but a
  global version manager (the `detail` names it: nvm/asdf/volta/fnm) or a
  system/Homebrew copy is ahead of it on `PATH`, so bare `pnpm`/`node` run the
  wrong version (this is what silently produces a `node_modules` built by the
  wrong pnpm). Advisory, not a blocker. Fix: ensure `eval "$(mise activate …)"`
  is sourced **after** the other manager in the rc file (mise must load last to
  win `PATH`), open a fresh shell, and confirm `which <tool>` now resolves under
  `…/mise/…`. Until then, run package-manager commands via `mise exec -- <tool>`.
- **`git` missing** — macOS: `xcode-select --install`; Debian/Ubuntu:
  `sudo apt-get install git` (a sudo command: present it, let the user run it).
- **`docker` missing** — **manual** (GUI app, can't be scripted): point them to
  <https://www.docker.com/products/docker-desktop/>, have them install and start
  it, then re-run this skill. Only a blocker when `detail` says `required`.
- **`docker` down** — offer to start it: macOS `open -a Docker` (then wait and
  re-scan until the daemon answers); Linux `sudo systemctl start docker`
  (present the command).
- **Windows** — the answer depends on the **shell**, not the OS. The hooks (and
  this detector) run via `sh`, so a POSIX shell must be present.
  - **`os` = `windows`** (the scan ran — it printed `os = windows`, i.e. under
    MINGW/MSYS via **Git for Windows**): this is a **supported** setup, not a
    blocker. steer's `sh`-invoked hooks run here, and it's the right environment
    for the **Claude Desktop Code tab** — `/steer:build` and `mise run dev:setup`
    build locally too (install Docker Desktop if the repo declares services).
    Proceed with the normal `mise`/runtime resolution above. WSL2 is *optional*
    here — only worth it for heavy CLI/IDE development.
  - **No POSIX shell at all** (this detector failed to run — native
    `cmd`/PowerShell, no Git Bash): install **Git for Windows** (`winget install
    Git.Git` or <https://gitforwindows.org/>), reopen the session, and re-scan —
    that alone gets the **Desktop Code tab** working, builds included. For
    **CLI / IDE** development, WSL2 is the recommended alternative: in elevated
    PowerShell run `wsl --install`, reboot, then re-run everything *inside* WSL2.
    Both are GUI/host steps — hand them over, don't automate. Full matrix: the
    Windows setup page in the docs (<https://github.com/element22llc/e22-plugins/blob/main/docs/getting-started/windows-setup.md>).

## 4. Re-scan and confirm

After installing, **re-run the detector** and report the new state. Don't claim
the machine is ready on the strength of a command that "looked like it worked" —
let the scan say so. A tool still `missing`/`down`/`unmanaged` is not resolved.

## Recommend the next action

Close with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, derived from the
final scan.

| Observed state | Category | Action / suggested command |
|---|---|---|
| §0 failed — the installed plugin has CRLF line endings | Blocking now | steer itself is broken, so nothing below was checked: re-install it (`/plugin uninstall steer@e22-plugins`, then re-install), or hand over the §0 in-place unblock |
| A required tool still `missing`/`down`/`unmanaged` | Blocking now | Finish resolving it (§3), then re-scan |
| `os` = `windows` (Git Bash live) | Complete | Supported — hooks run; valid for the Desktop Code tab, builds included. WSL2 optional (CLI/IDE dev only) |
| Windows, no POSIX shell (detector couldn't run) | Blocking now | Install Git for Windows, reopen, re-scan — or WSL2 for CLI/IDE dev |
| A runtime is `shadowed` (and nothing above blocks) | Recommended | Fix activation ordering (§3) — not a hard blocker, but the wrong, un-pinned version is in use |
| All green, repo not yet set up (no `/spec`) | Recommended | Stand the repo up — `/steer:init` (dev) or `/steer:build` (PO) |
| All green, repo already set up | Recommended | `mise run dev:setup`, then start work |
| All green, nothing else pending | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence. Read-only on the repo — it
detects and (with consent) installs host tools; it never edits repo files or
commits.

## Guardrails

- Never install without explicit confirmation. GUI/host steps (Docker Desktop,
  WSL2, Claude Code, the marketplace) are always manual instructions.
- Never edit repo files or commit from this skill; never touch secrets.
- The detector is plugin-internal — invoke it from `${CLAUDE_PLUGIN_ROOT}`; it is
  not installed into the consumer repo.
