---
mode: agent
description: One-time setup for a new managed repo — bootstrap the /spec spine + repo scaffolding from the plugin's bundled scaffold (the plugin replaces the old static repository-template as the bootstrap source), or resolve placeholders in a legacy template fork. In both cases pin the toolchain and leave the repo working spec-first.
---

<!-- Generated from the steer plugin's skills/init/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:init` workflow for GitHub Copilot in VS Code.

**Purpose.** One-time setup for a new managed repo — bootstrap the /spec spine + repo scaffolding from the plugin's bundled scaffold (the plugin replaces the old static repository-template as the bootstrap source), or resolve placeholders in a legacy template fork. In both cases pin the toolchain and leave the repo working spec-first.

**When to use.** Use when the dev says "set up this new repo", when a repo has no /spec spine, or when template placeholders ([Replace …], [Product Name], @github-handle) remain.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:init`); this capsule carries the intent so Copilot can drive the same workflow here.
