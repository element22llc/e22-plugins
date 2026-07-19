---
mode: agent
description: Human-facing capabilities menu — renders the router's intent-to-skill table in plain language, the six essentials first and the rest grouped by journey. Read-only; sources the live router table so it can never drift from actual routing.
---

<!-- Generated from the steer plugin's skills/help/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:help` workflow for GitHub Copilot in VS Code.

**Purpose.** Human-facing capabilities menu — renders the router's intent-to-skill table in plain language, the six essentials first and the rest grouped by journey. Read-only; sources the live router table so it can never drift from actual routing.

**When to use.** Use to browse steer's capabilities — "what can steer do?", "what can you do?", "show me the commands", "list the skills". Discovery only: "what should I do next" routes to /steer-next.

**Arguments.** [optional: a skill or area to zoom into]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/help/SKILL.md` (invoked as `/steer:help` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
