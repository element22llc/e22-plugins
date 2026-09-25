---
name: worktrees
description: "Internal worktree check - whatever tool made them (Claude Code, Orca, Conductor, git), each worktree inherits mise trust, gets its own ports, carries its boot files and is torn down on delete; sweeps stacks deleted ones left. Writes on confirmation."
when_to_use: "Reached via /steer:setup worktrees - not a direct entry point."
# Internal path behind `/steer:setup worktrees`. Model-callable, hidden from the
# slash menu - see the note on `init`.
user-invocable: false
allowed-tools:
  - Bash(sh *scripts/scan-worktrees.sh*)
  - Bash(git worktree list *)
  - Bash(docker compose ls *)
---

# Worktree handling (`/steer:setup worktrees`)

Rule `45-delivery` § Parallel worktrees assumes every worktree inherits trust,
runs its own Compose stack and is cleaned up when it goes. steer's hooks deliver
that only for worktrees Claude Code manages: **only Claude Code raises
`WorktreeRemove`**. A tool that creates and deletes worktrees itself - Orca,
Conductor, a plain `git worktree remove` - leaves its stack running unless the
repo carries that tool's own teardown hook. This skill checks a repo, installs
what its worktree tool needs, and sweeps what a deleted worktree left behind.

## 1. Scan

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-worktrees.sh" .
```

Read-only; its header documents every line. Works from the primary checkout or
any linked worktree. Report the **gaps only**, one line each - a clean scan is
one sentence.

## 2. Fix, finding by finding

Batch the confirmation for file edits. Ask **separately** before anything that
destroys data (orphans).

| Finding | Fix |
|---|---|
| `trust untrusted <wt>`, `primary-trust trusted` | `mise trust -C <wt>` - copying the primary's decision grants nothing new (trust is path-keyed). |
| `trust untrusted`, primary not `trusted` | Change nothing; ask the human to run `mise trust && mise install` in the primary checkout. **Never create trust.** |
| `env-isolation absent` / `mis-wired` | Scaffold drift - route to `/steer:setup sync` (`worktree-port-isolation`), never hand-copy `worktree-env.sh`. |
| `worktreeinclude absent` / `incomplete` | Add the uncovered paths to `.worktreeinclude` (a glob like `apps/*/.env` where several share a shape). Git-ignored boot files only - never caches or build output. |
| `env-copy missing <wt>: <files>` | The worktree predates the include. Offer to copy those files from the primary; never overwrite one that exists. Local only, nothing to commit. |
| `worktree-dir unignored <dir>` | Add `<dir>/` to `.gitignore`. |
| `teardown hooked` | Nothing - steer's `WorktreeRemove` hook runs `docker:clean`. |
| `teardown absent orca` | Install `${CLAUDE_PLUGIN_ROOT}/templates/worktrees/orca.yaml` at the repo root. |
| `teardown merge orca` | Keep the repo's `orca.yaml`; add the template's archive line to its `scripts.archive`. |
| `teardown manual conductor` | No bundled hook: add `mise run docker:clean \|\| true` to the archive script in Conductor's repository settings. |
| `teardown manual git` | Nothing to install: say `mise run docker:clean` runs **before** `git worktree remove`; the orphan sweep is the backstop. |
| `orphan <project> <dir>` | List them. On an explicit yes: `docker compose -p <project> down --remove-orphans`, then `docker volume rm` each `docker volume ls -q --filter label=com.docker.compose.project=<project>`. |

After installing Orca's hook, say both limits plainly: Orca's repository hook
policy must allow the shared `orca.yaml` script, and `orca worktree rm` skips it
without `--run-hooks`.

`.worktreeinclude`, `.gitignore` and `orca.yaml` are committed files: land them
through the repo's delivery mode like any change (rule `45-delivery` § Commit
autonomy). Trust and copied env files are local state and commit nothing.

## 3. Verify

Re-run the scan and report what is still open. Close with
`## Recommended next actions - /steer:setup worktrees`.

## Gotchas

- **`manager ... session env` describes this session only.** A primary checkout
  opened in a plain terminal shows no env line; the worktree paths are the
  durable signal. Several managers can show up at once - handle each.
- **Never remove a stack the scan did not list.** An orphan is a project named
  `<primary>-<worktree>` whose config dir is gone. A running stack with its
  directory present belongs to a live worktree, even when it looks stale.
- **The Orca archive hook must stay fail-soft and exit-free.** A failing archive
  hook blocks Orca's removal, and Orca may append the user's local script after
  it. Merge a line into an existing `archive`, never an `exit`.
