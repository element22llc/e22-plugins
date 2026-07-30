---
mode: agent
description: Create a numbered ADR from the bundled template, then offer its Deciders in-session ratification; `accept` writes the Proposed → Accepted transition.
---

<!-- Generated from the steer plugin's skills/adr/SKILL.md — do not edit by hand. Refresh with /steer:sync from Claude Code in a managed repo, or mise run gen:copilot in the plugin repo. -->

This mirrors steer's `/steer:adr` workflow for GitHub Copilot in VS Code.

**Purpose.** Create a numbered ADR from the bundled template, then offer its Deciders in-session ratification; `accept` writes the Proposed → Accepted transition.

**When to use.** Use for any hard-to-reverse or cross-cutting choice (stack, database, auth, deployment, new pattern), when asked to record a decision, or when a Decider ratifies a `Proposed` ADR ("accept ADR 0007") — including one drafted earlier.

**Arguments.** [<slug> | accept <n>]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/adr/SKILL.md` (invoked as `/steer:adr` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
