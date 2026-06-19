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
  Claude Desktop **Code tab** and **Cowork**. Best-effort: **the Chat tab +
  claude.ai web chat.**
- **The hook-driven core (always-on rules + gates) runs wherever Claude Code runs**
  — including the Claude Desktop **Code tab**, which shares the CLI engine.
- **Cowork is the _one_ chat-family surface where hooks run** — Anthropic's docs
  state *"hooks and sub-agents run only in Cowork."* (Plugin-scoped `SessionStart`
  had 2026 bugs, since closed — [§4](#4-where-the-hook-layer-runs); reconfirm.)
- **The Chat tab and claude.ai web chat do _not_ run hooks** (grayed out). Plugins
  install and **skills + MCP work**, but the always-on rules don't inject — load
  them by hand with `/steer:standards`.
- **The portable nucleus is skills (`SKILL.md`) + MCP.** Those work on every
  surface that loads plugins at all.

> **What changed since the first draft:** earlier text (built on Jan-2026 data and
> the repo's then-current `known-limitations.md`) said hooks "don't fire on Cowork
> or the desktop app." The June-2026 validation corrects that: hooks fire on the
> **Code tab** and, per docs, in **Cowork**; only the **Chat tab / web chat** lack
> them. `known-limitations.md` was updated to match.

## 2. How `steer` is built — the coupling map

| Component | Files | Runtime dependency | Portable? |
|---|---|---|---|
| **Always-on rules** | `rules/00-router.md` … `99-end-of-session.md` (24 files) | Delivered via `SessionStart` hook → stdout `additionalContext` | Prose is portable; **delivery is hook-bound** |
| **SessionStart hooks** | `inject-standards.sh`, `orient-session.sh`, `check-template-drift.sh`, `check-open-questions.sh`, `check-unmanaged-repo.sh`, `surface-faults.sh` | `SessionStart` event; source `${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh` | Claude-Code-runtime |
| **Gates** | `PreToolUse`: `check-version-pins.sh`, `check-code-before-spec.sh`, `check-issue-before-mutation.sh`; `Stop`: `reconcile-issue-first.sh` | `PreToolUse`/`Stop` events, `permissionDecision` output | Claude-Code-runtime |
| **Skills** (21) | `plugins/steer/skills/*` | YAML frontmatter + Markdown body; `/steer:` invocation; `allowed-tools` | **`SKILL.md` is the portable nucleus** |
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
  **Code tab** ("Claude Code Desktop") and **Cowork**. The Code tab is full Claude
  Code (shared engine), so hooks / rules / gates / skills / MCP all work — we just
  don't run it in the per-release test matrix. **Cowork** is, per Anthropic's docs,
  the one chat-family surface that runs hooks + sub-agents; the open caveat is
  whether *plugin-scoped* `SessionStart` fires (see
  [§4](#4-where-the-hook-layer-runs)) — reconfirm before relying on auto-injected
  rules.
- **Tier 3 — Best-effort.** The Claude Desktop **Chat tab** and **claude.ai web
  chat**. Plugins install and the portable nucleus (skills + MCP) works; **hooks
  and sub-agents are grayed out** — no always-on rules, no gates. Use
  `/steer:standards` to load rules by hand. No per-release testing commitment.

| Surface | Tier | Plugin install | Hooks (rules + gates) | Skills | MCP |
|---|---|---|---|---|---|
| Claude Code **CLI** | **1 — targeted** | ✅ | ✅ | ✅ | ✅ |
| **IDE extensions** (VS Code, JetBrains) | **1 — targeted** | ✅ via CLI | ✅ via CLI | ✅ | ✅ |
| Claude Desktop **Code tab** (Claude Code Desktop) | **2 — intended** | ✅ same engine as CLI | ✅ full engine | ✅ | ✅ |
| Claude Desktop **Cowork tab** | **2 — intended** | ✅ from GitHub marketplace | ✅ docs: "run only in Cowork" — ⚠️ reconfirm plugin scope ([§4](#4-where-the-hook-layer-runs)) | ✅ | ✅ |
| Claude Desktop **Chat tab** + **claude.ai** web chat | **3 — best-effort** | ✅ (chat) / ✅ as org Skills (web) | ❌ grayed out — use `/steer:standards` | ✅ | ✅ |

Legend: ✅ works · ⚠️ documented but reconfirm · ❌ not available / does not fire.

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

## 5. Recommendations per surface

### Claude Code — CLI & IDE extensions (Tier 1)
Full engine; `steer` works as-is. The IDE extensions delegate to the CLI, so hooks,
rules, gates, skills, and MCP all apply. No adaptation needed — this is the
reference experience.

### Claude Desktop Code tab + Cowork (Tier 2)
The **Code tab** ("Claude Code Desktop") is full Claude Code — it shares CLI
settings, so install/enable once and the whole engine applies; we keep it at Tier 2
only because it sits outside the per-release test matrix.

For **Cowork**, add the `steer` GitHub marketplace via **Customize → Plugins**. Per
docs, hooks run here, so the always-on rules *should* inject — but **reconfirm
plugin-scoped `SessionStart`** ([§6](#6-verification-checklist)); if it doesn't fire
on your build, fall back to `/steer:standards`. Highest-value pieces for
non-technical POs are the **PO-facing skills**, which are self-contained regardless
of hooks:

- **PO-appropriate:** `build`, `spec`, `questions`, `next`, `issues`,
  `design-sources`, `standards`.
- **Engineer-oriented (likely noise for POs):** `adopt`, `init`, `adr`, `audit`,
  `conventions`, `drift`, `spec-scaffold`, `sync`, `tidy`, `traceability`,
  `tracker-sync`, `protect`, `work`.

Rollout caveat: org-wide plugin **sharing is per-user today** ("coming"), so the
first wave is manual install.

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
- [ ] **Skills + MCP** (all surfaces) — run `/steer:next` and confirm
      `tracker-sync` finds the GitHub MCP connector.

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
