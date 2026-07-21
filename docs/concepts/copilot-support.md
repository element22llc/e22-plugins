# GitHub Copilot support

steer is built for Claude Code, but teammates who use **GitHub Copilot** — either
the **Copilot CLI** or **Copilot in VS Code** — can pick up the same org
engineering standards. This page explains how all surfaces share one source of
truth and how to install and refresh the Copilot side.

!!! note "Scope"
    The Copilot target covers the **always-on standards**
    (`.github/copilot-instructions.md`, read by both the CLI and VS Code), the
    **skills** (as cross-tool `SKILL.md` on the CLI, and as
    `.github/prompts/*.prompt.md` slash-commands in VS Code), **custom agents**
    (`.github/agents/*.agent.md` — the `steer-reviewer` port), **path-scoped
    instructions** (`.github/instructions/*.instructions.md`), **MCP servers**
    (`.vscode/mcp.json`), an opt-in **cloud coding-agent** setup workflow
    (`copilot-setup-steps.yml`), and the **gate hooks** (the version-pin
    policy and the trunk-push graduation gate, CLI-only, as soft `ask`s).
    Skill *enforcement* still differs from Claude Code and **hooks do not
    exist in VS Code** — see the sections below for the caveats.

## Surfaces at a glance

| Capability | Claude Code | Copilot CLI | Copilot in VS Code |
|---|---|---|---|
| Always-on standards | SessionStart hook → `additionalContext` | `.github/copilot-instructions.md` | `.github/copilot-instructions.md` (read natively) |
| Path-scoped standards | rule `inject-when` traits | (folded into instructions file) | `.github/instructions/*.instructions.md` (`applyTo` glob) |
| Skills | plugin `skills/` (`/steer:<skill>`) | plugin `skills/` via Copilot manifest | `.github/prompts/*.prompt.md` (`/steer-<skill>`) |
| Subagents | plugin `agents/` | plugin `agents/` via manifest | `.github/agents/*.agent.md` (agent picker) |
| MCP servers | plugin `.mcp.json` | plugin `.mcp.json` | `.vscode/mcp.json` |
| Cloud coding agent | — (Claude `@claude` workflow) | — | `.github/workflows/copilot-setup-steps.yml` (opt-in) |
| Gate hooks | `hooks/hooks.json` (hard `deny`) | `hooks/copilot-hooks.json` (soft `ask`) | none (no hook mechanism) |
| Source of truth | `rules/*.md` + `skills/` + `agents/` | the **same** `rules/` + `skills/` + `agents/` | the **same** `rules/` + `skills/` + `agents/` |

Every Copilot artifact — instructions, per-skill prompts, custom agents, the
VS Code `mcp.json`, the CLI hook manifest, and the plugin + marketplace manifest
versions — is generated from that one source and guarded by a build-time **drift
gate** (see [below](#why-the-surfaces-differ)) that fails the build the moment a
committed artifact drifts. A **symmetry meta-gate** (`check_copilot_symmetry.py`,
part of `plugin-check`) further asserts every `gen_copilot_*.py` is wired into
`gen:copilot` and every `check_copilot_*.py` into `plugin-check` — so no future
mirror can ship with a generator but no gate, or vice versa. The surfaces can
never silently diverge, and no Copilot artifact is hand-maintained.

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
  `.claude-plugin/` manifest Claude Code uses) points Copilot at `skills/`. Its
  version — and the Copilot marketplace manifest's — is stamped from the source
  `plugin.json` by `gen_copilot_manifests.py` (`mise run gen:copilot`), so no
  Copilot manifest is hand-versioned either.
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
  skill procedure. `/steer:<skill>` cross-references are rewritten to the
  `/steer-<skill>` prompt names, and the capsule points review-gated workflows at
  the `steer-reviewer` custom agent (below). The authoritative procedure still
  lives in the plugin.

## Custom agents on Copilot

steer's subagents in the plugin's `agents/` reach VS Code as **custom agents** —
`.github/agents/<name>.agent.md`, selectable from the Copilot Chat agent picker
(this is the format formerly called "custom chat modes"/`.chatmode.md`). Today
that is `steer-reviewer`, the read-only reviewer that `/steer-audit` and
`/steer-work --reviewed` delegate a single bounded slice to.

The build renders one `.agent.md` per subagent (`gen_copilot_agents.py`, drift
gate `check_copilot_agents.py`). The subagent's Claude `tools` (`Read`/`Grep`/
`Glob`) are mapped to Copilot's read-only built-in tool sets (`codebase`,
`search`), so the ported reviewer stays write-free on VS Code the same way it is
in Claude Code.

## Path-scoped instructions

Most rules are repo-wide and live in the flat `copilot-instructions.md`. A rule
that is genuinely area-specific — currently the infra/IaC stack rule — is emitted
instead as a **path-scoped instruction file**,
`.github/instructions/<name>.instructions.md`, carrying an `applyTo` glob so
Copilot loads it only when working on matching files (e.g. `**/*.tf`, `infra/**`).
This is the Copilot analog of the Claude SessionStart hook's `inject-when` trait
gating; the same rule source drives both, and a scoped rule is **excluded** from
the flat file so it never double-loads. The same generator + drift gate as the
flat instructions (`gen_copilot_instructions.py` / `check_copilot_instructions.py`)
keeps them in sync.

