---
mode: agent
description: 'Compare the as-built /spec (reverse-engineered from the code by /steer:adopt) against the intended spec exported from an issue tracker (Jira, Linear, GitHub Issues, … as markdown — one file per epic/issue or story/task) and surface every divergence. Read-only: reports findings and proposes Rule-5 resolutions, never edits.'
---

<!-- Generated from the steer plugin's skills/drift/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:drift` workflow for GitHub Copilot in VS Code.

**Purpose.** Compare the as-built /spec (reverse-engineered from the code by /steer:adopt) against the intended spec exported from an issue tracker (Jira, Linear, GitHub Issues, … as markdown — one file per epic/issue or story/task) and surface every divergence. Read-only: reports findings and proposes Rule-5 resolutions, never edits.

**When to use.** Use when asked to check a built app against its tracker specs, audit spec drift, or confirm the code did what the tickets asked.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:drift`); this capsule carries the intent so Copilot can drive the same workflow here.
