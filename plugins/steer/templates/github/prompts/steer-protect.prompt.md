---
mode: agent
description: Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo. Reads the machine-readable policy (policy/branch-protection.yml, consumer-first then plugin default), queries the repo's live protection via gh, reports a per-rule compliant/drifted/absent diff, and on the dev's explicit confirmation applies the missing settings via gh api — branch protection plus the repo-level settings the policy declares (secret scanning, Dependabot alerts + security updates). Verify by default; never writes repo settings without a yes. Configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and this skill does not and cannot block local pushes.
---

<!-- Generated from the steer plugin's skills/protect/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:protect` workflow for GitHub Copilot in VS Code.

**Purpose.** Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo. Reads the machine-readable policy (policy/branch-protection.yml, consumer-first then plugin default), queries the repo's live protection via gh, reports a per-rule compliant/drifted/absent diff, and on the dev's explicit confirmation applies the missing settings via gh api — branch protection plus the repo-level settings the policy declares (secret scanning, Dependabot alerts + security updates). Verify by default; never writes repo settings without a yes. Configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and this skill does not and cannot block local pushes.

**When to use.** Use when asked to "protect main", set up or check branch protection / merge rules on a GitHub-adopted repo, or as the final step of init/adopt to establish the PR gate. Also when /steer:audit flags missing or drifted branch protection.

**Arguments.** [verify | apply]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:protect`); this capsule carries the intent so Copilot can drive the same workflow here.
