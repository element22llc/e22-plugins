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

`steer` does **not** automate or manage a GitHub Projects board, and
priority/effort fields are not tracked by the plugin. The backlog is
**issue-first / local-first**; triage lives in issues and the `/spec` spine.

What steer *does* guarantee is that issues are **Projects v2-compatible by
construction**: it sets the native attributes a board or roadmap reads — Issue
**Type**, labels, assignees, milestone (`/steer:tracker-sync set-milestone`), and
native parent/sub-issue links — so you can build an (org-level) board or roadmap
on top without the plugin owning it. Project custom fields (Status, dates,
iteration, priority, size) live on the Project *item*, set Project-side, and are
never written into the issue; `steer:state` stays canonical in the body and is
mirrored at most one-directionally by a Project Status field. See the
*GitHub Projects v2 — compatibility boundary* in the issue-schema reference.

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
