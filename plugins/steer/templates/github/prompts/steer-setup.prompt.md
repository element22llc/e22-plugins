---
mode: agent
description: One front door for getting a repo onto the standards — detect the repo's /spec spine state and route to the right bootstrap path (greenfield init, brownfield adopt, or steady-state sync), installing prerequisites first if the toolchain is missing. A thin dispatcher that decides which path applies and hands off — it does not duplicate their logic.
---

<!-- Generated from the steer plugin's skills/setup/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:setup` workflow for GitHub Copilot in VS Code.

**Purpose.** One front door for getting a repo onto the standards — detect the repo's /spec spine state and route to the right bootstrap path (greenfield init, brownfield adopt, or steady-state sync), installing prerequisites first if the toolchain is missing. A thin dispatcher that decides which path applies and hands off — it does not duplicate their logic.

**When to use.** Use whenever someone wants to "set up", "onboard", "bootstrap", "adopt", or "bring this repo onto the standards", or to "sync to the latest plugin" — any time you'd otherwise have to guess between /steer:init, /steer:adopt, and /steer:sync. This is the single entry point; it auto-detects which applies.

**Arguments.** [init | adopt | sync]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:setup`); this capsule carries the intent so Copilot can drive the same workflow here.
