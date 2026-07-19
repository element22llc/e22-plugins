---
mode: agent
description: File a bug about the steer plugin itself upstream in element22llc/e22-plugins — gather the defect, scrub secrets/paths/product code, dedupe against existing issues, and auto-file via gh. For steer's own defects, not product bugs (those go to /steer-issues).
---

<!-- Generated from the steer plugin's skills/report/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:report` workflow for GitHub Copilot in VS Code.

**Purpose.** File a bug about the steer plugin itself upstream in element22llc/e22-plugins — gather the defect, scrub secrets/paths/product code, dedupe against existing issues, and auto-file via gh. For steer's own defects, not product bugs (those go to /steer-issues).

**When to use.** Use when steer misbehaves — a SessionStart self-fault notice, contradictory or impossible skill/rule instructions, a missing or crashing bundled helper — or on "report this steer bug".

**Arguments.** [describe the defect | run with no args to use recorded faults]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/report/SKILL.md` (invoked as `/steer:report` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
