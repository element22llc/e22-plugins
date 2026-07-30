---
mode: agent
description: One-time setup for a new managed repo — bootstrap the /spec spine + scaffolding, pin the toolchain, leave it working spec-first, and resolve placeholders in a legacy template fork. Offers PR flow or solo-trunk mode.
---

<!-- Generated from the steer plugin's skills/init/SKILL.md — do not edit by hand. Refresh with /steer:sync from Claude Code in a managed repo, or mise run gen:copilot in the plugin repo. -->

This mirrors steer's `/steer:init` workflow for GitHub Copilot in VS Code.

**Purpose.** One-time setup for a new managed repo — bootstrap the /spec spine + scaffolding, pin the toolchain, leave it working spec-first, and resolve placeholders in a legacy template fork. Offers PR flow or solo-trunk mode.

**When to use.** Use on a new repo with no /spec spine ("set up this new repo"), or when template placeholders ([Replace …], [Product Name], @github-handle) remain.

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/init/SKILL.md` (invoked as `/steer:init` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
