---
mode: agent
description: Read-only workspace navigator — reconstructs the whole workspace state cold (branch/PR, /spec feature status, open questions, Proposed ADRs, tracker issues, work claims, version drift) and arbitrates the single best next action across all workflows using the shared categories + safety precedence. Never edits, commits, publishes, merges, or advances state; defers how to resolve each state to the owning skill.
---

<!-- Generated from the steer plugin's skills/next/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:next` workflow for GitHub Copilot in VS Code.

**Purpose.** Read-only workspace navigator — reconstructs the whole workspace state cold (branch/PR, /spec feature status, open questions, Proposed ADRs, tracker issues, work claims, version drift) and arbitrates the single best next action across all workflows using the shared categories + safety precedence. Never edits, commits, publishes, merges, or advances state; defers how to resolve each state to the owning skill.

**When to use.** Use when picking a repo up cold or mid-stream and asking "what should I do next?", "where do I start?", or "I'm lost" across the whole workspace — when work spans more than one feature/issue/workflow and you need the one action that matters most right now, not a per-skill handoff.

**Arguments.** [optional constraints, e.g. 'only feature-x', 'no tracker writes']

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/next/SKILL.md` (invoked as `/steer:next` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
