---
mode: agent
description: Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine — version-stamp and commit the binary plus a normalized Markdown extraction under spec/sources/, git-diff it against the prior version, and surface a structured what-changed report. Then route the real changes into intent/contract/vision/roadmap and the tracker via the relevant skills, never clobbering human-authored prose (conflicts become Open questions). Idempotent on an unchanged document.
---

<!-- Generated from the steer plugin's skills/intake/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:intake` workflow for GitHub Copilot in VS Code.

**Purpose.** Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine — version-stamp and commit the binary plus a normalized Markdown extraction under spec/sources/, git-diff it against the prior version, and surface a structured what-changed report. Then route the real changes into intent/contract/vision/roadmap and the tracker via the relevant skills, never clobbering human-authored prose (conflicts become Open questions). Idempotent on an unchanged document.

**When to use.** Use when a Product Owner hands over a new or updated office document (a spec, a roadmap, a requirements deck, a spreadsheet) and the team needs to detect what changed versus the last version and propagate the real changes into /spec and the tracker without losing human-authored content. Reach for it whenever a re-sent document arrives with no pointer to what was edited.

**Arguments.** [<path-to-doc> | <source-id> | status]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:intake`); this capsule carries the intent so Copilot can drive the same workflow here.
