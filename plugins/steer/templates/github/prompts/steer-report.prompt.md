---
mode: agent
description: 'File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins. Gathers the defect (a recorded hook fault, a contradictory skill/rule instruction, or a missing/broken template or script), scrubs it of secrets/absolute-paths/product-code, deduplicates against existing upstream issues by a stable fingerprint, shows you the rendered body, and only on your confirmation files it via gh (MCP/gh write, with a paste-ready fallback when upstream access is missing). Detect-and-offer, never auto-file: the upstream write is a permission-prompted human gate. This is for steer''s OWN defects, not product-code bugs (those go to the product tracker via /steer:issues).'
---

<!-- Generated from the steer plugin's skills/report/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:report` workflow for GitHub Copilot in VS Code.

**Purpose.** File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins. Gathers the defect (a recorded hook fault, a contradictory skill/rule instruction, or a missing/broken template or script), scrubs it of secrets/absolute-paths/product-code, deduplicates against existing upstream issues by a stable fingerprint, shows you the rendered body, and only on your confirmation files it via gh (MCP/gh write, with a paste-ready fallback when upstream access is missing). Detect-and-offer, never auto-file: the upstream write is a permission-prompted human gate. This is for steer's OWN defects, not product-code bugs (those go to the product tracker via /steer:issues).

**When to use.** Use when steer itself misbehaves — a SessionStart self-fault notice appears, a skill/rule gives contradictory or impossible instructions, or a referenced template/script/helper is missing or crashes — and you want it fixed upstream. Also when the user says "report this steer bug" / "file this against the plugin".

**Arguments.** [describe the defect | run with no args to use recorded faults]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:report`); this capsule carries the intent so Copilot can drive the same workflow here.
