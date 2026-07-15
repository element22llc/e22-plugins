---
mode: agent
description: Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec. In bundle mode, render the PO-answerable open questions across the whole spine as a shareable, fillable Claude Code Artifact (with a Markdown fallback) so a Product Owner with no repo or Claude Code access can answer them in a browser and send the result back through /steer-intake clarify.
---

<!-- Generated from the steer plugin's skills/questions/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:questions` workflow for GitHub Copilot in VS Code.

**Purpose.** Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec. In bundle mode, render the PO-answerable open questions across the whole spine as a shareable, fillable Claude Code Artifact (with a Markdown fallback) so a Product Owner with no repo or Claude Code access can answer them in a browser and send the result back through /steer-intake clarify.

**When to use.** Use to work down accumulated open questions, before a release or PO→dev handoff, or when asked to resolve or review open questions — including when a client clarification document ingested via /steer-intake clarify supplies answers to fold in. Use bundle mode when you need to hand a Product Owner the open questions to answer offline — it produces a fillable questionnaire (Artifact or Markdown) covering every feature at once.

**Arguments.** [bundle [<feature-id>]]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/questions/SKILL.md` (invoked as `/steer:questions` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
