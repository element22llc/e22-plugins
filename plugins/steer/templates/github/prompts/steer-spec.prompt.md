---
mode: agent
description: 'Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution, WITHOUT writing any code. The no-build counterpart to /steer:build. Also runs `/steer:spec validate [feature-id|--all]`: a local, GitHub-independent structural check over the open-question contract that blocks approval while a blocking question is open. Never touches /apps or /packages; ends at an approved intent, not a build.'
---

<!-- Generated from the steer plugin's skills/spec/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:spec` workflow for GitHub Copilot in VS Code.

**Purpose.** Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution, WITHOUT writing any code. The no-build counterpart to /steer:build. Also runs `/steer:spec validate [feature-id|--all]`: a local, GitHub-independent structural check over the open-question contract that blocks approval while a blocking question is open. Never touches /apps or /packages; ends at an approved intent, not a build.

**When to use.** Use to think a feature through before committing to implementation, shape acceptance criteria, validate a spec's question state, or refine a spec you intend to compare against the code later via /steer:audit spec.

**Arguments.** [feature-id | approve <feature-id> | validate [feature-id | --all]]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:spec`); this capsule carries the intent so Copilot can drive the same workflow here.
