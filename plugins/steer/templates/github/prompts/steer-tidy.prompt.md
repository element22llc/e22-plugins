---
mode: agent
description: Sweep loose files out of the repo root into their correct home — source/research materials (incl. spec/requirements PDFs and docs) to /spec/reference, diagrams to /spec/design. Moves confidently-classified strays immediately; proposes renames and deletes and ambiguous cases for a yes.
---

<!-- Generated from the steer plugin's skills/tidy/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:tidy` workflow for GitHub Copilot in VS Code.

**Purpose.** Sweep loose files out of the repo root into their correct home — source/research materials (incl. spec/requirements PDFs and docs) to /spec/reference, diagrams to /spec/design. Moves confidently-classified strays immediately; proposes renames and deletes and ambiguous cases for a yes.

**When to use.** Use when the repo root is cluttered with spreadsheets, docs, diagrams, exports, or other non-code files, or the user asks to organize, clean up, or tidy the repo.

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/tidy/SKILL.md` (invoked as `/steer:tidy` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
