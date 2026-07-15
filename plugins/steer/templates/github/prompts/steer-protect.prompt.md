---
mode: agent
description: 'Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo: read policy/branch-protection.yml, diff it against the repo''s live protection, and on explicit confirmation apply the missing settings via gh api (branch protection, secret scanning, Dependabot alerts). Verify by default; configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and cannot block local pushes.'
---

<!-- Generated from the steer plugin's skills/protect/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:protect` workflow for GitHub Copilot in VS Code.

**Purpose.** Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo: read policy/branch-protection.yml, diff it against the repo's live protection, and on explicit confirmation apply the missing settings via gh api (branch protection, secret scanning, Dependabot alerts). Verify by default; configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and cannot block local pushes.

**When to use.** Use when asked to "protect main", protect a `prod` / promotion branch, set up or check branch protection / merge rules on a GitHub-adopted repo, or as the final step of init/adopt to establish the PR gate. Also when /steer-audit flags missing or drifted branch protection.

**Arguments.** [verify | apply]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/protect/SKILL.md` (invoked as `/steer:protect` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
