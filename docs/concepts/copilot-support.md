# GitHub Copilot support

steer is built for Claude Code, but teammates who use **GitHub Copilot** — either
the **Copilot CLI** or **Copilot in VS Code** — can pick up the same org
engineering standards. This page explains how all surfaces share one source of
truth and how to install and refresh the Copilot side.

!!! note "Scope"
    The Copilot target covers the **always-on standards**
    (`.github/copilot-instructions.md`, read by both the CLI and VS Code), the
    **skills** (as cross-tool `SKILL.md` on the CLI, and as
    `.agents/skills/steer-*/` in the open Agent Skills format, read by every
    non-Claude agent), **custom agents**
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
| Path-scoped standards | rule `inject-when` traits | **not delivered** — emitted only to `.github/instructions/` (see below) | `.github/instructions/*.instructions.md` (`applyTo` glob) |
| Skills | plugin `skills/` (`/steer:<skill>`) | plugin `skills/` via Copilot manifest | `.agents/skills/steer-*/` (`/steer-<skill>`) |
| Subagents | plugin `agents/` | **not declared** — the Copilot manifest carries `skills` + `hooks` only | `.github/agents/*.agent.md` (agent picker) |
| MCP servers | plugin `.mcp.json` | **not declared** — the Copilot manifest has no `mcpServers` key | `.vscode/mcp.json` |
| Cloud coding agent | — (Claude `@claude` workflow) | — | `.github/workflows/copilot-setup-steps.yml` (opt-in) |
| Gate hooks | `hooks/hooks.json` (`deny` on version pins, `ask` on the trunk-push gate) | `hooks/copilot-hooks.json` (softened to `ask`) | none (no hook mechanism) |
| Source of truth | `rules/*.md` + `skills/` + `agents/` | the **same** `rules/` + `skills/` + `agents/` | the **same** `rules/` + `skills/` + `agents/` |

