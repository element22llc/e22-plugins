---
mode: agent
description: Bring an already-bootstrapped managed repo up to date with the current plugin — update the plugin, apply pending structural migrations from the ledger (renames/moves the additive reconciliation can't express), reconcile the materialized spec spine + scaffold against the current templates, repair missing or mis-wired capability-critical scaffold (plugin enablement, in-CI loading, version-pin enforcement, drift gate, branch-protection), re-stamp /spec/.version, and land a PR. Supports a read-only --check mode. Read-then-propose, never clobbers, never commits to main.
---

<!-- Generated from the steer plugin's skills/sync/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:sync` workflow for GitHub Copilot in VS Code.

**Purpose.** Bring an already-bootstrapped managed repo up to date with the current plugin — update the plugin, apply pending structural migrations from the ledger (renames/moves the additive reconciliation can't express), reconcile the materialized spec spine + scaffold against the current templates, repair missing or mis-wired capability-critical scaffold (plugin enablement, in-CI loading, version-pin enforcement, drift gate, branch-protection), re-stamp /spec/.version, and land a PR. Supports a read-only --check mode. Read-then-propose, never clobbers, never commits to main.

**When to use.** Use on a steady-state repo after a plugin release, when a spec file/section was renamed upstream, when a repo adopted before a capability existed is missing the scaffold/wiring that enables it, or when asked to "sync to the latest standards / plugin version". Pass --check for a read-only capability + drift report with no branch or PR.

**Arguments.** [--check]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:sync`); this capsule carries the intent so Copilot can drive the same workflow here.
