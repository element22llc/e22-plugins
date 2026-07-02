# GitHub Copilot support

steer is built for Claude Code, but teammates who use **GitHub Copilot** — either
the **Copilot CLI** or **Copilot in VS Code** — can pick up the same org
engineering standards. This page explains how all surfaces share one source of
truth and how to install and refresh the Copilot side.

!!! note "Prototype scope"
    The Copilot target covers the **always-on standards**
    (`.github/copilot-instructions.md`, read by both the CLI and VS Code), the
    **skills** (as cross-tool `SKILL.md` on the CLI, and as
    `.github/prompts/*.prompt.md` slash-commands in VS Code), and a single **gate
    hook** (the version-pin policy, CLI-only, as a soft `ask`). Subagents are not
    ported, skill *enforcement* differs from Claude Code, and **hooks do not exist
    in VS Code** — see the sections below for the caveats.

## Surfaces at a glance

| Capability | Claude Code | Copilot CLI | Copilot in VS Code |
|---|---|---|---|
| Always-on standards | SessionStart hook → `additionalContext` | `.github/copilot-instructions.md` | `.github/copilot-instructions.md` (read natively) |
| Skills | plugin `skills/` (`/steer:<skill>`) | plugin `skills/` via Copilot manifest | `.github/prompts/*.prompt.md` (`/steer-<skill>`) |
| Gate hooks | `hooks/hooks.json` (hard `deny`) | `hooks/copilot-hooks.json` (soft `ask`) | none (no hook mechanism) |
| Source of truth | `rules/*.md` + `skills/` | the **same** `rules/` + `skills/` | the **same** `rules/` + `skills/` |

All three surfaces are generated from one set of `rules/` and `skills/`, and a
build-time drift gate (see [below](#why-the-surfaces-differ)) fails the build if
the generated artifact ever falls out of sync — so they can never silently diverge.

## Why the surfaces differ

On Claude Code, steer's rules reach every session through a **SessionStart hook**
(`inject-standards.sh`) whose stdout becomes the session's context. GitHub
Copilot has no equivalent: its `sessionStart` hook **ignores stdout**, so it
cannot inject context that way. Copilot's always-on context instead comes from a
static **custom-instructions file**, `.github/copilot-instructions.md`, which both
the Copilot CLI and Copilot in VS Code read.

A build-time generator (`mise run gen:copilot`) concatenates the rules into that
committed artifact, and a sync gate (`check_copilot_instructions.py`, part of
`plugin-check`) fails the build if the artifact ever drifts from the rules. The
same generator step also renders the per-skill prompt files (below), with its own
drift gate (`check_copilot_prompts.py`).

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

The standards file and the prompt files are installed by `/steer:init` (new repos)
or `/steer:adopt` (existing repos), run **from Claude Code** during bootstrap —
see the [Adopt workflow](../workflows/adopt.md). Copilot teammates only consume
the files; they do not need to generate them.

### Copilot CLI

```shell
copilot plugin marketplace add element22llc/e22-plugins
copilot plugin install steer@e22-plugins
```

The CLI loads the skills via the Copilot plugin manifest and reads the standards
from `.github/copilot-instructions.md` in the repo.

### Copilot in VS Code

VS Code does **not** use the Copilot CLI plugin marketplace, so there is nothing
to `install` — it reads the committed repo files directly:

- **Standards** — `.github/copilot-instructions.md` is read automatically as the
  repository's custom instructions (governed by the
  `github.copilot.chat.codeGeneration.useInstructionFiles` setting, default-on in
  recent VS Code). To confirm it loaded, expand the **References** section of a
  Copilot Chat response — the file is listed there (or right-click the Chat view
  → **Diagnostics**).
- **Skills** — each user-invocable steer skill ships as a
  `.github/prompts/steer-<skill>.prompt.md` *prompt file*, surfaced in Copilot
  Chat as a `/steer-<skill>` slash-command (governed by the `chat.promptFiles`
  setting). Type `/steer-` in Chat to see them.

The bundled `.vscode/settings.json` sets both settings explicitly, so the
standards load regardless of a teammate's VS Code defaults.

## Refreshing after a steer update

The Copilot files are a **static snapshot**, so they go stale when steer's rules
or skills change. To refresh, update the plugin and re-run init's install step
from Claude Code:

```shell
copilot plugin update steer       # CLI only: pull the new plugin version
# then, from Claude Code in the repo:
/steer:init                       # regenerates copilot-instructions.md + prompts/
```

The files are **fully steer-managed** — overwritten on refresh and never
hand-edited. Repo-specific Copilot guidance belongs in a separate
`*.instructions.md` file, not in these.

## Skills on Copilot

steer's skills are authored as `SKILL.md` files. They reach the two Copilot
surfaces differently:

- **Copilot CLI** reads `SKILL.md` natively (an open cross-tool standard). A
  Copilot-specific plugin manifest
  (`plugins/steer/.github/plugin/plugin.json`, which Copilot prefers over the
  `.claude-plugin/` manifest Claude Code uses) points Copilot at `skills/`.
- **Copilot in VS Code** uses prompt files instead. The build renders one
  `.github/prompts/steer-<skill>.prompt.md` per user-invocable skill from the
  skill's frontmatter.

Two differences from Claude Code matter on **both** Copilot surfaces:

- **Tool-permission scoping is inert.** Copilot does not honor steer's
  `allowed-tools` / `disallowed-tools`. steer's read-only skills rely on
  `disallowed-tools` to guarantee they never write; on Copilot that guard is
  **ignored**. Treat those skills as advisory there.
- **Bodies are Claude-centric.** Skill instructions reference
  `${CLAUDE_PLUGIN_ROOT}` paths and `/steer:<skill>` invocation, which do not
  resolve in a repo-committed prompt file. The VS Code prompt files are therefore
  **intent capsules** — purpose, when-to-use, and arguments — that drive the same
  workflow on top of the always-on standards, not verbatim reproductions of the
  skill procedure. The authoritative procedure still lives in the plugin.

## Gate hooks on Copilot

The Copilot CLI manifest points hooks at a **Copilot-native** file
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

**VS Code has no hook mechanism at all** — the gate is Copilot-CLI-only. In VS
Code the version-pin policy lives only as text in the standards.

## Known limitations

- **Subagents not ported.** The `steer-reviewer` agent is Claude-only.
- **Skill enforcement/invocation differs.** See [Skills on Copilot](#skills-on-copilot)
  — tool-permission scoping is inert and skill bodies are intent capsules.
- **One gate only, soft, CLI-only.** Only the version-pin gate is ported, as
  `ask`, and only on the Copilot CLI. VS Code gets no hooks. Other gates live in
  the standards text, not as hooks.
- **Manual refresh.** Unlike Claude Code's live injection, the Copilot files must
  be regenerated after a plugin update (see above).
- **Hooks are Preview.** Copilot's plugin hooks are Preview and can be disabled
  by org policy, so the standards delivery never depends on them; the Copilot
  hook is hardened to fail **open** (it can never block an edit on error).
