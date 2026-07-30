---
mode: agent
description: Human-facing capabilities menu — renders the router's intent-to-skill table in plain language, the six essentials first and the rest grouped by journey. Read-only; every line comes from the live router table, and a completeness check proves no front-door row was dropped. Optionally renders an Artifact menu.
---

<!-- Generated from the steer plugin's skills/help/SKILL.md — do not edit by hand. Refresh with /steer-sync in a managed repo, or mise run gen:copilot in the plugin repo. -->

This mirrors steer's `/steer:help` workflow for GitHub Copilot in VS Code.

**Purpose.** Human-facing capabilities menu — renders the router's intent-to-skill table in plain language, the six essentials first and the rest grouped by journey. Read-only; every line comes from the live router table, and a completeness check proves no front-door row was dropped. Optionally renders an Artifact menu.

**When to use.** Use to browse steer's capabilities — "what can steer do?", "show me the commands", "list the skills". Discovery only: "what should I do next" is /steer-next.

**Arguments.** [optional: a skill or area to zoom into]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/help/SKILL.md` (invoked as `/steer:help` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
