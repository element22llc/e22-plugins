---
mode: agent
description: Sweep every open question across the /spec spine and walk the PO/dev through answering each one, folding decisions back into the spec. bundle mode renders the PO-answerable questions as a fillable questionnaire (Claude Artifact with Markdown fallback) to answer offline.
---

<!-- Generated from the steer plugin's skills/questions/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:questions` workflow for GitHub Copilot in VS Code.

**Purpose.** Sweep every open question across the /spec spine and walk the PO/dev through answering each one, folding decisions back into the spec. bundle mode renders the PO-answerable questions as a fillable questionnaire (Claude Artifact with Markdown fallback) to answer offline.

**When to use.** Use to work down accumulated open questions, before a release or PO-to-dev handoff, or to fold in answers ingested via /steer-intake clarify; use bundle mode to hand a Product Owner the open questions across every feature at once.

**Arguments.** [bundle [<feature-id>]]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/questions/SKILL.md` (invoked as `/steer:questions` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
