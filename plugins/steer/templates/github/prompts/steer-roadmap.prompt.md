---
mode: agent
description: Generate a release timeline for the /spec spine as a GitHub Projects v2 roadmap — intended-but-unshipped work becomes issues grouped under release milestones with due dates. The issue + /spec stay canonical; never fabricates dates.
---

<!-- Generated from the steer plugin's skills/roadmap/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:roadmap` workflow for GitHub Copilot in VS Code.

**Purpose.** Generate a release timeline for the /spec spine as a GitHub Projects v2 roadmap — intended-but-unshipped work becomes issues grouped under release milestones with due dates. The issue + /spec stay canonical; never fabricates dates.

**When to use.** Use for a roadmap, release plan, or Projects v2 timeline — laying out where the product is going or turning target features into milestone-grouped issues.

**Arguments.** [from-features | from-gap | sync]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/roadmap/SKILL.md` (invoked as `/steer:roadmap` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
