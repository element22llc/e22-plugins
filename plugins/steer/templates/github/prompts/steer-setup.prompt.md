---
mode: agent
description: One front door for getting a repo onto the standards — detect the repo's /spec spine state and route to the right bootstrap path (greenfield init, brownfield adopt, or steady-state sync), installing prerequisites first if the toolchain is missing. A thin dispatcher that decides which path applies and hands off — it does not duplicate their logic.
---

<!-- Generated from the steer plugin's skills/setup/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:setup` workflow for GitHub Copilot in VS Code.

**Purpose.** One front door for getting a repo onto the standards — detect the repo's /spec spine state and route to the right bootstrap path (greenfield init, brownfield adopt, or steady-state sync), installing prerequisites first if the toolchain is missing. A thin dispatcher that decides which path applies and hands off — it does not duplicate their logic.

**When to use.** Use whenever someone wants to "set up", "onboard", "bootstrap", "adopt", or "bring this repo onto the standards", or to "sync to the latest plugin" — any time you'd otherwise have to guess between /steer-init, /steer-adopt, and /steer-sync. This is the single entry point; it auto-detects which applies.

**Arguments.** [init | adopt | sync]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/setup/SKILL.md` (invoked as `/steer:setup` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
