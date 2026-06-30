---
mode: agent
description: 'Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine. Version-stamps and commits the binary plus a normalized Markdown extraction under spec/sources/<source-id>/, git-diffs the new version against the prior extraction, and surfaces a structured what-changed report. Then routes the real changes into intent/contract/vision/roadmap and the tracker by delegating to /steer:spec-scaffold, /steer:tracker-sync, /steer:audit and /steer:questions — never clobbering human-authored prose: conflicts become Open questions, every absorbed change appends a HISTORY.md entry, drift is surfaced for a human and never resolved silently. Idempotent: re-running on an unchanged document is a no-op.'
---

<!-- Generated from the steer plugin's skills/intake/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:intake` workflow for GitHub Copilot in VS Code.

**Purpose.** Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine. Version-stamps and commits the binary plus a normalized Markdown extraction under spec/sources/<source-id>/, git-diffs the new version against the prior extraction, and surfaces a structured what-changed report. Then routes the real changes into intent/contract/vision/roadmap and the tracker by delegating to /steer:spec-scaffold, /steer:tracker-sync, /steer:audit and /steer:questions — never clobbering human-authored prose: conflicts become Open questions, every absorbed change appends a HISTORY.md entry, drift is surfaced for a human and never resolved silently. Idempotent: re-running on an unchanged document is a no-op.

**When to use.** Use when a Product Owner hands over a new or updated office document (a spec, a roadmap, a requirements deck, a spreadsheet) and the team needs to detect what changed versus the last version and propagate the real changes into /spec and the tracker without losing human-authored content. Reach for it whenever a re-sent document arrives with no pointer to what was edited.

**Arguments.** [<path-to-doc> | <source-id> | status]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:intake`); this capsule carries the intent so Copilot can drive the same workflow here.
