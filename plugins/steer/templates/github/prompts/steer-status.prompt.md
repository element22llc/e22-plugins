---
mode: agent
description: Client-facing, time-boxed progress report across the whole /spec spine — what shipped, what's in progress, what needs the client's input, and what's next — rendered as a shareable Claude Artifact with a Markdown fallback. Read-only and derived; never fabricates counts, dates, or status.
---

<!-- Generated from the steer plugin's skills/status/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:status` workflow for GitHub Copilot in VS Code.

**Purpose.** Client-facing, time-boxed progress report across the whole /spec spine — what shipped, what's in progress, what needs the client's input, and what's next — rendered as a shareable Claude Artifact with a Markdown fallback. Read-only and derived; never fabricates counts, dates, or status.

**When to use.** Use for a progress update to hand a client or Product Owner — "give me a status report", "what did we ship this week", "weekly status for the client", "where are we on <milestone>".

**Arguments.** [this-week | since <date> | milestone [<name>]]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/status/SKILL.md` (invoked as `/steer:status` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
