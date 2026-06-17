# Known limitations

What to know before you rely on `steer`. None of these are bugs — they're the
edges of what the plugin can guarantee, given the surfaces and tools it runs on.
When in doubt, fall back to human review.

## Claude Cowork and the desktop app

Plugin hooks are a Claude Code lifecycle feature, and on **Claude Cowork and the
desktop app** they do not currently fire. Consequences:

- The always-on rules are **not** auto-injected — run `/steer:standards` at the
  start of every session. This is the one that matters: the rules are what make
  Claude follow the standards.
- The `PreToolUse` hooks don't run either — the spec-first and issue-first
  nudges, and the version-pin `deny`. Note that the first two are only advisory
  reminders even when they *do* fire (see below), so losing them matters less
  than losing the rules.

Treat these surfaces as "load the rules by hand, and rely on review." See
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

`steer` does **not** automate GitHub Projects. There is no per-repo project
board, and priority/effort fields are not managed by the plugin. The backlog is
**issue-first / local-first**; triage lives in issues and the `/spec` spine, not
a Projects board.

## What the hooks do (and don't) enforce

Even when hooks fire, only one of them actually blocks an action. Be honest about
the tiers:

- **`SessionStart` → `inject-standards.sh`** injects the rules. Real and load-bearing.
- **`PreToolUse` → `check-code-before-spec.sh` / `check-issue-before-mutation.sh`**
  are **advisory nudges**: they emit a one-per-session reminder and let the write
  proceed. They are explicitly *"a nudge, not a gate,"* fail open on any
  ambiguity, and the issue-first one only fires in GitHub-tracked repos.
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
