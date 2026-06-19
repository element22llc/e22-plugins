# GitHub Copilot CLI support

steer is built for Claude Code, but teammates who use **GitHub Copilot CLI** can
pick up the same org engineering standards. This page explains how the two
surfaces share one source of truth and how to install and refresh the Copilot
side.

!!! note "Prototype scope"
    Today the Copilot target is **standards-only**: it delivers the always-on
    engineering rules. The `/steer:*` skills, the PreToolUse gate-hooks, and the
    subagents are **not** ported yet — those are planned later phases. Copilot
    users get the operating manual; the interactive workflows still run from
    Claude Code.

## Why the two surfaces differ

On Claude Code, steer's rules reach every session through a **SessionStart hook**
(`inject-standards.sh`) whose stdout becomes the session's context. GitHub
Copilot CLI has no equivalent: its `sessionStart` hook **ignores stdout**, so it
cannot inject context that way. Copilot's always-on context instead comes from a
static **custom-instructions file**.

So the same `plugins/steer/rules/*.md` are delivered two ways:

| | Claude Code | GitHub Copilot CLI |
|---|---|---|
| Mechanism | SessionStart hook → `additionalContext` | Static `.github/copilot-instructions.md` |
| Freshness | Live every session via `/plugin update` | Regenerated on install/refresh (`/steer:init`) |
| Source of truth | `plugins/steer/rules/*.md` | the **same** `rules/*.md` |

A build-time generator (`mise run gen:copilot`) concatenates the rules into a
committed artifact, and a sync gate (`check_copilot_instructions.py`, part of
`plugin-check`) fails the build if that artifact ever drifts from the rules — so
the two surfaces can never silently diverge.

## Why `.github/copilot-instructions.md`, not `AGENTS.md`

Copilot reads several repository instruction files and **merges** them — including
`AGENTS.md` *and* `CLAUDE.md`/`GEMINI.md` — resolving conflicts
non-deterministically. Emitting an `AGENTS.md` would therefore double-load the
org standards alongside a repo's existing `CLAUDE.md`, while Claude Code (which
does not read `AGENTS.md`) would ignore it entirely.

`.github/copilot-instructions.md` is Copilot's **primary** instructions file, is
**never** read by Claude Code, and lives under `.github/` so it does not compete
at the repo root with `CLAUDE.md`. That keeps each surface reading exactly one
copy of the standards.

## Using it as a Copilot teammate

1. Add the marketplace and install steer (one time):

    ```shell
    copilot plugin marketplace add element22llc/e22-plugins
    copilot plugin install steer
    ```

2. The standards are read from `.github/copilot-instructions.md` in the repo.
   That file is installed by `/steer:init` (new repos) or `/steer:adopt`
   (existing repos), run **from Claude Code** during bootstrap — see the
   [Adopt workflow](../workflows/adopt.md). Copilot teammates only consume the
   file; they do not need to generate it.

## Refreshing after a steer update

The Copilot instructions file is a **static snapshot**, so it goes stale when
steer's rules change. To refresh it, update the plugin and re-run init's install
step from Claude Code:

```shell
copilot plugin update steer       # pull the new plugin version
# then, from Claude Code in the repo:
/steer:init                       # regenerates .github/copilot-instructions.md
```

The file is **fully steer-managed** — overwritten on refresh and never
hand-edited. Repo-specific Copilot guidance belongs in a separate
`*.instructions.md` file, not in this one.

## Known limitations

- **Standards only.** Skills, gate-hooks, and agents are not available on Copilot
  yet. References to `/steer:*` skills inside the standards describe the Claude
  Code workflow; on Copilot they are context, not runnable commands.
- **Manual refresh.** Unlike Claude Code's live injection, the Copilot file must
  be regenerated after a plugin update (see above).
- **Hooks are not relied upon.** Copilot's plugin hooks are Preview and can be
  disabled by org policy, so the standards delivery deliberately does not depend
  on them.
