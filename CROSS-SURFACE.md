# Cross-surface integration strategy — `steer` beyond Claude Code CLI

> **Status:** strategy / findings, **validated June 2026**, with the skills row
> re-validated August 2026. No code changes proposed here — this is the map for
> deciding follow-up work.

> **August 2026 correction — the skills layer is no longer Claude-shaped.** This
> document's original premise was that `SKILL.md` is a Claude Code format, so other
> agents needed a per-surface *rendering* (which is why the Copilot target shipped
> lossy `.github/prompts/*.prompt.md` intent capsules). That premise is now wrong:
> [Agent Skills](https://agentskills.io) is an open standard, and GitHub Copilot,
> Cursor, Gemini CLI and Codex all discover project skills from **`.agents/skills/`**.
> steer therefore ships the **real skill bodies** to one cross-tool tree instead of
> a capsule per surface — see [`docs/concepts/copilot-support.md`](docs/concepts/copilot-support.md)
> → "Skills on Copilot". The *hook* layer's analysis below is unaffected. See
> [§6 Verification checklist](#6-verification-checklist) for what to confirm on the
> actual apps.

## 1. TL;DR

`steer` is authored as a **Claude Code plugin**: an always-on `SessionStart` hook
injects `rules/*.md`, `/steer:*` skills run on demand, `PreToolUse`/`Stop` hooks
gate work, and POSIX scripts resolve bundled assets via `${CLAUDE_PLUGIN_ROOT}`.

By mid-2026 "plugins" are a **cross-app concept**, not Claude Code-CLI-only. The
**Claude Desktop app has three tabs — Chat, Cowork, and Code** — and they don't
behave the same. The headline, validated against current docs and changelog:

- **Support is tiered ([§3](#3-support-policy--per-surface-matrix)).** Targeted:
  **Claude Code** — the CLI and IDE extensions (VS Code, JetBrains). Intended: the
  Claude Desktop **Code tab** (full Claude Code engine). Best-effort: **Cowork**
  (PO/knowledge-work only — engineering work is **not** supported there; use Claude
  Code), **the Chat tab + claude.ai web chat** (skills only), and the shipped
  generated **GitHub Copilot** target (CLI + VS Code, prototype scope —
  [§3](#3-support-policy--per-surface-matrix)).
- **The hook-driven core (always-on rules + gates) runs wherever Claude Code runs**
  — including the Claude Desktop **Code tab**, which shares the CLI engine.
- **Cowork is the _one_ chat-family surface where hooks run** — Anthropic's docs
  state *"hooks and sub-agents run only in Cowork."* (Plugin-scoped `SessionStart`
  had 2026 bugs, since closed — [§4](#4-where-the-hook-layer-runs); reconfirm.)
- **The Chat tab and claude.ai web chat do _not_ run hooks** (grayed out). Plugins
  install and **skills + MCP work**, but the always-on rules don't inject — load
  them by hand with `/steer:standards`.
- **The portable nucleus is skills (`SKILL.md`) + MCP.** Skills work on every
  surface that loads plugins at all. **MCP is more conditional than it looks:** the
  chat-family surfaces (Cowork, Chat, web) don't read the plugin `.mcp.json` and
  wire MCP through their own **Connectors** — and **Cowork is a no-install sandbox**
  (no docker/mise/`gh`), so the shipped `github` server doesn't work
  there; GitHub triage needs the **built-in GitHub
  connector** ([§4a](#4a-cowork-is-a-no-install-sandbox)).

> **What changed since the first draft:** earlier text (built on Jan-2026 data and
> the repo's then-current `known-limitations.md`) said hooks "don't fire on Cowork
> or the desktop app." The June-2026 validation corrects that: hooks fire on the
> **Code tab** and, per docs, in **Cowork**; only the **Chat tab / web chat** lack
> them. `known-limitations.md` was updated to match.

## 2. How `steer` is built — the coupling map

| Component | Files | Runtime dependency | Portable? |
|---|---|---|---|
| **Always-on core** | `rules/00-router.md` … `95-not-the-gate.md` (5 files) | Delivered via `SessionStart` hook → stdout `additionalContext`, which Claude Code caps at **10,000 characters** — the core is sized to fit it whole | Prose is portable; **delivery is hook-bound** |
| **Path-scoped rules** | `templates/scaffold/claude/rules/steer-*.md` (30 files) | Installed into the consumer repo as `.claude/rules/steer-*.md` by `/steer:init` / `/steer:adopt`, repaired by `/steer:sync` (capability `path-scoped-rules`); each loads when Claude reads a file its `paths:` frontmatter matches | Prose is portable; **delivery is repo-bound**, not hook-bound — a repo that never adopted them never gets them |
| **SessionStart hooks** | `inject-standards.sh`, `orient-session.sh`, `session-checks.sh` (orchestrates `check-template-drift.sh`, `check-open-questions.sh`, `check-unmanaged-repo.sh`, `check-rule-drift.sh`, `surface-faults.sh`, `check-graduation.sh`, `check-worktree-trust.sh` in one registration) | `SessionStart` event; source `${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh` | Claude-Code-runtime |
| **Lifecycle hooks** | `CwdChanged`: `check-worktree-trust.sh` (the same script the SessionStart roster runs — it also fires when a session *enters* a worktree mid-session, which SessionStart cannot see); `SessionEnd`: `on-session-end.sh`; `WorktreeRemove`: `on-worktree-remove.sh` | `CwdChanged` / `SessionEnd` / `WorktreeRemove` events; side effects only — none carries decision control, so none can block; `SessionEnd` and `WorktreeRemove` discard their JSON output fields, `CwdChanged` discards only `continue`. The `SessionEnd` teardown is **best-effort**: that event's 1.5s budget cannot be raised by a plugin-declared timeout | Claude-Code-runtime |
| **Gates** | `PreToolUse`: `check-version-pins.sh`, `check-write-nudges.sh`, `check-bash-actions.sh`; `PostToolUse`: `format-on-write.sh`; `Stop`: `reconcile-issue-first.sh` | `PreToolUse`/`PostToolUse`/`Stop` events, `permissionDecision` output | Mostly Claude-Code-runtime — but `check-version-pins.sh` and `check-bash-actions.sh` are dual-target: with `STEER_HOOK_TARGET=copilot` they emit a Copilot `ask` envelope, wired by `hooks/copilot-hooks.json` on the Copilot CLI. In `check-bash-actions.sh` that covers **check 1 only** (the trunk-push graduation gate); check 2, the issue-create contract guard, needs the `additionalContext` the Copilot envelope has no slot for, so it stays silent there by design. `format-on-write.sh` is Claude-only (non-blocking PostToolUse, no decision to port) |
| **Skills** (26) | `plugins/steer/skills/*` | YAML frontmatter + Markdown body; `/steer:` invocation; `allowed-tools` | **`SKILL.md` is the portable nucleus — now literally so.** The bodies ship verbatim to `.agents/skills/steer-*/`, the Agent Skills standard's interoperable location, read by Copilot / Cursor / Gemini CLI / Codex. What is rewritten: `${CLAUDE_PLUGIN_ROOT}` paths, `/steer:` invocation, the `name` prefix, and the frontmatter narrowing (`when_to_use` folded into the body; the Claude-syntax tool grants and `context` dropped, with a prose restriction note in their place) |
| **MCP** | `tracker-sync` (GitHub MCP → `gh` → manual) | MCP connector | **Already surface-agnostic** |
| **Bundled assets** | `templates/spec/*`, `templates/scaffold/*` | `${CLAUDE_PLUGIN_ROOT}` path resolution | Files portable; path var is runtime-specific |

Read this as two layers: a *portable nucleus* (skills + MCP) that works anywhere
plugins load, and a *hook layer* (always-on rules + gates) that runs only where the
**Claude Code engine** runs (CLI / IDE / Code tab) plus **Cowork**.

There is also one **non-Claude target already shipped**: **GitHub Copilot** (CLI +
VS Code), served not by porting the hook layer but by **build-time generation** —
`mise run gen:copilot` renders the same `rules/` into a committed
`.github/copilot-instructions.md` and the skills into a cross-tool
`.agents/skills/` tree (read by VS Code, Cursor, Gemini CLI and Codex alike) /
a Copilot plugin manifest (`plugins/steer/.github/plugin/plugin.json`, CLI), with the
two CLI-only gates above. See
[`docs/concepts/copilot-support.md`](docs/concepts/copilot-support.md).

## 3. Support policy & per-surface matrix

`steer` is built and tested for the **Claude Code engine**. Support tiers:

- **the always-on core — Targeted (developed & tested against).** **Claude Code** — the
  **CLI** and the **IDE extensions (VS Code, JetBrains)** (the extensions delegate
  to the CLI). Full engine: hooks, always-on rules, gates, skills, and MCP all
  work. Regressions here are **bugs we fix**.
- **Deferred repository rules — Intended (supported, not gated per release).** The Claude Desktop
  **Code tab** ("Claude Code Desktop"). It is full Claude Code (shared engine), so
  hooks / rules / gates / skills / MCP all work — we just don't run it in the
  per-release test matrix. Regressions here we fix; we just don't pre-verify each
  release on it.
- **Tier 3 — Best-effort.** None of these run in the per-release test matrix:
  - **Cowork — PO/knowledge-work only.** Cowork *does* run hooks + sub-agents (the
    one chat-family surface that does, per Anthropic's docs — reconfirm
    *plugin-scoped* `SessionStart` on your build, [§4](#4-where-the-hook-layer-runs)),
    so a PO opening a non-code folder gets the lean **knowledge-work** ruleset and
    the PO-facing skills, and repo-scoped GitHub **triage** works through the
    built-in connector. But Cowork is a **no-install sandbox** that doesn't read the
    plugin `.mcp.json` ([§4a](#4a-cowork-is-a-no-install-sandbox)), so everything
    install-dependent — scaffold install (`init`/`adopt`), docker/mise builds, the
    `uvx`-based document conversion (`mise run convert:doc`), `gh`-CLI tracker
    flows, org-level issue fields —
    **does not work**. **Engineering work is not supported on Cowork: do it in
    Claude Code (CLI / IDE / Code tab).** Treat Cowork as a PO knowledge-work lane,
    not an engineering surface.
  - **Chat tab + claude.ai web chat.** Plugins install and the portable nucleus
    (skills + MCP) works; **hooks and sub-agents are grayed out** — no always-on
    rules, no gates. Use `/steer:standards` to load rules by hand.
  - **GitHub Copilot (CLI + VS Code) — shipped, prototype scope.** Not a Claude
    surface at all: the standards and skills reach Copilot as **generated,
    committed artifacts** (`.github/copilot-instructions.md`,
    the cross-tool `.agents/skills/` tree, the Copilot plugin manifest
    `plugins/steer/.github/plugin/plugin.json`) rendered from the same `rules/` + `skills/` by
    `mise run gen:copilot` — including the `steer-reviewer` subagent as
    `.github/agents/steer-reviewer.agent.md` — plus two CLI-only gates
    (`hooks/copilot-hooks.json`: the version-pin and bash-action `ask`s). VS Code
    has no hook mechanism. See [`docs/concepts/copilot-support.md`](docs/concepts/copilot-support.md).

| Surface | Tier | Plugin install | Hooks (rules + gates) | Skills | MCP |
|---|---|---|---|---|---|
| Claude Code **CLI** | **1 — targeted** | ✅ | ✅ | ✅ | ✅ |
| **IDE extensions** (VS Code, JetBrains) | **1 — targeted** | ✅ via CLI | ✅ via CLI | ✅ | ✅ |
| Claude Desktop **Code tab** (Claude Code Desktop) | **2 — intended** | ✅ same engine as CLI | ✅ full engine | ✅ | ✅ |
| Claude Desktop **Cowork tab** | **3 — best-effort (PO only)** | ✅ from GitHub marketplace | ✅ docs: "run only in Cowork" — ⚠️ reconfirm plugin scope ([§4](#4-where-the-hook-layer-runs)) | ✅ (skills are install-free) — but **engineering work unsupported; use Claude Code** | ⚠️ **built-in connector only** — the plugin `.mcp.json` `github` server **doesn't work** in the no-install sandbox ([§4a](#4a-cowork-is-a-no-install-sandbox)) |
| Claude Desktop **Chat tab** + **claude.ai** web chat | **3 — best-effort** | ✅ (chat) / ✅ as org Skills (web) | ❌ grayed out — use `/steer:standards` | ✅ | ⚠️ via the surface's own connector, not the plugin `.mcp.json` |
| **GitHub Copilot** — **CLI** + **VS Code** | **3 — best-effort (prototype scope)** | ✅ CLI: `copilot plugin install steer@e22-plugins` (Copilot manifest) / VS Code: reads the committed `.github/` artifacts, no install | ⚠️ **generated, not hooked** — rules ship as committed `.github/copilot-instructions.md`; two gates (`copilot-hooks.json` version-pin + bash-action, soft `ask`, CLI-only; VS Code has no hooks) | ✅ CLI via the plugin manifest; VS Code (and Cursor / Gemini CLI / Codex) from the committed `.agents/skills/` tree as `/steer-<skill>`; `steer-reviewer` ported as a custom agent | ⚠️ Copilot's own MCP config — the plugin `.mcp.json` is Claude-Code-only |

Legend: ✅ works · ⚠️ works with a caveat / reconfirm · ❌ not available / does not fire.

> **Cowork is a no-install sandbox.** Cowork runs in an Anthropic-managed Linux
> VM where you generally **cannot install docker, mise, language toolchains, or
> `gh`**, and which doesn't read the CLI's plugin `.mcp.json`. GitHub access there
> comes from Cowork's **built-in GitHub connector** (Customize → Connectors), not
> the plugin server — see [§4a](#4a-cowork-is-a-no-install-sandbox) and the
> authoritative [Known limitations → Claude Cowork's sandbox](docs/reference/known-limitations.md#claude-coworks-sandbox-no-installs-connector-only-github).

Org-wide deployment differs by surface: managed settings (the Claude Code
surfaces), per-user install today with org-wide sharing "coming" (Cowork), and
admin-provisioned Skills on Team/Enterprise (claude.ai web). See
[§5](#5-recommendations-per-surface).

## 4. Where the hook layer runs

`steer`'s core value — **always-on rules** — rides a plugin `SessionStart` hook
that surfaces `hookSpecificOutput.additionalContext` to the model; the
`PreToolUse`/`Stop` gates use the same plugin-hook lifecycle. Validated June 2026:

- **Runs:** Claude Code CLI, IDE extensions, and the Claude Desktop **Code tab**
  (shared engine). The earlier "plugin `SessionStart` `additionalContext` silently
  discarded" defect ([anthropics/claude-code#45438](https://github.com/anthropics/claude-code/issues/45438))
  was **fixed (closed COMPLETED, 2026-04-08)**, and the changelog shows
  `SessionStart` `additionalContext` / `reloadSkills` / `sessionTitle` as live
  features.
- **Runs (per docs), reconfirm:** **Cowork.** Anthropic's
  [Use plugins in Claude](https://support.claude.com/en/articles/13837440-use-plugins-in-claude)
  states *"hooks and sub-agents run only in Cowork, [so] they appear grayed out in
  chat."* Plugin-scoped `SessionStart` in Cowork was reported broken earlier in
  2026 (e.g. [#27398](https://github.com/anthropics/claude-code/issues/27398) —
  `--setting-sources user` excluding plugin scope), now **closed as duplicate with
  no open canonical** — likely resolved, but "closed-as-duplicate" ≠ "verified," so
  reconfirm on your build before relying on auto-injected rules there.
- **Does not run:** the Claude Desktop **Chat tab** and **claude.ai web chat** —
  hooks/sub-agents are grayed out by design. Skills + MCP still work.

Two latent fragilities worth a defensive guard if we ever harden the hooks:
the older, still-**open** [#12151](https://github.com/anthropics/claude-code/issues/12151)
(broader "plugin hook output not captured"), and `${CLAUDE_PLUGIN_ROOT}` being
unset during `SessionStart` ([#27145](https://github.com/anthropics/claude-code/issues/27145),
closed-as-duplicate) — if that recurs, every steer SessionStart script fails at the
`. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"` line.

**Mitigation:** where the rules didn't auto-load (Chat tab, web chat, or any
Cowork build where plugin hooks don't fire), run `/steer:standards` at session
start and rely on human review where the gates would have fired.

### 4a. Cowork is a no-install sandbox

The hook layer is one constraint; the **runtime environment** is another, and it
bites the *portable* nucleus too. Cowork runs in an **Anthropic-managed,
sandboxed Linux VM** (OS-level isolation, bubblewrap/seatbelt). Inside the
connected folder Claude can read/write/run scripts, but the sandbox's filesystem
and network are locked down, so in practice you **cannot install system tooling**
— docker, mise, language toolchains, the `gh` CLI (validated June 2026). Two
knock-on effects correct the earlier "MCP is surface-agnostic" optimism of
[§2](#2-how-steer-is-built--the-coupling-map):

- **The plugin `.mcp.json` is not Cowork's MCP source.** MCP config isn't shared
  across surfaces — Cowork wires MCP through its own **Connectors**, not the CLI's
  plugin `.mcp.json`. So the shipped `github` server (auth via `${user_config.github_pat}`
  from a *shell* the sandbox doesn't have) can't authenticate and may be silently
  disabled ("disabled in your connector settings"). Only a plain hosted HTTP server
  with no token (e.g. `context7`) routes through. (steer ships no local-process MCP
  server at all now — `markitdown` was retired for the on-demand `convert:doc`
  task, which the sandbox equally cannot run since it has no `uvx`.)
- **GitHub triage still works — via the built-in connector.** Enable Cowork's
  **built-in GitHub connector** (Customize → Connectors); it's Anthropic-managed
  OAuth that runs *outside* the bash sandbox and exposes the repo-scoped issue
  tools `/steer:tracker-sync`'s MCP-first probe looks for. It is **repo-scoped**,
  so org-level reads (Issue Types, native Priority/Effort fields) come back empty
  and degrade to markers / human follow-up. The `gh`-CLI fallback is unavailable.

This is documented authoritatively in
[Known limitations → Claude Cowork's sandbox](docs/reference/known-limitations.md#claude-coworks-sandbox-no-installs-connector-only-github).

## 5. Recommendations per surface

### Claude Code — CLI & IDE extensions (the always-on core)
Full engine; `steer` works as-is. The IDE extensions delegate to the CLI, so hooks,
rules, gates, skills, and MCP all apply. No adaptation needed — this is the
reference experience.

### Claude Desktop Code tab (the deferred tier)
The **Code tab** ("Claude Code Desktop") is full Claude Code — it shares CLI
settings, so install/enable once and the whole engine applies; we keep it at the deferred tier
only because it sits outside the per-release test matrix.

### Cowork — PO/knowledge-work only (Tier 3)
**Cowork is a best-effort, PO/knowledge-work surface, not an engineering one** —
its sandbox can't install anything (see below), so do all build/tracker/infra work
in Claude Code (CLI / IDE / Code tab). What Cowork is genuinely good for: a product
owner working a connected folder of specs/docs and triaging issues.

To set it up, add the `steer` GitHub marketplace via **Customize → Plugins**.
The official Plugins Reference confirms the full hook lifecycle (`SessionStart`,
`PreToolUse`, `Stop`) runs in the Cowork tab — the "hooks and sub-agents run only
in Cowork" line means they fire here and are grayed out only in the plain **Chat**
tab — so the always-on rules inject. A PO typically opens a **non-code connected
folder** (specs/docs, no git repo); steer detects this as **knowledge-work mode**
and injects a **lean, PO-relevant ruleset** (skipping the code/infra/tracker rules)
plus a plain-language confirmation that standards are active (see
[Known limitations → Knowledge-work mode](docs/reference/known-limitations.md)). If
a build ever fails to fire the hook, fall back to `/steer:standards`. Highest-value
pieces for non-technical POs are the **PO-facing skills**, which are self-contained
regardless of hooks:

- **PO-appropriate:** `setup`, `build`, `spec`, `intake`, `questions`, `next`,
  `explain`, `status`, `issues`, `roadmap`, `reference`, `standards`, `help`.
- **Engineer-oriented (likely noise for POs):** `adopt`, `init`, `adr`, `audit`,
  `loop`, `spec-scaffold`, `sync`, `tidy`, `tracker-sync`, `protect`, `work`,
  `doctor`, `report`.

Rollout caveat: org-wide plugin **sharing is per-user today** ("coming"), so the
first wave is manual install.

**No-install reality (do this before expecting tracker work).** Cowork's sandbox
can't install docker/mise/`gh` and doesn't read the plugin `.mcp.json`
([§4a](#4a-cowork-is-a-no-install-sandbox)), so the shipped `github`
MCP server doesn't work there. For GitHub **issue triage** — the realistic Cowork
tracker use case — enable the **built-in GitHub connector** (Customize →
Connectors); `/steer:tracker-sync` then takes its MCP path through that connector
(repo-scoped: triage/label/comment/state work; org-level Issue Types and
Priority/Effort fields degrade). Reserve the install-dependent flows
(docker/mise builds, local MCP, `gh`-CLI paths) for the Claude Code CLI / Code tab.

### Chat tab + claude.ai web chat (Tier 3)
No hooks. Path:
1. Plugins install in the Chat tab; on claude.ai web, provision steer's portable
   skills as **org-wide Skills** (Team/Enterprise admin).
2. Add **GitHub MCP** as a remote **connector** (mirrors `tracker-sync`'s MCP path).
3. Since the always-on rules can't inject, run **`/steer:standards`** per session,
   or capture a **condensed standards digest** as a Skill / Project
   custom-instruction. This is the one place the always-on model has no native
   equivalent.

### Cross-cutting
Keep skills surface-agnostic: lean on the plain-Markdown body and avoid hard
`${CLAUDE_PLUGIN_ROOT}` assumptions in skill *prose*. The `/steer:standards`
manual-load is the graceful-degradation path wherever hooks don't run.

## 6. Verification checklist

Run on each app and record results back into the
[§3 matrix](#3-support-policy--per-surface-matrix):

- [ ] **Code tab** — start a fresh session; ask "what engineering rules are
      active?" → expect the `00-router` ruleset (hooks fired).
- [ ] **Cowork** — start a fresh session; check whether the rules auto-injected.
      If **yes**, plugin-scoped `SessionStart` works there; if **no**, run
      `/steer:standards` and note it in the matrix.
- [ ] **`PreToolUse` gate** (Code tab / Cowork) — attempt a mutation that
      `check-write-nudges.sh` should advise on (issue-first dimension).
- [ ] **Chat tab / web chat** — confirm hooks are grayed out (rules *not*
      injected), then confirm `/steer:standards` loads them.
- [x] **Skills + MCP** (all surfaces) — run `/steer:next` and confirm
      `tracker-sync` finds the GitHub MCP connector. **Cowork result (June 2026):**
      the plugin `.mcp.json` `github` server does **not** authenticate (no
      user config not read by Cowork) and the `gh` fallback can't
      install — `tracker-sync` finds MCP issue tools **only** when the **built-in
      GitHub connector** is enabled (Customize → Connectors). See
      [§4a](#4a-cowork-is-a-no-install-sandbox). On the CLI both paths work as before.

## 7. Out of scope (this pass)

No hook hardening and no MCP packaging. Those remain follow-ups this doc
recommends and sizes — to be decided after the checklist results come back. The
third follow-up the first draft listed here — a **skills-only distribution
build** — has since **shipped**, and then got simpler: `mise run gen:copilot`
emits the committed `.github/copilot-instructions.md` plus a cross-tool
`.agents/skills/` tree carrying the real skill bodies, which Copilot, Cursor,
Gemini CLI and Codex all read from the same place (see
[`docs/concepts/copilot-support.md`](docs/concepts/copilot-support.md)).

---

### Sources
- **Surface × capability (current):**
  [Use plugins in Claude](https://support.claude.com/en/articles/13837440-use-plugins-in-claude)
  ("hooks and sub-agents run only in Cowork") and
  [Claude Desktop — Code tab](https://code.claude.com/docs/en/desktop) (the
  three-tab structure; the Code tab is full Claude Code).
- **Hook-behavior bug history:** claude-code issues
  [#45438](https://github.com/anthropics/claude-code/issues/45438) (fixed, 2026-04-08),
  [#12151](https://github.com/anthropics/claude-code/issues/12151) (open),
  [#27398](https://github.com/anthropics/claude-code/issues/27398) /
  [#27145](https://github.com/anthropics/claude-code/issues/27145) (closed-as-duplicate);
  Claude Code changelog (`SessionStart` `additionalContext` / `reloadSkills` /
  `sessionTitle`).
- **Authoritative in-repo statement:**
  [`docs/reference/known-limitations.md`](docs/reference/known-limitations.md)
  ("Where hooks fire").
- This repo: `plugins/steer/hooks/hooks.json`, `plugins/steer/skills/*`,
  `plugins/steer/rules/*`, root `CLAUDE.md`, `README.md`.
