---
mode: agent
description: Sweep loose files out of the repo root into their correct home — source/research materials (incl. spec/requirements PDFs and docs) to /spec/reference, diagrams to /spec/design. Moves confidently-classified strays immediately; proposes renames and deletes and ambiguous cases for a yes.
---

<!-- Generated from the steer plugin's skills/tidy/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:tidy` workflow for GitHub Copilot in VS Code.

**Purpose.** Sweep loose files out of the repo root into their correct home — source/research materials (incl. spec/requirements PDFs and docs) to /spec/reference, diagrams to /spec/design. Moves confidently-classified strays immediately; proposes renames and deletes and ambiguous cases for a yes.

**When to use.** Use when the repo root is cluttered with spreadsheets, docs, diagrams, exports, or other non-code files, or the user asks to organize, clean up, or tidy the repo.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:tidy`); this capsule carries the intent so Copilot can drive the same workflow here.
