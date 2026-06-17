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
- **`steer` can be _installed_ on Cowork and Claude Desktop with no rewrite** — but
  installing ≠ running its core.
- **The hook-driven core does _not_ fire on Cowork or the desktop app** (per our own
  [known-limitations](docs/reference/known-limitations.md)): the always-on rules are
  not auto-injected and the `PreToolUse` gates don't run there. Load the rules by
  hand with `/steer:standards` (see [§4](#4-why-the-hook-layer-doesnt-travel)).
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
- **Tier 2 — Intended.** Claude Code **desktop**. We commit to supporting it, but
  **plugin hooks do not fire there** ([known-limitations](docs/reference/known-limitations.md)):
  skills and MCP work; the always-on rules and `PreToolUse` gates do not — run
  `/steer:standards` to load the rules manually. (The support *tier* is our
  commitment; the hook layer's availability is a separate axis — see the Hooks
  column and [§4](#4-why-the-hook-layer-doesnt-travel).)
- **Tier 3 — Best-effort.** Claude **Cowork** and **claude.ai chat**. The portable
  nucleus (skills + MCP) is what works; the hook-driven core (always-on rules +
  gates) **does not fire** (Cowork: confirmed; claude.ai: no hook engine at all). No
  per-release testing commitment.

| Surface | Tier | Plugin install | Hooks (rules + gates) | Skills | MCP |
|---|---|---|---|---|---|
| Claude Code **CLI** | **1 — targeted** | ✅ today | ✅ | ✅ | ✅ |
| **IDE extensions** (VS Code, JetBrains) | **1 — targeted** | ✅ via CLI | ✅ via CLI | ✅ | ✅ |
| Claude Code **desktop** | **2 — intended** | ✅ same engine as CLI | ❌ don't fire — use `/steer:standards` ([§4](#4-why-the-hook-layer-doesnt-travel)) | ✅ | ✅ |
| Claude **Cowork** | **3 — best-effort** | ✅ from GitHub marketplace | ❌ don't fire — use `/steer:standards` | ✅ | ✅ |
| **claude.ai** chat | **3 — best-effort** | ❌ no plugin engine | ❌ no hook engine | ✅ as org **Skills** | ✅ remote **connectors** |

Legend: ✅ works · ❌ not available, or present but does not fire (see cell note).

Org-wide deployment differs by surface: managed settings (Tier 1/2), per-user
install today with org-wide sharing "coming" (Cowork), and admin-provisioned Skills
on Team/Enterprise (claude.ai). See [§5](#5-recommendations-per-surface).

## 4. Why the hook layer doesn't travel

`steer`'s core value — **always-on rules** — depends on a plugin `SessionStart`
hook surfacing `hookSpecificOutput.additionalContext` to the model, and the
`PreToolUse`/`Stop` gates depend on the same plugin-hook lifecycle. Our own
[known-limitations](docs/reference/known-limitations.md) records the tested
reality: **on Claude Cowork and the desktop app these hooks do not currently
fire.** Skills and MCP are unaffected; the rules and the gates are.

Two mechanism-level reasons this layer is fragile (consistent with the observed
behavior):

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

**Mitigation (per known-limitations):** on Cowork/desktop, load the rules by hand
with `/steer:standards` at the start of each session, and rely on human review
where the `PreToolUse` gates would have fired.

## 5. Recommendations per surface

### Claude Code desktop
Same plugin engine as the CLI **except plugin hooks don't fire** — so skills and
MCP work, but the always-on rules and `PreToolUse` gates don't
([known-limitations](docs/reference/known-limitations.md)). Guidance: install
`steer`, then **run `/steer:standards` at the start of each session** to load the
rules by hand, and rely on review where the gates would have run. No code change;
the [§6](#6-verification-checklist) checklist confirms skills/MCP and the manual
rule-load.

### Claude Cowork (priority: non-technical POs)
Add the `steer` GitHub marketplace via **Customize → Plugins**. Highest-value
portable pieces for product owners are the **PO-facing skills**, which work even if
the rules hook doesn't fire:

- **PO-appropriate:** `build`, `spec`, `questions`, `next`, `issues`,
  `design-sources`, `standards`.
- **Engineer-oriented (likely noise for POs):** `adopt`, `init`, `adr`, `audit`,
  `conventions`, `drift`, `spec-scaffold`, `sync`, `tidy`, `traceability`,
  `tracker-sync`, `protect`, `work`.

Caveats to flag in rollout: the always-on rules **do not inject** on Cowork
([known-limitations](docs/reference/known-limitations.md)) — POs get skills without
the ambient ruleset, so have them run `/steer:standards` first (or lean on the
PO-facing skills, which are self-contained). And org-wide plugin **sharing is
per-user today** ("coming"), so the first wave is manual install.

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

Run on each desktop app and record results back into the
[§3 matrix](#3-support-policy--per-surface-matrix). Hooks are **expected not to
fire** on Cowork/desktop ([§4](#4-why-the-hook-layer-doesnt-travel)) — so this
confirms the working path and the manual workaround, not parity:

- [ ] Install/enable `steer`; start a **fresh** session.
- [ ] **Skill invocation works?** Run `/steer:next` (or `/steer:build`) and confirm
      the namespaced invocation resolves.
- [ ] **MCP found?** Confirm `tracker-sync` locates the GitHub MCP connector.
- [ ] **Manual rule-load works?** Run `/steer:standards` and confirm the session
      then reflects the ruleset.
- [ ] **(Sanity) hooks still silent?** On a fresh session the rules should *not*
      auto-inject (matches [known-limitations](docs/reference/known-limitations.md)).
      If they now *do*, the platform changed — update both docs.

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
- **Authoritative in-repo statement on hook behavior:**
  [`docs/reference/known-limitations.md`](docs/reference/known-limitations.md)
  ("Claude Cowork and the desktop app" — hooks do not fire; load rules via
  `/steer:standards`).
- This repo: `plugins/steer/hooks/hooks.json`, `plugins/steer/skills/*`,
  `plugins/steer/rules/*`, root `CLAUDE.md`, `README.md`.
