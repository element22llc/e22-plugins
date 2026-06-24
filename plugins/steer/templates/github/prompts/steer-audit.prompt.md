---
mode: agent
description: 'Repeatable, read-only audits of a managed repo behind one skill. `code` mode (default) is a whole-repo code-vs-standards health sweep across the standards dimensions (architecture, data layer, validation, errors, tests, deps, design, spec coverage), vets each finding against the cited code, ranks by leverage (impact ÷ effort × confidence), proposes routing into /spec, and files findings in the tracker. `spec` mode compares the as-built /spec (reverse-engineered by /steer:adopt) against the intended spec exported from the issue tracker and surfaces every divergence (the former drift skill). `all` runs both. Repository-read-only: it proposes spec changes and files tracker issues, but never edits code or spec and never commits. Defers correctness to /code-review and security to /security-review.'
---

<!-- Generated from the steer plugin's skills/audit/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:audit` workflow for GitHub Copilot in VS Code.

**Purpose.** Repeatable, read-only audits of a managed repo behind one skill. `code` mode (default) is a whole-repo code-vs-standards health sweep across the standards dimensions (architecture, data layer, validation, errors, tests, deps, design, spec coverage), vets each finding against the cited code, ranks by leverage (impact ÷ effort × confidence), proposes routing into /spec, and files findings in the tracker. `spec` mode compares the as-built /spec (reverse-engineered by /steer:adopt) against the intended spec exported from the issue tracker and surfaces every divergence (the former drift skill). `all` runs both. Repository-read-only: it proposes spec changes and files tracker issues, but never edits code or spec and never commits. Defers correctness to /code-review and security to /security-review.

**When to use.** Use to audit overall code health and find the highest-leverage improvements (code), to confirm the build matches what the tracker asked for (spec), or both (all) — a periodic standards-conformance pass on a steady-state repo.

**Arguments.** [code | spec | all]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:audit`); this capsule carries the intent so Copilot can drive the same workflow here.
