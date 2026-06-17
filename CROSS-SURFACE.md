# Cross-surface integration strategy — `steer` beyond Claude Code CLI

> **Status:** strategy / findings (June 2026). No code changes proposed here — this
> is the map for deciding follow-up work. See [§6 Verification checklist](#6-verification-checklist)
> for what to actually test on the desktop apps.

## 1. TL;DR

`steer` is authored as a **Claude Code plugin**: an always-on `SessionStart` hook
injects `rules/*.md`, `/steer:*` skills run on demand, `PreToolUse`/`Stop` hooks
gate work, and POSIX scripts resolve bundled assets via `${CLAUDE_PLUGIN_ROOT}`.

The landscape shifted in early 2026: **"plugins" are now a cross-app concept**, not
Claude Code-CLI-only. Claude Cowork and Claude Desktop expose **Customize →
Plugins / Skills / Connectors** and can install a plugin marketplace **straight
from a GitHub repo** — the same `marketplace.json` model this repo already ships.

So the headline is good and the caveat is sharp:

- **Support is tiered ([§3](#3-support-policy--per-surface-matrix)).** Targeted:
  Claude Code **CLI + IDE extensions** (VS Code, JetBrains). Intended: Claude Code
  **desktop**. Everything else — **Cowork, claude.ai chat — is best-effort.**
- **`steer` can be _installed_ on Cowork and Claude Desktop with no rewrite.**
- **Whether its hook-driven core _runs_ there is unverified and must be tested** —
  the always-on rules injection rides a hook mechanism with a documented, still-open
  reliability bug (see [§4](#4-the-two-risk-mechanisms)).
- **The portable nucleus is skills (`SKILL.md`) + MCP.** Those travel everywhere.
- **claude.ai chat is the outlier — no plugins, no hooks.** Reach it via org-wide
  Skills + MCP connectors + Project instructions; there is no equivalent of the
  always-on rules hook there.

## 2. How `steer` is built — the coupling map

| Component | Files | Runtime dependency | Portable? |
|---|---|---|---|
| **Always-on rules** | `rules/00-router.md` … `99-end-of-session.md` (22 files) | Delivered **only** via `SessionStart` hook → stdout `additionalContext` | Prose is portable; **delivery is hook-bound** |
| **SessionStart hooks** | `inject-standards.sh`, `orient-session.sh`, `check-template-drift.sh`, `check-open-questions.sh`, `check-unmanaged-repo.sh` | `SessionStart` event; all source `${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh` | Claude-runtime-specific |
| **Gates** | `PreToolUse`: `check-version-pins.sh`, `check-code-before-spec.sh`, `check-issue-before-mutation.sh`; `Stop`: `reconcile-issue-first.sh` | `PreToolUse`/`Stop` events, `permissionDecision` output | Claude-runtime-specific |
| **Skills** (21) | `plugins/steer/skills/*` | YAML frontmatter + Markdown body; `/steer:` invocation; `allowed-tools`/`disallowed-tools` | **`SKILL.md` is the portable nucleus**; invocation + tool-allowlists are runtime concepts |
| **MCP** | `tracker-sync` (GitHub MCP → `gh` → manual) | MCP connector | **Already surface-agnostic** |
| **Bundled assets** | `templates/spec/*`, `templates/scaffold/*` | `${CLAUDE_PLUGIN_ROOT}` path resolution | Files portable; path var is runtime-specific |

**Read this as two layers.** A *portable nucleus* (skills + MCP, plain Markdown
and an open protocol) and a *non-portable risk layer* (the always-on rules
injection and the `PreToolUse`/`Stop` gates, which depend on Claude-runtime hook
behavior).

## 3. Support policy & per-surface matrix

`steer` is built and tested for the **Claude Code engine**. We commit support in
three tiers:

- **Tier 1 — Targeted (developed & tested against).** Claude Code **CLI** and the
  **IDE extensions (VS Code, JetBrains)** — the extensions delegate to the CLI, so
  they inherit the full plugin engine: hooks, always-on rules injection, gates,
  skills, and MCP. Regressions here are **bugs we fix**.
- **Tier 2 — Intended (expected parity, pending verification).** Claude Code
  **desktop**. Same plugin engine; parity expected but not yet confirmed
  ([§6](#6-verification-checklist)). We aim to support it and track gaps; not
  guaranteed per release.
- **Tier 3 — Best-effort.** Claude **Cowork** and **claude.ai chat**. The portable
  nucleus (skills + MCP) may work; the hook-driven core (always-on rules + gates) is
  **not guaranteed** and we make no per-release testing commitment.

| Surface | Tier | Plugin install | Hooks (rules + gates) | Skills | MCP |
|---|---|---|---|---|---|
| Claude Code **CLI** | **1 — targeted** | ✅ today | ✅ | ✅ | ✅ |
| **IDE extensions** (VS Code, JetBrains) | **1 — targeted** | ✅ via CLI | ✅ via CLI | ✅ | ✅ |
| Claude Code **desktop** | **2 — intended** | ✅ same engine as CLI | ⚠️ **verify** ([§4](#4-the-two-risk-mechanisms)) | ✅ | ✅ |
| Claude **Cowork** | **3 — best-effort** | ✅ from GitHub marketplace | ⚠️ **verify**, not guaranteed | ✅ | ✅ |
| **claude.ai** chat | **3 — best-effort** | ❌ no plugin engine | ❌ no hooks | ✅ as org **Skills** | ✅ remote **connectors** |

Legend: ✅ supported · ⚠️ supported-in-principle-but-unverified · ❌ not available.

Org-wide deployment differs by surface: managed settings (Tier 1/2), per-user
install today with org-wide sharing "coming" (Cowork), and admin-provisioned Skills
on Team/Enterprise (claude.ai). See [§5](#5-recommendations-per-surface).

## 4. The two risk mechanisms

`steer`'s core value — **always-on rules** — depends on a plugin `SessionStart`
hook surfacing `hookSpecificOutput.additionalContext` to the model. Two reported
behaviors put that at risk. Both must be treated as **empirically unverified on
each app runtime**, not assumed working:

1. **Plugin `SessionStart` `additionalContext` not surfaced** —
   [anthropics/claude-code#12151](https://github.com/anthropics/claude-code/issues/12151)
   (**open** since 2025-11-22): plugin hook output not captured/passed to the agent
   for `UserPromptSubmit`/`SessionStart`. An earlier report,
   [#16538](https://github.com/anthropics/claude-code/issues/16538), was closed
   *not-planned / stale* (2026-05-11). ⇒ If this bites, `steer` installs cleanly but
   the rules **silently never inject** — the failure looks like "no rules" with no error.

2. **`${CLAUDE_PLUGIN_ROOT}` unset during `SessionStart`** —
   [#27145](https://github.com/anthropics/claude-code/issues/27145) (closed as
   *duplicate* 2026-02-24; **no open canonical found** — possibly resolved). ⇒ If it
   recurs on any surface, **every** steer SessionStart script fails at the
   `. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"` line. Latent fragility worth a
   defensive guard if/when we harden.

These are the reason desktop/Cowork parity is a **test**, not an assumption.

## 5. Recommendations per surface

### Claude Code desktop
Same plugin engine as the CLI; the expectation is **parity**. Action: run the
[§6](#6-verification-checklist) checklist. Most likely "just works"; the only real
exposure is the #12151 `additionalContext` path. No code change anticipated —
confirm and document.

### Claude Cowork (priority: non-technical POs)
Add the `steer` GitHub marketplace via **Customize → Plugins**. Highest-value
portable pieces for product owners are the **PO-facing skills**, which work even if
the rules hook doesn't fire:

- **PO-appropriate:** `build`, `spec`, `questions`, `next`, `issues`,
  `design-sources`, `standards`.
- **Engineer-oriented (likely noise for POs):** `adopt`, `init`, `adr`, `audit`,
  `conventions`, `drift`, `spec-scaffold`, `sync`, `tidy`, `traceability`,
  `tracker-sync`, `protect`, `work`.

Caveats to flag in rollout: org-wide plugin **sharing is per-user today**
("coming"), so the first wave is manual install; and the always-on rules may not
inject (verify) — POs would then get skills without the ambient ruleset.

### claude.ai chat
No plugin/hook engine. Three-part path:
1. Provision steer's portable skills as **org-wide Skills** (Team/Enterprise admin).
2. Add **GitHub MCP** as a remote **connector** (mirrors `tracker-sync`'s MCP path).
3. Since the always-on rules can't inject, capture a **condensed standards digest**
   as a Skill or a **Project custom-instruction** — this is the one place the
   always-on model has no native equivalent.

### Cross-cutting
Keep skills surface-agnostic: lean on the plain-Markdown body and avoid hard
`${CLAUDE_PLUGIN_ROOT}` assumptions in skill *prose*. Design a graceful-degradation
story for rules where hooks don't run (digest-as-skill is the fallback).

## 6. Verification checklist

Hook parity is empirical and can't be checked from the CLI — run this on each
desktop app and record pass/fail back into the [§3 matrix](#3-per-surface-support-matrix):

- [ ] Install/enable `steer`; start a **fresh** session.
- [ ] **Rules injected?** Ask "what engineering rules are active?" — expect the
      `00-router` ruleset, not a blank. (Tests #12151.)
- [ ] **`PreToolUse` gate fires?** Attempt a mutation that
      `check-issue-before-mutation.sh` should advise/deny.
- [ ] **Skill invocation works?** Run `/steer:next` (or `/steer:build`) and confirm
      the namespaced invocation resolves.
- [ ] **MCP found?** Confirm `tracker-sync` locates the GitHub MCP connector.
- [ ] Record results per surface; if rules don't inject, that's the trigger to scope
      the hook-hardening / digest-as-skill follow-up.

## 7. Out of scope (this pass)

No hook hardening, no skills-only distribution build, no MCP packaging. Those are
follow-ups this doc recommends and sizes — to be decided after the checklist
results come back.

---

### Sources
- Claude Cowork extensions (MCP, plugins, skills, hooks) and "Use plugins in
  Claude" (Customize → Plugins, install from GitHub) — claude.com / support.claude.com docs.
- Open/closed hook behavior: claude-code issues
  [#12151](https://github.com/anthropics/claude-code/issues/12151),
  [#16538](https://github.com/anthropics/claude-code/issues/16538),
  [#27145](https://github.com/anthropics/claude-code/issues/27145).
- This repo: `plugins/steer/hooks/hooks.json`, `plugins/steer/skills/*`,
  `plugins/steer/rules/*`, root `CLAUDE.md`, `README.md`.
