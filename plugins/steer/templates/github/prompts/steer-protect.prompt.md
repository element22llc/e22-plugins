---
mode: agent
description: Make GitHub branch protection reliable — diff policy/branch-protection.yml against live settings and, on confirmation, apply the missing pieces via gh api (protection, secret scanning, Dependabot alerts). Graduation also flips the CLAUDE.md delivery-mode marker. Verify by default.
---

<!-- Generated from the steer plugin's skills/protect/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:protect` workflow for GitHub Copilot in VS Code.

**Purpose.** Make GitHub branch protection reliable — diff policy/branch-protection.yml against live settings and, on confirmation, apply the missing pieces via gh api (protection, secret scanning, Dependabot alerts). Graduation also flips the CLAUDE.md delivery-mode marker. Verify by default.

**When to use.** Use when asked to protect main or a prod branch, check branch protection / merge rules, graduate solo trunk to PR flow, or as the last step of init/adopt.

**Arguments.** [verify | apply]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/protect/SKILL.md` (invoked as `/steer:protect` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
