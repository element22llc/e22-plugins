# Cross-surface integration strategy — `steer` beyond Claude Code CLI

> **Status:** strategy / findings, **validated June 2026**. No code changes
> proposed here — this is the map for deciding follow-up work. See
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
  Code) and **the Chat tab + claude.ai web chat** (skills only).
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
  (no docker/mise/`gh`), so the shipped `${GITHUB_PAT}` `github` and local-process
  `markitdown` servers don't work there; GitHub triage needs the **built-in GitHub
  connector** ([§4a](#4a-cowork-is-a-no-install-sandbox)).

> **What changed since the first draft:** earlier text (built on Jan-2026 data and
> the repo's then-current `known-limitations.md`) said hooks "don't fire on Cowork
> or the desktop app." The June-2026 validation corrects that: hooks fire on the
> **Code tab** and, per docs, in **Cowork**; only the **Chat tab / web chat** lack
> them. `known-limitations.md` was updated to match.

## 2. How `steer` is built — the coupling map

| Component | Files | Runtime dependency | Portable? |
|---|---|---|---|
| **Always-on rules** | `rules/00-router.md` … `99-end-of-session.md` (32 files) | Delivered via `SessionStart` hook → stdout `additionalContext`; rules with an `inject-when` marker are scoped to repos where they apply | Prose is portable; **delivery is hook-bound** |
| **SessionStart hooks** | `inject-standards.sh`, `orient-session.sh`, `check-template-drift.sh`, `check-open-questions.sh`, `check-unmanaged-repo.sh`, `surface-faults.sh`, `check-graduation.sh` | `SessionStart` event; source `${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh` | Claude-Code-runtime |
| **Gates** | `PreToolUse`: `check-version-pins.sh`, `check-code-before-spec.sh`, `check-issue-before-mutation.sh`, `check-issue-create-contract.sh`; `Stop`: `reconcile-issue-first.sh` | `PreToolUse`/`Stop` events, `permissionDecision` output | Claude-Code-runtime |
| **Skills** (24) | `plugins/steer/skills/*` | YAML frontmatter + Markdown body; `/steer:` invocation; `allowed-tools` | **`SKILL.md` is the portable nucleus** |
| **MCP** | `tracker-sync` (GitHub MCP → `gh` → manual) | MCP connector | **Already surface-agnostic** |
| **Bundled assets** | `templates/spec/*`, `templates/scaffold/*` | `${CLAUDE_PLUGIN_ROOT}` path resolution | Files portable; path var is runtime-specific |

Read this as two layers: a *portable nucleus* (skills + MCP) that works anywhere
plugins load, and a *hook layer* (always-on rules + gates) that runs only where the
**Claude Code engine** runs (CLI / IDE / Code tab) plus **Cowork**.

## 3. Support policy & per-surface matrix

`steer` is built and tested for the **Claude Code engine**. Support tiers:

- **Tier 1 — Targeted (developed & tested against).** **Claude Code** — the
  **CLI** and the **IDE extensions (VS Code, JetBrains)** (the extensions delegate
  to the CLI). Full engine: hooks, always-on rules, gates, skills, and MCP all
  work. Regressions here are **bugs we fix**.
- **Tier 2 — Intended (supported, not gated per release).** The Claude Desktop
  **Code tab** ("Claude Code Desktop"). It is full Claude Code (shared engine), so
  hooks / rules / gates / skills / MCP all work — we just don't run it in the
  per-release test matrix. Regressions here we fix; we just don't pre-verify each
  release on it.
- **Tier 3 — Best-effort.** Three surfaces, none in the per-release test matrix:
  - **Cowork — PO/knowledge-work only.** Cowork *does* run hooks + sub-agents (the
    one chat-family surface that does, per Anthropic's docs — reconfirm
    *plugin-scoped* `SessionStart` on your build, [§4](#4-where-the-hook-layer-runs)),
    so a PO opening a non-code folder gets the lean **knowledge-work** ruleset and
    the PO-facing skills, and repo-scoped GitHub **triage** works through the
    built-in connector. But Cowork is a **no-install sandbox** that doesn't read the
    plugin `.mcp.json` ([§4a](#4a-cowork-is-a-no-install-sandbox)), so everything
    install-dependent — scaffold install (`init`/`adopt`), docker/mise builds, the
    local `markitdown` server, `gh`-CLI tracker flows, org-level issue fields —
    **does not work**. **Engineering work is not supported on Cowork: do it in
    Claude Code (CLI / IDE / Code tab).** Treat Cowork as a PO knowledge-work lane,
    not an engineering surface.
  - **Chat tab + claude.ai web chat.** Plugins install and the portable nucleus
    (skills + MCP) works; **hooks and sub-agents are grayed out** — no always-on
    rules, no gates. Use `/steer:standards` to load rules by hand.

| Surface | Tier | Plugin install | Hooks (rules + gates) | Skills | MCP |
|---|---|---|---|---|---|
| Claude Code **CLI** | **1 — targeted** | ✅ | ✅ | ✅ | ✅ |
| **IDE extensions** (VS Code, JetBrains) | **1 — targeted** | ✅ via CLI | ✅ via CLI | ✅ | ✅ |
| Claude Desktop **Code tab** (Claude Code Desktop) | **2 — intended** | ✅ same engine as CLI | ✅ full engine | ✅ | ✅ |
| Claude Desktop **Cowork tab** | **3 — best-effort (PO only)** | ✅ from GitHub marketplace | ✅ docs: "run only in Cowork" — ⚠️ reconfirm plugin scope ([§4](#4-where-the-hook-layer-runs)) | ✅ (skills are install-free) — but **engineering work unsupported; use Claude Code** | ⚠️ **built-in connector only** — the plugin `.mcp.json` `${GITHUB_PAT}` `github` server and local-process `markitdown` server **don't work** in the no-install sandbox ([§4a](#4a-cowork-is-a-no-install-sandbox)) |
| Claude Desktop **Chat tab** + **claude.ai** web chat | **3 — best-effort** | ✅ (chat) / ✅ as org Skills (web) | ❌ grayed out — use `/steer:standards` | ✅ | ⚠️ via the surface's own connector, not the plugin `.mcp.json` |

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
  plugin `.mcp.json`. So the shipped `github` server (auth via `${GITHUB_PAT}`
  from a *shell* the sandbox doesn't have) can't authenticate, and the
  local-process `markitdown` server (`uvx`) can't run and may be silently disabled
  ("disabled in your connector settings"). Only a plain hosted HTTP server with no
  token (e.g. `context7`) could route through.
- **GitHub triage still works — via the built-in connector.** Enable Cowork's
  **built-in GitHub connector** (Customize → Connectors); it's Anthropic-managed
  OAuth that runs *outside* the bash sandbox and exposes the repo-scoped issue
  tools `/steer:tracker-sync`'s MCP-first probe looks for. It is **repo-scoped**,
  so org-level reads (Issue Types, native Priority/Effort fields) come back empty
  and degrade to markers / human follow-up. The `gh`-CLI fallback is unavailable.

This is documented authoritatively in
[Known limitations → Claude Cowork's sandbox](docs/reference/known-limitations.md#claude-coworks-sandbox-no-installs-connector-only-github).

## 5. Recommendations per surface

### Claude Code — CLI & IDE extensions (Tier 1)
Full engine; `steer` works as-is. The IDE extensions delegate to the CLI, so hooks,
rules, gates, skills, and MCP all apply. No adaptation needed — this is the
reference experience.

### Claude Desktop Code tab (Tier 2)
The **Code tab** ("Claude Code Desktop") is full Claude Code — it shares CLI
settings, so install/enable once and the whole engine applies; we keep it at Tier 2
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
  `explain`, `issues`, `roadmap`, `reference`, `standards`, `help`.
- **Engineer-oriented (likely noise for POs):** `adopt`, `init`, `adr`, `audit`,
  `spec-scaffold`, `sync`, `tidy`, `tracker-sync`, `protect`, `work`, `doctor`,
  `report`.

Rollout caveat: org-wide plugin **sharing is per-user today** ("coming"), so the
first wave is manual install.

**No-install reality (do this before expecting tracker work).** Cowork's sandbox
can't install docker/mise/`gh` and doesn't read the plugin `.mcp.json`
([§4a](#4a-cowork-is-a-no-install-sandbox)), so the shipped `github`/`markitdown`
MCP servers don't work there. For GitHub **issue triage** — the realistic Cowork
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
      `check-issue-before-mutation.sh` should advise/deny.
- [ ] **Chat tab / web chat** — confirm hooks are grayed out (rules *not*
      injected), then confirm `/steer:standards` loads them.
- [x] **Skills + MCP** (all surfaces) — run `/steer:next` and confirm
      `tracker-sync` finds the GitHub MCP connector. **Cowork result (June 2026):**
      the plugin `.mcp.json` `github` server does **not** authenticate (no
      `${GITHUB_PAT}` shell, config not read by Cowork) and the `gh` fallback can't
      install — `tracker-sync` finds MCP issue tools **only** when the **built-in
      GitHub connector** is enabled (Customize → Connectors). See
      [§4a](#4a-cowork-is-a-no-install-sandbox). On the CLI both paths work as before.

## 7. Out of scope (this pass)

No hook hardening, no skills-only distribution build, no MCP packaging. Those are
follow-ups this doc recommends and sizes — to be decided after the checklist
results come back.

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