Every Copilot artifact — instructions, the cross-tool `.agents/skills/` tree, custom agents, the
VS Code `mcp.json`, the CLI hook manifest, and the plugin + marketplace manifest
versions — is generated from that one source and guarded by a build-time **drift
gate** (see [below](#why-the-surfaces-differ)) that fails the build the moment a
committed artifact drifts. A **symmetry meta-gate** (`check_copilot_symmetry.py`,
part of `plugin-check`) further asserts every `gen_copilot_*.py` is wired into
`gen:copilot` and every `check_copilot_*.py` into `plugin-check` — so a generator
no task runs, or a gate no task invokes, fails the build. It asserts *wiring*, not
generator↔gate pairing: `gen_copilot_manifests.py` has no `check_copilot_manifests.py`
counterpart, because the manifest versions are gated by `check_plugin.py`'s
version-sync check instead. No Copilot artifact is hand-maintained.

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
same generator step also renders the cross-tool skill tree (below), with its own
drift gate (`check_agent_skills.py`).

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

The standards file and the skill tree are installed by `/steer:init` (new repos)
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
- **Skills** — every steer skill ships as a real `SKILL.md` under
  `.agents/skills/steer-<skill>/`, one of the three project-skill locations VS Code
  discovers (alongside `.github/skills/` and `.claude/skills/`). Each is surfaced in
  Chat as a `/steer-<skill>` slash-command. Type `/steer-` in Chat to see them.
  Nothing in `.vscode/settings.json` gates this — skill discovery is on by default.

The bundled `.vscode/settings.json` sets both settings explicitly, so the
standards load regardless of a teammate's VS Code defaults.

## Refreshing after a steer update

The Copilot files are a **static snapshot**, so they go stale when steer's rules
or skills change. Refresh them with **`/steer:sync`** from Claude Code:

```shell
copilot plugin update steer       # CLI only: pull the new plugin version
# then, from Claude Code in the repo:
/steer:sync                       # re-copies copilot-instructions.md,
                                  # .agents/skills/, agents/, instructions/
/steer:sync --check               # read-only: reports the surface as mis-wired
                                  # when it has fallen behind
```

`/steer:sync` owns this because the refresh is a **capability repair**:
`agent-surface-current` is wired only when every generated file is
byte-identical to its plugin source, and the repair is a verbatim re-copy.
**`/steer:init` is not the refresh path** — it installs the surface at bootstrap
and then deliberately stops on an already-initialized repo, so re-running it does
nothing.

Because Copilot has no context-injecting SessionStart hook, this static set *is*
its entire standards surface — so a repo that never refreshes leaves Copilot
teammates working against the rules of whatever plugin version bootstrapped it,
while their Claude Code colleagues are current. Put the refresh on whoever owns
plugin updates; the [launch checklist](../team-rollout/launch-checklist.md) carries
it as a rollout item.

The files are **fully steer-managed** — overwritten on refresh and never
hand-edited. Repo-specific Copilot guidance belongs in a separate
`*.instructions.md` file, not in these; the re-copy never touches a file you own.

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
- **Copilot in VS Code** reads the committed `.agents/skills/` tree. This is not a
  Copilot-specific rendering: `.agents/skills/` is one of the interoperable
  locations defined by the [Agent Skills](https://agentskills.io) open standard, so
  the same tree is discovered by **Cursor**, **Gemini CLI** and **Codex** without
  any further work.

The build renders one `.agents/skills/steer-<skill>/` directory per skill —
including the two `user-invocable: false` gateways, which the model can reach even
though no one can type them — carrying the **real skill body** and its supporting
mode files, not a summary. Three things are rewritten so a body works off Claude
Code (`gen_agent_skills.py`):

| In the authored skill | In the portable copy | Why |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/skills/<self>/modes/x.md` | `modes/x.md` | The file travels with the skill, which is exactly the spec's colocation convention. |
| `${CLAUDE_PLUGIN_ROOT}/templates/reference/…` | a `blob/main` URL on this repo | Shared by many skills; vendoring several hundred KB — `MIGRATIONS.md` alone is the largest single file — into every consumer repo is not worth it, and the repo is public. **These URLs are not currently fetchable** — see [Known limitations](#known-limitations). |
| `/steer:<skill>` | `/steer-<skill>` | Plugin namespacing is Claude Code's; the slash name here is the skill's directory name. |

Two differences from Claude Code remain on **both** Copilot surfaces:

- **Tool-permission scoping is inert.** No non-Claude agent honors steer's
  `allowed-tools` / `disallowed-tools`, and their values are Claude tool syntax
  anyway — so the portable copy **drops** both fields rather than shipping a grant
  that means nothing. A skill that was frontmatter-restricted upstream instead
  opens with an explicit note that the restriction is now **enforced by
  instruction, not by tooling**, so a body reading "the edit tools are unavailable"
  is not mistaken for a guarantee. Treat those skills as advisory there.
- **Hooks do not exist in VS Code**, so nothing gates a skill mid-run.

## Custom agents on Copilot

steer's subagents in the plugin's `agents/` reach VS Code as **custom agents** —
`.github/agents/<name>.agent.md`, selectable from the Copilot Chat agent picker
(this is the format formerly called "custom chat modes"/`.chatmode.md`). Today
that is `steer-reviewer`, the read-only reviewer that `/steer-audit`,
`/steer-work --reviewed` and `/steer-loop` delegate a single bounded slice to.

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

!!! warning "A scoped rule reaches VS Code only"
    Because the exclusion is unconditional (`iter_rule_files` filters `SCOPED_RULES`),
    a path-scoped rule is **not** in `.github/copilot-instructions.md` — today that
    means rule `12-stack-infra`, the IaC stack standards. That directory is read by
    Copilot in VS Code and by the cloud coding agent; whether the Copilot **CLI**
    reads it is unverified here, so a CLI teammate working on Terraform may receive
    no IaC standards. If you need them there, load the file explicitly.

    Do not "fix" this by dropping the rule from `SCOPED_RULES`: that key drives both
    the flat-file exclusion *and* the scoped emission, and `main()` prunes the
    orphaned file — so you would move the rule into every consumer's always-on
    context and delete `infra.instructions.md`, not resolve the gap.

Repo-specific Copilot guidance you author yourself also goes in a *separate*
`*.instructions.md` you own — never edit the steer-generated ones.

## MCP servers in VS Code

Copilot in VS Code does **not** read the plugin's `.mcp.json` (that wires Claude
Code only). So the scaffold ships **`.vscode/mcp.json`** — VS Code's `servers`
schema — mirroring the same servers: the **GitHub** MCP server that the tracker
gateway (`tracker-sync`, reached through `/steer-issues` and `/steer-work` — it is
`user-invocable: false`, so no one types it directly) is built around, and
**context7** for current library docs. The GitHub server prompts once for a PAT
(stored in VS Code secret storage). Without it, Copilot's tracker workflow falls
back to `gh` only.

Like the other Copilot artifacts, this file is **generated** — `gen_copilot_mcp.py`
renders it from the plugin's `.mcp.json` (`mise run gen:copilot`), translating the
one sanctioned difference: the auth placeholder (env var → prompted input, mapped
in the generator's `AUTH_INPUTS`). A byte-equality drift gate
(`check_copilot_mcp.py`, part of `plugin-check`) fails the build if the committed
mirror falls out of sync. Edit `.mcp.json` and regenerate — never hand-edit the
template **in this repo**.

That byte-gate governs the plugin-side template only. Unlike the four artifacts
under `.github/`, the **installed** `.vscode/mcp.json` is not steer-managed: it sits
outside `/steer:sync`'s `agent-surface-current` capability, so a consumer owns
their copy and is expected to merge additively and remove servers they don't use.
Nothing re-copies it over their edits; only a one-shot ledger migration amends it.

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
(`check-bash-actions.sh`, an `ask` on both surfaces). One hook script serves both
surfaces, each emitting Copilot's flat `permissionDecision` envelope when invoked
with `STEER_HOOK_TARGET=copilot` — but the two paths are not identical: the
trunk-push gate's **repeat** push downgrades to a non-blocking `additionalContext`
reminder on Claude and to a **silent allow** under Copilot, which has no
non-blocking channel (`check-bash-actions.sh` — the `STEER_HOOK_TARGET` check on
the marker-present branch). That caveat lives in the `gates` reference doc, not
inline in rule `45-commit-autonomy`, and the generated
`.github/copilot-instructions.md` does **not** carry it either — so it is absent
from the always-on standards both surfaces read. It reaches a reader only on the
**CLI**, which loads the real `reference` skill from the Copilot plugin manifest;
that doc also states a push declined there must not be retried in the hope of a
quieter second attempt. In VS Code the `reference` skill now ships too, as
`.agents/skills/steer-reference/`, so the topic routing travels — though the
pointer it carries is subject to the fetch limitation below — and nothing was lost meanwhile, since VS Code has no hooks and so
never raises the repeat-push decision the caveat is about.
The advisory spec-first / issue-first
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

- **The rewritten shared-file URLs are not fetchable.** The rewrite in the table
  above points at GitHub's HTML `blob/` view rather than `raw.githubusercontent.com`,
  and it is applied inside runnable command lines too, so those ship as
  `sh "https://…"`. Because the rewrite is unconditional, any step that depends on
  reading a shared file or running a shared script is affected — for some skills
  that costs a link, for others the whole procedure. Detail, and what is
  unaffected, in
  [Known limitations](../reference/known-limitations.md#the-cross-tool-agentsskills-tree-shared-bundle-links-are-not-fetchable).
- **Tool-permission scoping is inert.** No non-Claude agent honors steer's
  `allowed-tools` / `disallowed-tools`, and their values are Claude tool syntax
  anyway — so the portable copy **drops** both fields rather than shipping a grant
  that means nothing. A skill that was frontmatter-restricted upstream instead
  opens with an explicit note that the restriction is now **enforced by
  instruction, not by tooling**, so a body reading "the edit tools are unavailable"
  is not mistaken for a guarantee. Treat those skills as advisory there.
- **Hooks do not exist in VS Code**, so nothing gates a skill mid-run.

## Custom agents on Copilot

steer's subagents in the plugin's `agents/` reach VS Code as **custom agents** —
`.github/agents/<name>.agent.md`, selectable from the Copilot Chat agent picker
(this is the format formerly called "custom chat modes"/`.chatmode.md`). Today
that is `steer-reviewer`, the read-only reviewer that `/steer-audit`,
`/steer-work --reviewed` and `/steer-loop` delegate a single bounded slice to.

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

!!! warning "A scoped rule reaches VS Code only"
    Because the exclusion is unconditional (`iter_rule_files` filters `SCOPED_RULES`),
    a path-scoped rule is **not** in `.github/copilot-instructions.md` — today that
    means rule `12-stack-infra`, the IaC stack standards. That directory is read by
    Copilot in VS Code and by the cloud coding agent; whether the Copilot **CLI**
    reads it is unverified here, so a CLI teammate working on Terraform may receive
    no IaC standards. If you need them there, load the file explicitly.

    Do not "fix" this by dropping the rule from `SCOPED_RULES`: that key drives both
    the flat-file exclusion *and* the scoped emission, and `main()` prunes the
    orphaned file — so you would move the rule into every consumer's always-on
    context and delete `infra.instructions.md`, not resolve the gap.

Repo-specific Copilot guidance you author yourself also goes in a *separate*
`*.instructions.md` you own — never edit the steer-generated ones.

## MCP servers in VS Code

Copilot in VS Code does **not** read the plugin's `.mcp.json` (that wires Claude
Code only). So the scaffold ships **`.vscode/mcp.json`** — VS Code's `servers`
schema — mirroring the same servers: the **GitHub** MCP server that the tracker
gateway (`tracker-sync`, reached through `/steer-issues` and `/steer-work` — it is
`user-invocable: false`, so no one types it directly) is built around, and
**context7** for current library docs. The GitHub server prompts once for a PAT
(stored in VS Code secret storage). Without it, Copilot's tracker workflow falls
back to `gh` only.

Like the other Copilot artifacts, this file is **generated** — `gen_copilot_mcp.py`
renders it from the plugin's `.mcp.json` (`mise run gen:copilot`), translating the
one sanctioned difference: the auth placeholder (env var → prompted input, mapped
in the generator's `AUTH_INPUTS`). A byte-equality drift gate
(`check_copilot_mcp.py`, part of `plugin-check`) fails the build if the committed
mirror falls out of sync. Edit `.mcp.json` and regenerate — never hand-edit the
template **in this repo**.

That byte-gate governs the plugin-side template only. Unlike the four artifacts
under `.github/`, the **installed** `.vscode/mcp.json` is not steer-managed: it sits
outside `/steer:sync`'s `agent-surface-current` capability, so a consumer owns
their copy and is expected to merge additively and remove servers they don't use.
Nothing re-copies it over their edits; only a one-shot ledger migration amends it.

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
(`check-bash-actions.sh`, an `ask` on both surfaces). One hook script serves both
surfaces, each emitting Copilot's flat `permissionDecision` envelope when invoked
with `STEER_HOOK_TARGET=copilot` — but the two paths are not identical: the
trunk-push gate's **repeat** push downgrades to a non-blocking `additionalContext`
reminder on Claude and to a **silent allow** under Copilot, which has no
non-blocking channel (`check-bash-actions.sh` — the `STEER_HOOK_TARGET` check on
the marker-present branch). That caveat lives in the `gates` reference doc, not
inline in rule `45-commit-autonomy`, and the generated
`.github/copilot-instructions.md` does **not** carry it either — so it is absent
from the always-on standards both surfaces read. It reaches a reader only on the
**CLI**, which loads the real `reference` skill from the Copilot plugin manifest;
that doc also states a push declined there must not be retried in the hope of a
quieter second attempt. In VS Code the `reference` skill now ships too, as
`.agents/skills/steer-reference/`, so the topic routing travels — though the
pointer it carries is subject to the fetch limitation below — and nothing was lost meanwhile, since VS Code has no hooks and so
never raises the repeat-push decision the caveat is about.
The advisory spec-first / issue-first
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

- **The rewritten shared-file URLs are not fetchable.** The rewrite in the table
  above points at GitHub's HTML `blob/` view rather than `raw.githubusercontent.com`,
  and it is applied inside runnable command lines too, so those ship as
  `sh "https://…"`. Most skills lose only a link, but `steer-standards`,
  `steer-help` and `steer-protect` are *procedurally* dependent on the fetch and
  cannot do their job here — and `steer-standards` reads a **directory** URL, which
  has no raw equivalent. Full detail, and what is unaffected, in
  [Known limitations → the `.agents/skills/` tree](../reference/known-limitations.md).
- **Tool-permission scoping is inert.** See [Skills on Copilot](#skills-on-copilot)
  — the bodies themselves port in full, but a skill that Claude Code restricts via
  `allowed-tools`/`disallowed-tools` carries that restriction here as an
  instruction rather than something the runtime enforces (the `steer-reviewer`
  subagent does port as a [custom agent](#custom-agents-on-copilot)).
- **Two gates, soft, CLI-only.** Only the version-pin and trunk-push graduation
  gates are ported, as `ask`s, and only on the Copilot CLI. VS Code gets no
  hooks. The advisory nudges live in the standards text, not as hooks.
- **Invocation form differs by surface, and the instructions file is shared.**
  `.github/copilot-instructions.md` carries the rules verbatim, so every skill
  cross-reference in them reads `/steer:<skill>`. In VS Code the invocable form is
  `/steer-<skill>` (the `.agents/skills/` tree); on the CLI skills load from the
  plugin manifest. Because one file serves both surfaces, a blanket rewrite would
  be wrong for one of them — the generated file therefore opens with a note stating
  the mapping. The skill-tree artifacts *are* rewritten to the hyphen form by
  `gen_agent_skills.py`.
- **The two ported gates depend on `CLAUDE_PLUGIN_ROOT`.** `copilot-hooks.json`
  builds each script path from that Claude-named variable. Whether the Copilot CLI
  exports it is **unverified** — so treat the gates as *ported, not proven*. They
  are guarded on the resolved path and report `CLAUDE_PLUGIN_ROOT unresolved —
  <script> gate skipped` on stderr rather than silently exiting 0, so an
  unresolved root is diagnosable instead of an invisible no-op. Standards delivery
  never depended on hooks, so this bounds enforcement, not the standards.
- **Polyrepo topology is Claude-only.** Workspace/member role detection is emitted
  by the `orient-session.sh` SessionStart hook, and Copilot has no SessionStart
  equivalent. There is deliberately no always-on polyrepo *rule* for the generator
  to carry, so a Copilot session gets no topology note. Read
  `/steer:reference polyrepo` from Claude Code for the full topology.
- **Worktree `mise trust` inheritance is Claude-only.** `check-worktree-trust.sh`
  runs on two Claude-Code registrations — `SessionStart` and `CwdChanged` — so a
  Copilot session started in *or* entered into a linked worktree does **not**
  inherit the primary checkout's trust, and its first `mise run …` fails on
  *trust*, not on the task — the cost a polyrepo pays per member per feature. The
  standards carry the remedy instead of a hook: rule `24-worktrees` tells the agent
  to run `mise trust` in the worktree before its first `mise run …` and names the
  inheriting check as Claude-Code-only, so no Copilot surface is told trust it does
  not have. `mise trust` is idempotent, so the instruction is also free on Claude
  Code where the check already ran.
- **Worktree *teardown* is Claude-only too.** Stopping a worktree's Docker stack
  is now done by two Claude-Code lifecycle hooks (`SessionEnd` → `docker:down`,
  `WorktreeRemove` → `docker:clean`), and `copilot-hooks.json` registers only the
  two `PreToolUse` gates — so Copilot gets neither. This is exactly the trap this
  page exists to avoid: an unscoped rule asserting a safety net that is not there.
  Rules `24-worktrees` and `99-end-of-session` therefore scope the hook claim to
  Claude Code and leave `mise run docker:clean` as the agent's own job everywhere
  else. (On Claude Code only the `WorktreeRemove` half is dependable; the
  `SessionEnd` half is best-effort — see
  [Hooks → Lifecycle events](../reference/hooks.md#lifecycle-events).)
  What *is* surface-agnostic is the per-worktree `COMPOSE_PROJECT_NAME`/port
  offset: it comes from the scaffold's `mise` config
  (`scripts/worktree-env.sh`), not from a hook.
- **SessionStart *notices* never arrive, so the rules no longer promise them.**
  Beyond the worktree check above, three always-on rules used to tell the agent a
  SessionStart hook would flag a condition: a missing `/spec` spine (rule
  `00-router`), an in-progress `spec/BUILD-STATUS.md` (rule `05-roles`), and
  recorded hook faults (rule `97-self-report`). Copilot's `sessionStart` ignores
  stdout, so the notice never comes — and its *absence* reads as "condition not
  present," which is worse than no promise at all. Each rule now scopes the flag to
  Claude Code and, where there is something a reader could look for themselves
  (rules `00-router` and `05-roles`), says to do that instead; rule `97-self-report`
  only scopes, because recorded hook faults exist on no other surface.
  Likewise rule `10-stack` no longer claims a hook **denies** stale image-major
  pins without qualification: the ported gate only *asks* on the Copilot CLI, and
  VS Code has no hook mechanism, so the rule now says to keep the pins current
  yourself.
- **One further rule scoped, two whose detail moved out, plus one skill.** The same
  sweep, finished. Rule `90-design-sources` pointed at the `frontend-design`
  plugin, which the Copilot marketplace does not list, so it is scoped to Claude
  Code inline. Two others no longer need scoping because the surface-specific
  detail left the rule entirely: rule `62-hotfix` is now surface-neutral about the
  `hotfix/<n>-slug` prefix (the reconciliation it used to name is the `Stop` hook
  `reconcile-issue-first.sh`, which is not ported — only the two `PreToolUse` gates
  are, so on Copilot the prefix carries the convention alone), and rule
  `36-issue-first` no longer enumerates the `allow`/`ask` permission tiers. Those
  tiers are Claude Code's — they live in `.claude/settings.json` and Claude skill
  frontmatter, and are documented in the plugin's `ISSUE-WORKFLOW.md`, which the
  flat Copilot standards file does not carry; Copilot applies its own host
  permissions instead, which is what the rule's surviving text describes. And
  `/steer:questions` leaned on
  `check-open-questions.sh` for both the backlog nudge and the 14-day blocking
  escalation with no alternative — its body now tells any other surface to apply
  that age test by hand.
- **Manual refresh.** Unlike Claude Code's live injection, the Copilot files must
  be regenerated after a plugin update (see above).
- **Hooks are Preview.** Copilot's plugin hooks are Preview and can be disabled
  by org policy, so the standards delivery never depends on them; the Copilot
  hook is hardened to fail **open** (it can never block an edit on error).
