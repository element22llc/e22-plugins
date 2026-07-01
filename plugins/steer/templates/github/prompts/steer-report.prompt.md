---
mode: agent
description: File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins — gather the defect, scrub secrets/absolute-paths/product-code, dedupe against existing upstream issues, and file via gh only on your confirmation (detect-and-offer, never auto-file). For steer's own defects, not product-code bugs (those go to the product tracker via /steer:issues).
---

<!-- Generated from the steer plugin's skills/report/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:report` workflow for GitHub Copilot in VS Code.

**Purpose.** File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins — gather the defect, scrub secrets/absolute-paths/product-code, dedupe against existing upstream issues, and file via gh only on your confirmation (detect-and-offer, never auto-file). For steer's own defects, not product-code bugs (those go to the product tracker via /steer:issues).

**When to use.** Use when steer itself misbehaves — a SessionStart self-fault notice appears, a skill/rule gives contradictory or impossible instructions, or a referenced template/script/helper is missing or crashes — and you want it fixed upstream. Also when the user says "report this steer bug" / "file this against the plugin".

**Arguments.** [describe the defect | run with no args to use recorded faults]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:report`); this capsule carries the intent so Copilot can drive the same workflow here.
