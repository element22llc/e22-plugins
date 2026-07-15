---
mode: agent
description: Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → handoff for dev review, with Claude driving all tooling.
---

<!-- Generated from the steer plugin's skills/build/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:build` workflow for GitHub Copilot in VS Code.

**Purpose.** Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → handoff for dev review, with Claude driving all tooling.

**When to use.** Use when a non-developer wants to build or prototype an app idea, or to resume a PO build whose repo already has /spec/BUILD-STATUS.md.

**Arguments.** [idea or product description]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/build/SKILL.md` (invoked as `/steer:build` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
