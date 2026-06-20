---
mode: agent
description: Adopt an existing repo that never went through bootstrap (a "vibe-coded" app) into the standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the plugin's bundled scaffolding without clobbering working code.
---

<!-- Generated from the steer plugin's skills/adopt/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:adopt` workflow for GitHub Copilot in VS Code.

**Purpose.** Adopt an existing repo that never went through bootstrap (a "vibe-coded" app) into the standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the plugin's bundled scaffolding without clobbering working code.

**When to use.** Use when a repo has working code but no /spec spine and no mise.toml, or when asked to adopt or onboard an existing app onto the standards.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:adopt`); this capsule carries the intent so Copilot can drive the same workflow here.
