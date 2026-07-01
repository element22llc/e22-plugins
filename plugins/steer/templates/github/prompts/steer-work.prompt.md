---
mode: agent
description: Execute a GitHub issue end-to-end from local Claude Code — claim, branch, load linked specs, implement, test, open the PR, and transition lifecycle state; the execution counterpart to /steer:issues, routing all tracker-metadata I/O through /steer:tracker-sync. Pass --reviewed to wrap execution in independent plan- and code-review gates, --hotfix for the production-incident fast path.
---

<!-- Generated from the steer plugin's skills/work/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:work` workflow for GitHub Copilot in VS Code.

**Purpose.** Execute a GitHub issue end-to-end from local Claude Code — claim, branch, load linked specs, implement, test, open the PR, and transition lifecycle state; the execution counterpart to /steer:issues, routing all tracker-metadata I/O through /steer:tracker-sync. Pass --reviewed to wrap execution in independent plan- and code-review gates, --hotfix for the production-incident fast path.

**When to use.** Use when asked to work, start, resume, or finish a specific issue ("work on

**Arguments.** [start | resume | status | finish] [--reviewed | --hotfix] [#issue ...]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:work`); this capsule carries the intent so Copilot can drive the same workflow here.
