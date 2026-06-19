# GitHub Copilot CLI support

steer is built for Claude Code, but teammates who use **GitHub Copilot CLI** can
pick up the same org engineering standards. This page explains how the two
surfaces share one source of truth and how to install and refresh the Copilot
side.

!!! note "Prototype scope"
    The Copilot target covers the **always-on standards** (`.github/copilot-instructions.md`),
    the **skills** (they load via Copilot's cross-tool `SKILL.md` standard), and
    a single **gate hook** (the version-pin policy, as a soft `ask`). The
    subagents are not ported, and skill *enforcement/invocation* differs from
    Claude Code — see [Skills on Copilot](#skills-on-copilot) and
    [Gate hooks on Copilot](#gate-hooks-on-copilot) for the caveats.

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

## Skills on Copilot

steer's skills are authored as `SKILL.md` files, which is an **open cross-tool
standard** Copilot CLI reads natively. A Copilot-specific plugin manifest
(`plugins/steer/.github/plugin/plugin.json`, which Copilot prefers over the
`.claude-plugin/` manifest Claude Code uses) points Copilot at `skills/`, so the
skills load. Two differences from Claude Code matter:

- **Tool-permission scoping is inert.** Copilot's `SKILL.md` does not yet support
  `allowed-tools` / `disallowed-tools` (an open cross-tool proposal at the time of
  writing). steer's read-only skills rely on `disallowed-tools` to guarantee they never
  write; on Copilot that guard is **ignored**. Treat those skills as advisory
  there — they will not be hard-prevented from editing.
- **Bodies are Claude-centric.** Skill instructions reference
  `${CLAUDE_PLUGIN_ROOT}` paths and `/steer:<skill>` invocation. On Copilot they
  run through Copilot's own skill activation; the workflow intent carries over,
  but exact invocation and any plugin-root file reads may differ.

## Gate hooks on Copilot

The Copilot manifest points hooks at a **Copilot-native** file
(`hooks/copilot-hooks.json`) rather than letting Copilot fall back to Claude's
`hooks/hooks.json` — important because Copilot's `preToolUse` hooks are
**fail-closed** (a hook that errors *denies* the tool), so a mis-run Claude hook
could block edits.

Only the **version-pin policy** gate is ported so far, and as a soft **`ask`**
(Copilot prompts you to confirm) rather than Claude's hard `deny`. The same
`check-version-pins.sh` logic runs on both surfaces; it emits Copilot's flat
`permissionDecision` envelope when invoked with `STEER_HOOK_TARGET=copilot`. The
advisory spec-first / issue-first nudges are **not** ported as hooks (Copilot's
`preToolUse` cannot inject non-blocking context); their intent is carried by the
standards in `.github/copilot-instructions.md`.

## Known limitations

- **Subagents not ported.** The `steer-reviewer` agent is Claude-only.
- **Skill enforcement/invocation differs.** See [Skills on Copilot](#skills-on-copilot)
  — tool-permission scoping is inert and skill bodies are Claude-centric.
- **One gate only, soft.** Only the version-pin gate is ported, as `ask`. Other
  gates live in the standards text, not as hooks.
- **Manual refresh.** Unlike Claude Code's live injection, the Copilot
  instructions file must be regenerated after a plugin update (see above).
- **Hooks are Preview.** Copilot's plugin hooks are Preview and can be disabled
  by org policy, so the standards delivery never depends on them; the Copilot
  hook is hardened to fail **open** (it can never block an edit on error).
