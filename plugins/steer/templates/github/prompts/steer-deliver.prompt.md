---
mode: agent
description: Run a task through a review-gated execution loop — plan, an independent plan-gate review, your sign-off, implementation (delegated to /steer:work in GitHub-adopted repos, direct in prototype/local mode), an independent code-review gate, and a bounded fix loop — so the output is vetted, not first-draft. Orchestrates and reviews; delegates governed implementation rather than owning a second path.
---

<!-- Generated from the steer plugin's skills/deliver/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:deliver` workflow for GitHub Copilot in VS Code.

**Purpose.** Run a task through a review-gated execution loop — plan, an independent plan-gate review, your sign-off, implementation (delegated to /steer:work in GitHub-adopted repos, direct in prototype/local mode), an independent code-review gate, and a bounded fix loop — so the output is vetted, not first-draft. Orchestrates and reviews; delegates governed implementation rather than owning a second path.

**When to use.** Use when you want a non-trivial task carried out with review built in rather than in one straight pass — "deliver X carefully", "do this with review", or any change where a wrong approach would be costly to unwind. For routine issue execution without the extra gates, use /steer:work directly; for trivial edits, just make them.

**Arguments.** [task description]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:deliver`); this capsule carries the intent so Copilot can drive the same workflow here.
