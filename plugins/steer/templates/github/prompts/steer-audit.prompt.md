---
mode: agent
description: Repeatable, read-only audits of a managed repo — code mode sweeps repo health against the standards and files ranked findings in the tracker; spec mode surfaces as-built vs intended drift; all runs both. Proposes and files, never edits code or spec.
---

<!-- Generated from the steer plugin's skills/audit/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:audit` workflow for GitHub Copilot in VS Code.

**Purpose.** Repeatable, read-only audits of a managed repo — code mode sweeps repo health against the standards and files ranked findings in the tracker; spec mode surfaces as-built vs intended drift; all runs both. Proposes and files, never edits code or spec.

**When to use.** Use for a periodic standards-conformance pass — audit overall code health and the highest-leverage improvements (code), confirm the build matches what the tracker asked for (spec), or both (all).

**Arguments.** [code | spec | all]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/audit/SKILL.md` (invoked as `/steer:audit` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
