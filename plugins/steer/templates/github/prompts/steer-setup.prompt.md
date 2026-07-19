---
mode: agent
description: One front door for getting a repo onto the standards — detect the /spec spine state and route to greenfield init, brownfield adopt, or steady-state sync, installing prerequisites first when the toolchain is missing.
---

<!-- Generated from the steer plugin's skills/setup/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:setup` workflow for GitHub Copilot in VS Code.

**Purpose.** One front door for getting a repo onto the standards — detect the /spec spine state and route to greenfield init, brownfield adopt, or steady-state sync, installing prerequisites first when the toolchain is missing.

**When to use.** Use when asked to set up, onboard, bootstrap, or adopt a repo, or to sync to the latest plugin — the single entry point whenever you would otherwise guess between /steer-init, /steer-adopt, and /steer-sync.

**Arguments.** [init | adopt | sync]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/setup/SKILL.md` (invoked as `/steer:setup` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
