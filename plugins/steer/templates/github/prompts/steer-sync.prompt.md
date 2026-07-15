---
mode: agent
description: Bring an already-bootstrapped managed repo up to date with the current plugin — apply pending structural migrations from the ledger, reconcile the spec spine + scaffold against current templates, repair missing or mis-wired capability-critical wiring, re-stamp /spec/.version, and land a PR. Supports a read-only --check mode; read-then-propose, never clobbers, never commits to main.
---

<!-- Generated from the steer plugin's skills/sync/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:sync` workflow for GitHub Copilot in VS Code.

**Purpose.** Bring an already-bootstrapped managed repo up to date with the current plugin — apply pending structural migrations from the ledger, reconcile the spec spine + scaffold against current templates, repair missing or mis-wired capability-critical wiring, re-stamp /spec/.version, and land a PR. Supports a read-only --check mode; read-then-propose, never clobbers, never commits to main.

**When to use.** Use on a steady-state repo after a plugin release, when a spec file/section was renamed upstream, when a repo adopted before a capability existed is missing the scaffold/wiring that enables it, or when asked to "sync to the latest standards / plugin version". Pass --check for a read-only capability + drift report with no branch or PR.

**Arguments.** [--check]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/sync/SKILL.md` (invoked as `/steer:sync` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
