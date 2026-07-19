---
mode: agent
description: Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution WITHOUT writing any code; `validate` checks the open-question contract. Ends at an approved intent, not a build.
---

<!-- Generated from the steer plugin's skills/spec/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:spec` workflow for GitHub Copilot in VS Code.

**Purpose.** Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution WITHOUT writing any code; `validate` checks the open-question contract. Ends at an approved intent, not a build.

**When to use.** Use to think a feature through before committing to implementation, shape acceptance criteria, or validate a spec's question state (/steer-spec validate). Works spec-only on an unmanaged repo (lite mode) — no bootstrap required.

**Arguments.** [feature-id | approve <feature-id> | validate [feature-id | --all]]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/spec/SKILL.md` (invoked as `/steer:spec` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
