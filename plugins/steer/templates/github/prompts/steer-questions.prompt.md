---
mode: agent
description: Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec.
---

<!-- Generated from the steer plugin's skills/questions/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:questions` workflow for GitHub Copilot in VS Code.

**Purpose.** Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec.

**When to use.** Use to work down accumulated open questions, before a release or PO→dev handoff, or when asked to resolve or review open questions.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:questions`); this capsule carries the intent so Copilot can drive the same workflow here.
