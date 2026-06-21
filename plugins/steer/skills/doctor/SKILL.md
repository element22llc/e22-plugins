---
name: doctor
description: Detect and install the local prerequisites a managed repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), and Docker — with per-OS guidance and confirmation-gated installs.
when_to_use: >-
  Use on a fresh machine, or whenever a tool is missing ("command not found",
  "tool not found", mise/docker errors), before /steer:init, /steer:build, or
  `mise run dev:setup`. /steer:build and /steer:init invoke it when prerequisites
  are absent.
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

# Prerequisite doctor

Get a blank or half-set-up machine to the point where `/steer:init`,
`/steer:build`, and `mise run dev:setup` actually work. This is the one place
the toolchain-install logic lives; `/steer:init` and `/steer:build` call here
rather than carrying their own copies.

**What a skill cannot do — the manual floor.** Installing **Claude Code** itself,
**adding the steer marketplace**, and the **Docker Desktop** app are GUI/host
steps no skill can perform (a skill can't run before its host exists). This skill
*detects* and *links* them; for everything below the floor — mise and the
runtimes it manages — it installs with your confirmation.

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
    `~/.zshrc` / `~/.bashrc` so new shells have it.
- **`node` / `pnpm` / `uv` (`via-mise` or `unmanaged`)** — do **not** install
  these separately. Once mise is present, run `mise install` from the repo
  (and `cd infra && mise install` if they'll touch infra); it provisions every
  pinned runtime. Then verify each `mise.lock` gained real `[[tools.*]]` entries
  (see `/steer:init` step 4) and commit it.
- **`git` missing** — macOS: `xcode-select --install`; Debian/Ubuntu:
  `sudo apt-get install git` (a sudo command: present it, let the user run it).
- **`docker` missing** — **manual** (GUI app, can't be scripted): point them to
  <https://www.docker.com/products/docker-desktop/>, have them install and start
  it, then re-run this skill. Only a blocker when `detail` says `required`.
- **`docker` down** — offer to start it: macOS `open -a Docker` (then wait and
  re-scan until the daemon answers); Linux `sudo systemctl start docker`
  (present the command).
- **`os` = `windows`** — unsupported host (the toolchain assumes a POSIX shell).
  Hand over the WSL2 setup, **manual**: in elevated PowerShell run
  `wsl --install`, reboot, then clone and re-run everything *inside* WSL2 (see
  the scaffold README "Windows: develop in WSL"). Don't attempt installs on
  native Windows.

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
| A required tool still `missing`/`down`/`unmanaged` | Blocking now | Finish resolving it (§3), then re-scan |
| `os` = `windows` (native) | Blocking now | Set up WSL2 and re-run inside it |
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