Repo-specific Copilot guidance you author yourself also goes in a *separate*
`*.instructions.md` you own — never edit the steer-generated ones.

## MCP servers in VS Code

Copilot in VS Code does **not** read the plugin's `.mcp.json` (that wires Claude
Code only). So the scaffold ships **`.vscode/mcp.json`** — VS Code's `servers`
schema — mirroring the same servers: the **GitHub** MCP server that
`/steer-tracker-sync` is built around, **markitdown** for PO source docs, and
**context7** for current library docs. The GitHub server prompts once for a PAT
(stored in VS Code secret storage). Without it, Copilot's tracker workflow falls
back to `gh` only.

Like the other Copilot artifacts, this file is **generated** — `gen_copilot_mcp.py`
renders it from the plugin's `.mcp.json` (`mise run gen:copilot`), translating the
one sanctioned difference: the auth placeholder (env var → prompted input, mapped
in the generator's `AUTH_INPUTS`). A byte-equality drift gate
(`check_copilot_mcp.py`, part of `plugin-check`) fails the build if the committed
mirror falls out of sync. Edit `.mcp.json` and regenerate — never hand-edit the
mirror.

## Cloud coding agent (opt-in)

The **GitHub-side Copilot coding agent** (assign it an issue, it works in an
ephemeral environment and opens a PR) reads the same
`.github/copilot-instructions.md` + `.github/instructions/` for standards. To make
it boot a steer repo correctly, the scaffold carries
**`.github/workflows/copilot-setup-steps.yml`** — it installs the pinned mise
toolchain and runs `dev:setup`. The job name `copilot-setup-steps` is required;
MCP + firewall for the agent are set in repo **Settings → Copilot → Coding agent**,
not in-repo.

It is **opt-in** — `/steer:init` does not install it automatically; add it only
for repos that use the coding agent. It fits steer's autonomous-loop rules: the
coding agent opens draft PRs and never merges, so the human merge gate stands.
Point it only at PR-flow repos (protected `main`), never solo-trunk.

## Gate hooks on Copilot

The Copilot CLI manifest points hooks at a **Copilot-native** file
(`hooks/copilot-hooks.json`) rather than letting Copilot fall back to Claude's
`hooks/hooks.json` — important because Copilot's `preToolUse` hooks are
**fail-closed** (a hook that errors *denies* the tool), so a mis-run Claude hook
could block edits.

Two gates are ported so far, both surfacing as a soft **`ask`** (Copilot prompts
you to confirm): the **version-pin policy** (`check-version-pins.sh`, a hard
`deny` on Claude softened to `ask` here) and the **trunk-push graduation gate**
(`check-bash-actions.sh`, an `ask` on both surfaces). The same hook logic runs on
both surfaces; each emits Copilot's flat `permissionDecision` envelope when
invoked with `STEER_HOOK_TARGET=copilot`. The advisory spec-first / issue-first
nudges — and the issue-create contract guard that also lives in
`check-bash-actions.sh` — are **not** ported as hooks (Copilot's `preToolUse`
cannot inject non-blocking context); their intent is carried by the standards in
`.github/copilot-instructions.md`.

`copilot-hooks.json` is **generated** from `hooks.json` by `gen_copilot_hooks.py`
(`mise run gen:copilot`): the ported subset is declared in the generator's
`COPILOT_HOOKS` table, and it reshapes each selected hook into Copilot's flat
schema — adding `STEER_HOOK_TARGET=copilot` and the fail-open `|| true`, and
mapping `timeout` → `timeoutSec`. It is emitted as **strict JSON** (no header
comment), because the Copilot CLI hook parser is not documented to accept JSONC —
unlike the VS Code `mcp.json` mirror, which is JSONC. A byte-equality drift gate
(`check_copilot_hooks.py`, part of `plugin-check`) fails the build if the
committed manifest drifts, and additionally verifies each referenced script still
exists on disk. Renaming, dropping, or retiming a hook script on the Claude side
then fails the build until you regenerate, instead of silently leaving the Copilot
manifest pointing at a dead path.

**VS Code has no hook mechanism at all** — the gates are Copilot-CLI-only. In VS
Code the version-pin and trunk-push policies live only as text in the standards.

## Known limitations

- **Skill enforcement/invocation differs.** See [Skills on Copilot](#skills-on-copilot)
  — tool-permission scoping is inert and skill bodies are intent capsules (though
  the `steer-reviewer` subagent now ports as a [custom agent](#custom-agents-on-copilot)).
- **Two gates, soft, CLI-only.** Only the version-pin and trunk-push graduation
  gates are ported, as `ask`s, and only on the Copilot CLI. VS Code gets no
  hooks. The advisory nudges live in the standards text, not as hooks.
- **Manual refresh.** Unlike Claude Code's live injection, the Copilot files must
  be regenerated after a plugin update (see above).
- **Hooks are Preview.** Copilot's plugin hooks are Preview and can be disabled
  by org policy, so the standards delivery never depends on them; the Copilot
  hook is hardened to fail **open** (it can never block an edit on error).
