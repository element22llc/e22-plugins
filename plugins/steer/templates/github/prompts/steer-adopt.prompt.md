---
mode: agent
description: Adopt an existing repo that never went through bootstrap (a "vibe-coded" app) into the standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the plugin's bundled scaffolding without clobbering working code.
---

<!-- Generated from the steer plugin's skills/adopt/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:adopt` workflow for GitHub Copilot in VS Code.

**Purpose.** Adopt an existing repo that never went through bootstrap (a "vibe-coded" app) into the standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the plugin's bundled scaffolding without clobbering working code.

**When to use.** Use when a repo has working code but no /spec spine and no mise.toml, or when asked to adopt or onboard an existing app onto the standards.

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/adopt/SKILL.md` (invoked as `/steer:adopt` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
