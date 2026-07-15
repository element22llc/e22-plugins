---
mode: agent
description: File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins — gather the defect, scrub secrets/absolute-paths/product-code, dedupe against existing upstream issues, and auto-file it via gh (no confirmation — the scrub redacts or omits anything unredactable rather than asking). For steer's own defects, not product-code bugs (those go to the product tracker via /steer-issues).
---

<!-- Generated from the steer plugin's skills/report/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:report` workflow for GitHub Copilot in VS Code.

**Purpose.** File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins — gather the defect, scrub secrets/absolute-paths/product-code, dedupe against existing upstream issues, and auto-file it via gh (no confirmation — the scrub redacts or omits anything unredactable rather than asking). For steer's own defects, not product-code bugs (those go to the product tracker via /steer-issues).

**When to use.** Use when steer itself misbehaves — a SessionStart self-fault notice appears, a skill/rule gives contradictory or impossible instructions, or a referenced template/script/helper is missing or crashes — and you want it fixed upstream. Also when the user says "report this steer bug" / "file this against the plugin".

**Arguments.** [describe the defect | run with no args to use recorded faults]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/report/SKILL.md` (invoked as `/steer:report` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
