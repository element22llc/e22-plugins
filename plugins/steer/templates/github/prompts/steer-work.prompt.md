---
mode: agent
description: Execute a GitHub issue end-to-end from local Claude Code — claim, branch, load linked specs, implement, test, open the PR, and transition lifecycle state; the execution counterpart to /steer-issues, routing all tracker-metadata I/O through /steer-tracker-sync. Pass --reviewed to wrap execution in independent plan- and code-review gates, --hotfix for the production-incident fast path.
---

<!-- Generated from the steer plugin's skills/work/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:work` workflow for GitHub Copilot in VS Code.

**Purpose.** Execute a GitHub issue end-to-end from local Claude Code — claim, branch, load linked specs, implement, test, open the PR, and transition lifecycle state; the execution counterpart to /steer-issues, routing all tracker-metadata I/O through /steer-tracker-sync. Pass --reviewed to wrap execution in independent plan- and code-review gates, --hotfix for the production-incident fast path.

**When to use.** Use when asked to work, start, resume, or finish a specific issue ("work on

**Arguments.** [start | resume | status | finish] [--reviewed | --hotfix] [#issue ...]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/work/SKILL.md` (invoked as `/steer:work` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
