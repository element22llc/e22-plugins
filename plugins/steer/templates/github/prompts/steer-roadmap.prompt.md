---
mode: agent
description: 'Generate a release timeline for the /spec spine and make it viewable as a GitHub Projects v2 roadmap — turn intended-but-unshipped work (target features, or a spec-gap surfaced by /steer:audit spec) into GitHub issues grouped under release Milestones with due dates. A thin orchestrator: it delegates issue creation to /steer:issues, gap detection to /steer:audit spec, and routes ALL GitHub I/O through /steer:tracker-sync. The issue + /spec stay canonical; the Project is a derived view. It proposes a dependency-ordered milestone plan and never fabricates dates.'
---

<!-- Generated from the steer plugin's skills/roadmap/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:roadmap` workflow for GitHub Copilot in VS Code.

**Purpose.** Generate a release timeline for the /spec spine and make it viewable as a GitHub Projects v2 roadmap — turn intended-but-unshipped work (target features, or a spec-gap surfaced by /steer:audit spec) into GitHub issues grouped under release Milestones with due dates. A thin orchestrator: it delegates issue creation to /steer:issues, gap detection to /steer:audit spec, and routes ALL GitHub I/O through /steer:tracker-sync. The issue + /spec stay canonical; the Project is a derived view. It proposes a dependency-ordered milestone plan and never fabricates dates.

**When to use.** Use to lay out where the product is going on a timeline — when asked for a roadmap, a release plan, or a Projects v2 timeline, or to turn target features or a spec-vs-implemented gap into milestone-grouped GitHub issues.

**Arguments.** [from-features | from-gap | sync]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:roadmap`); this capsule carries the intent so Copilot can drive the same workflow here.
