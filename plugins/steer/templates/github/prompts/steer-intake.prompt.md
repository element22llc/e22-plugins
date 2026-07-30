---
mode: agent
description: Absorb a PO office document (docx/pptx/xlsx/pdf) into the /spec spine — commit the binary plus a normalized Markdown extraction under spec/sources/, diff it against the prior version, report what changed, and route the real changes into the spine and tracker without clobbering human-authored prose. clarify maps a client clarification document to open questions and new scope; status reports a source's absorb state.
---

<!-- Generated from the steer plugin's skills/intake/SKILL.md — do not edit by hand. Refresh with /steer:sync from Claude Code in a managed repo, or mise run gen:copilot in the plugin repo. -->

This mirrors steer's `/steer:intake` workflow for GitHub Copilot in VS Code.

**Purpose.** Absorb a PO office document (docx/pptx/xlsx/pdf) into the /spec spine — commit the binary plus a normalized Markdown extraction under spec/sources/, diff it against the prior version, report what changed, and route the real changes into the spine and tracker without clobbering human-authored prose. clarify maps a client clarification document to open questions and new scope; status reports a source's absorb state.

**When to use.** Use when a Product Owner hands over a new or re-sent spec, roadmap, requirements deck, or spreadsheet and the team needs what changed propagated into /spec and the tracker.

**Arguments.** [<path-to-doc> | clarify <path-to-doc> | <source-id> | status]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/intake/SKILL.md` (invoked as `/steer:intake` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
