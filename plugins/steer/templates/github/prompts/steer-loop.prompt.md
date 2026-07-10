---
mode: agent
description: 'Scaffold an autonomous loop for a managed repo — a scheduled GitHub Actions workflow that wakes on its own, triages work (CI failures, open issues, drift) via /steer:audit + /steer:next, drafts fixes in isolated worktrees reviewed by steer-reviewer, and opens draft PRs. Wired to stop at every human gate (rule 53): it delivers up to the PR, it never merges/deploys. Instantiates templates/github/workflows/steer-loop.yml and lands it via the normal autonomous branch-push + PR (Commit autonomy — the merge review is the gate).'
---

<!-- Generated from the steer plugin's skills/loop/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:loop` workflow for GitHub Copilot in VS Code.

**Purpose.** Scaffold an autonomous loop for a managed repo — a scheduled GitHub Actions workflow that wakes on its own, triages work (CI failures, open issues, drift) via /steer:audit + /steer:next, drafts fixes in isolated worktrees reviewed by steer-reviewer, and opens draft PRs. Wired to stop at every human gate (rule 53): it delivers up to the PR, it never merges/deploys. Instantiates templates/github/workflows/steer-loop.yml and lands it via the normal autonomous branch-push + PR (Commit autonomy — the merge review is the gate).

**When to use.** Use when someone wants to automate steer's triage/fix loop instead of prompting it each turn — "set up a nightly loop", "automate CI-failure triage", "have Claude sweep the backlog on a schedule", "loop engineering for this repo". Also the follow-up when /steer:audit or /steer:next keeps surfacing the same recurring sweep. Verify or remove an existing loop with the verify/remove modes.

**Arguments.** [scaffold | verify | remove]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:loop`); this capsule carries the intent so Copilot can drive the same workflow here.
