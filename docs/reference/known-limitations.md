# Known limitations

What to know before you rely on `steer`. None of these are bugs — they're the
edges of what the plugin can guarantee, given the surfaces and tools it runs on.
When in doubt, fall back to human review.

## Where hooks fire (Claude Code vs. the chat surfaces)

Plugin hooks are a Claude Code lifecycle feature, and **where they fire depends on
the surface** (validated June 2026). The Claude Desktop app has three tabs —
**Chat**, **Cowork**, and **Code** — and they don't behave the same:

- **Claude Code — the CLI, the IDE extensions (VS Code / JetBrains), and the
  Claude Desktop *Code* tab — runs hooks fully.** The always-on rules inject, the
  `PreToolUse` gates run, skills and MCP work. This is the supported path.
- **Cowork** (the *Cowork* tab) is the one chat-family surface where hooks and
  sub-agents run — Anthropic's docs state *"hooks and sub-agents run only in
  Cowork."* Plugin-scoped `SessionStart` hooks had bugs earlier in 2026 (since
  closed); **reconfirm on your build** before relying on auto-injected rules there.
- **The Claude Desktop *Chat* tab and claude.ai web chat do NOT run hooks** — they
  show as grayed out. Plugins install and **skills work**, but the always-on rules
  are **not** auto-injected and the `PreToolUse` gates don't run.

On the no-hooks surfaces (Chat tab, web chat) — and as a fallback anywhere the
rules didn't load — run `/steer:standards` at the start of the session to load the
rules by hand, and rely on human review where the gates would have fired. The
rules are the one that matters: they're what make Claude follow the standards; the
`PreToolUse` spec-first and issue-first nudges are only advisory even when they
*do* fire (see below), so losing them matters less. See
[Installation](../getting-started/installation.md) and the
[Hooks reference](hooks.md).

## Knowledge-work mode (non-code folders, e.g. Claude Cowork)

When a session opens a folder that is **confidently not a code project** — no git
work tree and no code/config markers nearby — steer injects a **lean,
PO-relevant** ruleset instead of the full engineering manual. This is the typical
**Claude Cowork** case: a product owner opens a connected folder of specs/docs.
In that mode the spec-workflow, decision-capture, living-docs, roles, secrets and
output rules still apply, but the code/infra/tracker-specific rules (stack,
testing, coverage, worktrees, deployment, drift-gates, …) are **intentionally
omitted** to reclaim context budget and cut noise, and `orient-session` confirms
in plain language that the standards are active.

The classification is **fail-safe**: a git repo, *any* code/config marker, or any
uncertainty resolves to full `code` mode — steer never silently drops a rule from
a real code project. `/spec` is deliberately not treated as a code marker, since a
knowledge folder is exactly where a spec spine may live. The limitation to know:
in a non-git folder steer cannot detect a code project that carries no on-disk
markers, so a marker-less code checkout opened without git would get the lean set
— add a `mise.toml`/`package.json` (or open it as a git repo) to get full rules.

## Claude Cowork's sandbox: no installs, connector-only GitHub

Claude Cowork runs in an **Anthropic-managed, sandboxed Linux VM** (OS-level
isolation via bubblewrap/seatbelt), not a normal dev machine. Claude can read,
write, and run scripts inside the connected folder, but the sandbox's filesystem
and network are locked down: in practice you **cannot install system tooling** —
**docker, mise, language toolchains, or the `gh` CLI** — the way you can in a
Claude Code CLI session (validated June 2026). Treat Cowork as a **no-install**
surface. This is an environment boundary, not a steer bug.

Two consequences follow, and together they explain why "the GitHub connector
isn't working" in Cowork even though it works in the CLI.

**1. The plugin's `.mcp.json` is a Claude Code mechanism — Cowork doesn't use it.**
[MCP config is not shared across surfaces](mcp-servers.md): Cowork wires MCP
through its own **Connectors**, not the plugin-shipped
`plugins/steer/.mcp.json` that the CLI reads. So of the three servers steer
ships, two do **not** survive Cowork:

