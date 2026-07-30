---
mode: agent
description: Detect the local prerequisites a managed repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), Docker — flagging shadowed runtimes; installs mise + runtimes on confirmation, GUI steps handed over.
---

<!-- Generated from the steer plugin's skills/doctor/SKILL.md — do not edit by hand. Refresh with /steer:sync from Claude Code in a managed repo, or mise run gen:copilot in the plugin repo. -->

This mirrors steer's `/steer:doctor` workflow for GitHub Copilot in VS Code.

**Purpose.** Detect the local prerequisites a managed repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), Docker — flagging shadowed runtimes; installs mise + runtimes on confirmation, GUI steps handed over.

**When to use.** Use on a fresh machine, or whenever a tool is missing ("command not found", "tool not found", mise/docker errors), before /steer-init, /steer-build, or `mise run dev:setup`.

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/doctor/SKILL.md` (invoked as `/steer:doctor` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
