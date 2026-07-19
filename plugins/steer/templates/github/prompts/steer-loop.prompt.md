---
mode: agent
description: Scaffold an autonomous loop for a managed repo — a scheduled GitHub Actions workflow that triages work (CI failures, open issues, drift) via /steer-audit + /steer-next, drafts fixes in reviewed worktrees, and opens draft PRs. Stops at every human gate; never merges or deploys.
---

<!-- Generated from the steer plugin's skills/loop/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:loop` workflow for GitHub Copilot in VS Code.

**Purpose.** Scaffold an autonomous loop for a managed repo — a scheduled GitHub Actions workflow that triages work (CI failures, open issues, drift) via /steer-audit + /steer-next, drafts fixes in reviewed worktrees, and opens draft PRs. Stops at every human gate; never merges or deploys.

**When to use.** Use to automate steer's triage/fix sweep on a schedule — "set up a nightly loop", "sweep the backlog on a schedule" — or when audits keep surfacing the same recurring sweep; verify/remove modes manage an existing loop.

**Arguments.** [scaffold | verify | remove]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/loop/SKILL.md` (invoked as `/steer:loop` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
