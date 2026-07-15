---
mode: agent
description: Detect and install the local prerequisites a managed repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), and Docker — with per-OS guidance and confirmation-gated installs.
---

<!-- Generated from the steer plugin's skills/doctor/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:doctor` workflow for GitHub Copilot in VS Code.

**Purpose.** Detect and install the local prerequisites a managed repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), and Docker — with per-OS guidance and confirmation-gated installs.

**When to use.** Use on a fresh machine, or whenever a tool is missing ("command not found", "tool not found", mise/docker errors), before /steer-init, /steer-build, or `mise run dev:setup`. /steer-build and /steer-init invoke it when prerequisites are absent.

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/doctor/SKILL.md` (invoked as `/steer:doctor` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
