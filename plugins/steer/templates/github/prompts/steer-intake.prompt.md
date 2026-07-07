---
mode: agent
description: 'Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine — version-stamp and commit the binary plus a normalized Markdown extraction under spec/sources/ — relocating the dropped file into that canonical home so it does not linger where it was uploaded — git-diff it against the prior version, and surface a structured what-changed report. Then route the real changes into intent/contract/vision/roadmap and the tracker via the relevant skills, never clobbering human-authored prose (conflicts become Open questions). Idempotent on an unchanged document. In clarify mode, absorbs a client clarification document instead: it segments the extraction, maps each unit against open questions and the feature list, and sorts them into a three-bucket worklist — answers routed to /steer:questions, new scope to the reconcile rows, unmatched surfaced for the human.'
---

<!-- Generated from the steer plugin's skills/intake/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:intake` workflow for GitHub Copilot in VS Code.

**Purpose.** Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine — version-stamp and commit the binary plus a normalized Markdown extraction under spec/sources/ — relocating the dropped file into that canonical home so it does not linger where it was uploaded — git-diff it against the prior version, and surface a structured what-changed report. Then route the real changes into intent/contract/vision/roadmap and the tracker via the relevant skills, never clobbering human-authored prose (conflicts become Open questions). Idempotent on an unchanged document. In clarify mode, absorbs a client clarification document instead: it segments the extraction, maps each unit against open questions and the feature list, and sorts them into a three-bucket worklist — answers routed to /steer:questions, new scope to the reconcile rows, unmatched surfaced for the human.

**When to use.** Use when a Product Owner hands over a new or updated office document (a spec, a roadmap, a requirements deck, a spreadsheet) and the team needs to detect what changed versus the last version and propagate the real changes into /spec and the tracker without losing human-authored content. Reach for it whenever a re-sent document arrives with no pointer to what was edited. Use clarify mode when a client hands over a clarification document that answers open questions and/or introduces new scope, and the team needs each point mapped to the spine without hand-supplying question IDs.

**Arguments.** [<path-to-doc> | clarify <path-to-doc> | <source-id> | status]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:intake`); this capsule carries the intent so Copilot can drive the same workflow here.
