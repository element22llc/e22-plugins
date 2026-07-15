---
mode: agent
description: Load the always-on operating manual on demand. In Claude Code the rules are already injected, so this only repeats them.
---

<!-- Generated from the steer plugin's skills/standards/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:standards` workflow for GitHub Copilot in VS Code.

**Purpose.** Load the always-on operating manual on demand. In Claude Code the rules are already injected, so this only repeats them.

**When to use.** Use at the start of a session on any surface where the SessionStart hook does NOT auto-inject the rules — notably the Claude desktop/web Chat tab and chat-only surfaces, where plugin hooks do not run.

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/standards/SKILL.md` (invoked as `/steer:standards` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
