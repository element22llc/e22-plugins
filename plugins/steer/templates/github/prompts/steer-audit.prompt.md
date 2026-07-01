---
mode: agent
description: 'Repeatable, read-only audits of a managed repo: `code` mode (default) sweeps the whole repo against the standards dimensions, ranks findings by leverage, and files them in the tracker; `spec` mode compares the as-built /spec against the intended spec from the tracker and surfaces drift; `all` runs both. Repository-read-only — proposes spec changes and files issues but never edits code/spec or commits; defers correctness to /code-review and security to /security-review.'
---

<!-- Generated from the steer plugin's skills/audit/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:audit` workflow for GitHub Copilot in VS Code.

**Purpose.** Repeatable, read-only audits of a managed repo: `code` mode (default) sweeps the whole repo against the standards dimensions, ranks findings by leverage, and files them in the tracker; `spec` mode compares the as-built /spec against the intended spec from the tracker and surfaces drift; `all` runs both. Repository-read-only — proposes spec changes and files issues but never edits code/spec or commits; defers correctness to /code-review and security to /security-review.

**When to use.** Use to audit overall code health and find the highest-leverage improvements (code), to confirm the build matches what the tracker asked for (spec), or both (all) — a periodic standards-conformance pass on a steady-state repo.

**Arguments.** [code | spec | all]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:audit`); this capsule carries the intent so Copilot can drive the same workflow here.
