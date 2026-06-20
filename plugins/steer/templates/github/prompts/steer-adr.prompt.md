---
mode: agent
description: Create a numbered ADR from the bundled template.
---

<!-- Generated from the steer plugin's skills/adr/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:adr` workflow for GitHub Copilot in VS Code.

**Purpose.** Create a numbered ADR from the bundled template.

**When to use.** Use for any hard-to-reverse or cross-cutting choice (stack, database, auth, deployment, new pattern) or when asked to record a decision.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:adr`); this capsule carries the intent so Copilot can drive the same workflow here.
