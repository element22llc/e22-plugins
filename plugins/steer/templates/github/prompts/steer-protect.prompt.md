---
mode: agent
description: 'Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo: read policy/branch-protection.yml, diff it against the repo''s live protection, and on explicit confirmation apply the missing settings via gh api (branch protection, secret scanning, Dependabot alerts). Verify by default; configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and cannot block local pushes.'
---

<!-- Generated from the steer plugin's skills/protect/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:protect` workflow for GitHub Copilot in VS Code.

**Purpose.** Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo: read policy/branch-protection.yml, diff it against the repo's live protection, and on explicit confirmation apply the missing settings via gh api (branch protection, secret scanning, Dependabot alerts). Verify by default; configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and cannot block local pushes.

**When to use.** Use when asked to "protect main", protect a `prod` / promotion branch, set up or check branch protection / merge rules on a GitHub-adopted repo, or as the final step of init/adopt to establish the PR gate. Also when /steer:audit flags missing or drifted branch protection.

**Arguments.** [verify | apply]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:protect`); this capsule carries the intent so Copilot can drive the same workflow here.
