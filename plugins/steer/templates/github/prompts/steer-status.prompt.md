---
mode: agent
description: 'Render a client-facing, time-boxed progress report across the whole /spec spine — what shipped this period, what''s in progress, what needs the client''s input, and what''s next — as a shareable Claude Code Artifact with a Markdown fallback. A thin orchestrator + presentation layer: reads closed issues and milestone progress through /steer-tracker-sync and reads open blocking questions and feature status from /spec, then renders them in plain product language. Read-only and derived — /spec and the tracker stay canonical; it never fabricates counts, dates, or status, never writes into /spec, /apps, /packages, or the tracker, and is never auto-generated on a schedule.'
---

<!-- Generated from the steer plugin's skills/status/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:status` workflow for GitHub Copilot in VS Code.

**Purpose.** Render a client-facing, time-boxed progress report across the whole /spec spine — what shipped this period, what's in progress, what needs the client's input, and what's next — as a shareable Claude Code Artifact with a Markdown fallback. A thin orchestrator + presentation layer: reads closed issues and milestone progress through /steer-tracker-sync and reads open blocking questions and feature status from /spec, then renders them in plain product language. Read-only and derived — /spec and the tracker stay canonical; it never fabricates counts, dates, or status, never writes into /spec, /apps, /packages, or the tracker, and is never auto-generated on a schedule.

**When to use.** Use when someone wants a progress/status update to hand a client or Product Owner — "give me a status report", "what did we ship this week", "weekly status for the client", "where are we on <milestone>". Not for choosing the next action (that is /steer-next), planning a forward timeline (that is /steer-roadmap), or presenting one feature in depth (that is /steer-explain); this summarizes progress across the whole spine over a time window.

**Arguments.** [this-week | since <date> | milestone [<name>]]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/status/SKILL.md` (invoked as `/steer:status` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
