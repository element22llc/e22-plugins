---
mode: agent
description: Execute a GitHub issue end-to-end from local Claude Code — read and validate the issue, claim it, create or reuse a branch, load linked specs, implement, test, update progress on the issue, open the PR, and transition lifecycle state. The execution counterpart to /steer:issues (which owns backlog management and never edits code). Routes all tracker-metadata I/O through /steer:tracker-sync; git and PR delivery follow the repo's commit/PR-autonomy rules and delivery mode — in solo-trunk mode it commits straight to main and closes the issue from the trunk commit instead of branching and opening a PR. One issue per branch/PR (or trunk commit) by default. Pass --reviewed to wrap execution in independent plan- and code-review gates plus a bounded fix loop (the review-gated path formerly the deliver skill) — vetted, not first-draft.
---

<!-- Generated from the steer plugin's skills/work/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:work` workflow for GitHub Copilot in VS Code.

**Purpose.** Execute a GitHub issue end-to-end from local Claude Code — read and validate the issue, claim it, create or reuse a branch, load linked specs, implement, test, update progress on the issue, open the PR, and transition lifecycle state. The execution counterpart to /steer:issues (which owns backlog management and never edits code). Routes all tracker-metadata I/O through /steer:tracker-sync; git and PR delivery follow the repo's commit/PR-autonomy rules and delivery mode — in solo-trunk mode it commits straight to main and closes the issue from the trunk commit instead of branching and opening a PR. One issue per branch/PR (or trunk commit) by default. Pass --reviewed to wrap execution in independent plan- and code-review gates plus a bounded fix loop (the review-gated path formerly the deliver skill) — vetted, not first-draft.

**When to use.** Use when asked to work, start, resume, or finish a specific issue ("work on

**Arguments.** [start | resume | status | finish] [--reviewed] [#issue ...]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:work`); this capsule carries the intent so Copilot can drive the same workflow here.
