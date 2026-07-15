---
mode: agent
description: Human-facing capabilities menu — renders the router's intent→skill table in plain language, grouped by workflow, so a user can browse what steer can do without knowing any skill name. Read-only; sources the live router table so it can never drift from actual routing.
---

<!-- Generated from the steer plugin's skills/help/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:help` workflow for GitHub Copilot in VS Code.

**Purpose.** Human-facing capabilities menu — renders the router's intent→skill table in plain language, grouped by workflow, so a user can browse what steer can do without knowing any skill name. Read-only; sources the live router table so it can never drift from actual routing.

**When to use.** Use when the user wants to browse steer's capabilities rather than run one — "what can steer do?", "what can you do?", "show me the commands", "list the skills", "I'm new here, what's available?". This is discovery, not navigation: for "what should I do next" in a real repo route to /steer-next, and for getting a repo onto the standards route to /steer-setup.

**Arguments.** [optional: a skill or area to zoom into]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/help/SKILL.md` (invoked as `/steer:help` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