- **`github`** authenticates with `Authorization: Bearer ${GITHUB_PAT}` resolved
  from your **local shell**. The sandbox has no shell you exported that PAT into,
  and Cowork doesn't read the CLI `.mcp.json` for credentials anyway — so the
  plugin's GitHub server appears to "try to connect like Claude Code" and fails
  to authenticate. **Do not rely on it in Cowork.**
- **`markitdown`** runs as a **local process** (`uvx markitdown-mcp`), which needs
  `uv`/Python that can't be installed, and local MCP tools can be **silently
  disabled** in Cowork (they appear in the list but return *"This tool has been
  disabled in your connector settings"*). Don't rely on it either.
- **`context7`** is a plain hosted HTTP endpoint with no token, so it is the one
  that can work if the surface routes it — nothing to install, no shell secret.

**2. GitHub on Cowork = the built-in connector, not the plugin server.** To do
issue work in Cowork, enable the **built-in GitHub connector** (Cowork →
**Customize → Connectors**), which Anthropic manages via OAuth and runs **outside**
the bash sandbox. Once it's on, `/steer:tracker-sync`'s **MCP-first** probe finds
the repo-scoped issue tools (list / get / create / comment / label / transition)
and `/steer:issues triage` works — Cowork **can** triage GitHub issues. Caveats:

- It is **repo-scoped only.** Org/team-level reads come back empty by design, so
  anything needing org config — Issue **Types**, and the org-level native issue
  **fields** (Priority/Effort/dates) `field-set` writes — may be unavailable and
  will degrade to the `steer:kind` marker / a human follow-up rather than fail
  loudly. Plain triage (read, classify, label, comment, set the `steer:state`
  marker, link issues) does not need org scope and works.
- The **`gh`-CLI fallback is unavailable** (can't install `gh`), so when the
  built-in connector is off there is no automated path — only the manual floor.

Net: in Cowork, do **issue triage** through the built-in connector; for the
install-dependent parts of steer (docker/mise builds, the local `markitdown`
server, `gh`-CLI flows) use the **Claude Code CLI or the Desktop *Code* tab**,
which share the full engine.

## Headless vs. interactive runs

The plugin's gates assume an **interactive human** is present to approve specs,
pushes, and merges. In headless or scheduled (cron) runs there is no human at the
gate, and **interactively-authenticated MCP servers may be absent**, so the
MCP-first tracker path can silently fall back. Don't run the gated workflows
unattended and expect the approvals to happen.

## GitHub auth / `gh`

Anything that touches the tracker or GitHub needs an authenticated path. Tracker
I/O routes **MCP-first → `gh` fallback → manual floor** (see the
`tracker-sync` skill), so without an MCP tracker tool *and* without an
authenticated `gh`, these operations drop to the manual floor:

- creating and transitioning issues,
- opening and updating PRs (`gh pr create`),
- syncing lifecycle state.

Check with `gh auth status`. Skills never hit `gh`/MCP for issues directly —
they go through `/steer:tracker-sync`, so the fallback is consistent, but the
underlying capability still has to be there.

## GitHub Projects automation

`steer` does **not** automate or manage a GitHub Projects board. The backlog is
**issue-first / local-first**; triage lives in issues and the `/spec` spine.
Priority, effort, and start/target dates are **native GitHub issue fields** on the
issue (not labels, not Project-item fields) — `steer` reads them and escalate-only
auto-sets Priority.

What steer *does* guarantee is that issues are **Projects v2-compatible by
construction**: it sets the native attributes a board or roadmap reads — Issue
**Type**, labels, assignees, milestone (`/steer:tracker-sync set-milestone`),
native parent/sub-issue links, and the native issue fields above — so you can build
an (org-level) board or roadmap on top without the plugin owning it. An `epic`
(a parent tracking issue grouping features as sub-issues) makes the full
`Epic → Feature → Task` tree board-visible by construction, so a Projects v2
Hierarchy view renders it with no extra machinery; `Type=Epic` is used only when
the org enables that type, otherwise the epic carries the `steer:kind=epic` marker
with its Type left unset. Only Project
*item* custom fields (Status, iteration, size) live Project-side and are never
written into the issue; `steer:state` stays canonical in the body and is mirrored
at most one-directionally by a Project Status field.

!!! warning "The native-field vs Projects-column trap"
    When a Project v2 board surfaces the native issue fields (Priority, Effort,
    dates), they appear as single-select **columns that look identical to genuine
    Project custom fields (`Size`, `Iteration`) but are API-locked**. Every Projects
    write path rejects them — `updateProjectV2Field` and `gh project item-edit`
    return `Only custom fields can be updated. Fields derived from issues or pull
    requests must be updated through their respective APIs` — and every Projects
    *read* path reports `options: []`, so there is no option id to set through the
    Project at all, even though the UI shows Urgent/High/Medium/Low. **Set these on
    the native issue field via `/steer:tracker-sync field-set`, never the Projects
    API.** The reverse holds for a genuine Project custom field (`Size`,
    `Iteration`): it is *not* a native issue field, so it is edited with
    `gh project item-edit` and `field-set` will not find it. To populate a chosen
    Priority/Effort value (PO seeding, not the escalate-only floor), `/steer:issues`
    triage and board route the request straight to `field-set`. `field-set` writes
    the native field through GraphQL `setIssueFieldValue` (or the equivalent REST
    `issue-field-values` endpoint) — *not* a GraphQL-only path, despite the Projects
    columns being read-locked.

## Context window, compaction, and sessions

`steer` cannot manage your context window for you, and that is a hard Claude Code
boundary, not a plugin gap: no hook or environment variable exposes the token count
or how full the window is, and **neither a hook nor the model can trigger `/compact`
or start a new session** — only you can. So `steer` will never silently compact or
"switch you to a fresh session" when a long run fills the window.

What it does instead (rule `26-context-hygiene`; full prose via
`/steer:reference context-hygiene`):

- **Delegates heavy, multi-phase, or search-heavy runs to subagents**, which get a
  fresh context window by construction and return only the result — so the heavy
  intermediate context never lands in your main session.
- **Keeps durable run-state and task constraints in files** (`/spec/**`, sidecars),
  which survive compaction and a fresh session where chat history does not. The
  `SessionStart` hook also re-injects the rules after a `compact`.
- **Only when the thread is genuinely overloaded** does it *recommend* you `/compact`
  or start a fresh session — with a pre-composed hand-off — saying plainly that
  acting is your call, not something it can do.

## What the hooks do (and don't) enforce

Even when hooks fire, only one of them actually blocks an action. Be honest about
the tiers:

- **`SessionStart` → `inject-standards.sh`** injects the rules. Real and load-bearing.
- **`PreToolUse` → `check-code-before-spec.sh` / `check-issue-before-mutation.sh`**
  are **advisory nudges** that let the write proceed. They are explicitly *"a
  nudge, not a gate,"* fail open on any ambiguity, and the issue-first one only
  fires in GitHub-tracked repos. `check-code-before-spec.sh` reminds once per
  session about the missing `/spec` spine, but its **scaffold** reminder is
  sticky — it re-fires on each new feature file while the repo has no root
  `mise.toml`, since the bundled scaffold is product-independent and shouldn't be
  silently skipped (it still never blocks).
- **`PreToolUse` → `check-version-pins.sh`** is the only hard **`deny`** — it
  blocks image/runtime pins below the supported floor.
- The **push / PR gate is not a hook at all** — it's a rule Claude follows
  (`45-commit-autonomy`, `95-not-the-gate`). Nothing technically prevents a push;
  a human reviewer is the real backstop.

## When hooks fail or don't run

If a hook errors or simply doesn't fire (see Cowork/Desktop above), the session
keeps working — but the rules aren't injected and the `PreToolUse` hooks don't
fire. The plugin's hooks fail **open** by design (any ambiguity → allow), and
there is no automatic retry. Mitigation:

- Load the rules manually with `/steer:standards`.
- Rely on human review at every decision gate.
- On managed surfaces, confirm rules loaded (the session should reflect the
  standards) before trusting the gates.
