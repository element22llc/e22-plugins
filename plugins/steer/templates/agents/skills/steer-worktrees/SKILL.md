---
name: steer-worktrees
description: Check each worktree inherits mise trust, gets its own ports and boot files, and is torn down on delete.
user-invocable: false
---

<!-- Generated from the steer plugin's skills/worktrees/SKILL.md - do not edit by hand.
     Refresh with /steer:setup sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Reached via /steer-setup worktrees.

> **Helper scripts run from a local steer copy.** Commands below that use
> `"${STEER_PLUGIN_ROOT}/..."` (a helper, its template argument, a plugin directory) need
> `STEER_PLUGIN_ROOT` set to the steer plugin directory - the installed plugin
> (Codex, Copilot CLI), or `plugins/steer` in a checkout of
> `element22llc/e22-plugins`. With no local copy, skip the step and say what it
> would have reported. Never download a helper and run it from a URL.

# Worktree handling (`/steer-setup worktrees`)

Rule `45-delivery` -> Parallel worktrees assumes every worktree inherits trust,
runs its own Compose stack and is cleaned up when it goes. steer delivers
trust and ports wherever the worktree lives, but **no tool tells steer a worktree
is being deleted**: Claude Code removes its own without raising `WorktreeRemove`,
and Orca, Conductor or a plain `git worktree remove` do the same. A deleted
worktree's stack and volumes stay behind unless the repo carries that tool's own
teardown hook. This skill checks a repo, installs what its worktree tool needs,
and sweeps what a deleted worktree left behind.

## 1. Scan

```sh
sh "${STEER_PLUGIN_ROOT}/scripts/scan-worktrees.sh" .
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
| `env-isolation absent` / `mis-wired` | Scaffold drift - route to `/steer-setup sync` (`worktree-port-isolation`), never hand-copy `worktree-env.sh`. |
| `worktreeinclude absent` / `incomplete` | Add the uncovered paths to `.worktreeinclude` (a glob like `apps/*/.env` where several share a shape). Git-ignored boot files only - never caches or build output. |
| `env-copy missing <wt>: <files>` | The worktree predates the include. Offer to copy those files from the primary; never overwrite one that exists. Local only, nothing to commit. |
| `worktree-dir unignored <dir>` | Add `<dir>/` to `.gitignore`. |
| `teardown swept` | Nothing to install: Claude Code deletes its worktrees without a hook steer can use, so the primary checkout's session check reports their stacks and the `orphan` row below removes them. |
| `teardown absent orca` | Install `https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/worktrees/orca.yaml` at the repo root. |
| `teardown merge orca` | Keep the repo's `orca.yaml`; add the template's archive line to its `scripts.archive`. |
| `teardown manual conductor` | No bundled hook: add `mise run docker:clean \|\| true` to the archive script in Conductor's repository settings. |
| `teardown manual git` | Nothing to install: say `mise run docker:clean` runs **before** `git worktree remove`; the orphan sweep is the backstop. |
| `orphan <project> <dir>` | List them (`-` for the dir: only volumes remain, matched by name). On an explicit yes: `docker compose -p <project> down --remove-orphans`, then `docker volume rm` each `docker volume ls -q --filter label=com.docker.compose.project=<project>`. |

After installing Orca's hook, say both limits plainly: Orca's repository hook
policy must allow the shared `orca.yaml` script, and `orca worktree rm` skips it
without `--run-hooks`.

`.worktreeinclude`, `.gitignore` and `orca.yaml` are committed files: land them
through the repo's delivery mode like any change (rule `45-delivery` -> Commit
autonomy). Trust and copied env files are local state and commit nothing.

Worktrees from `claude --worktree`, subagent `isolation: worktree` and `/batch`
need nothing beyond these rows; how they fit delivery is in
`/steer-reference conventions` -> Native Claude Code delivery features.

## 3. Verify

Re-run the scan and report what is still open. Close with
`## Recommended next actions - /steer-setup worktrees`.

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
