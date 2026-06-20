---
mode: agent
description: Load the always-on operating manual on demand. In Claude Code the rules are already injected, so this only repeats them.
---

<!-- Generated from the steer plugin's skills/standards/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:standards` workflow for GitHub Copilot in VS Code.

**Purpose.** Load the always-on operating manual on demand. In Claude Code the rules are already injected, so this only repeats them.

**When to use.** Use at the start of a session on any surface where the SessionStart hook does NOT auto-inject the rules — notably the Claude desktop/web Chat tab and chat-only surfaces, where plugin hooks do not run.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:standards`); this capsule carries the intent so Copilot can drive the same workflow here.
