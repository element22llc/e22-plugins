---
mode: agent
description: Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → PR for dev review, with Claude driving all tooling.
---

<!-- Generated from the steer plugin's skills/build/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:build` workflow for GitHub Copilot in VS Code.

**Purpose.** Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → PR for dev review, with Claude driving all tooling.

**When to use.** Use when a non-developer wants to build or prototype an app idea, or to resume a PO build whose repo already has /spec/BUILD-STATUS.md.

**Arguments.** [idea or product description]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:build`); this capsule carries the intent so Copilot can drive the same workflow here.
