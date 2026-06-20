---
mode: agent
description: 'Repeatable, read-only, whole-repo health audit of a managed repo — sweeps the code across standards dimensions (architecture, data layer, validation, errors, tests, deps, design, spec coverage), vets each finding against the cited code, ranks by leverage (impact ÷ effort × confidence), proposes routing into /spec, and files findings in the tracker. Repository-read-only: it proposes spec changes and files tracker issues, but never edits code or spec and never commits. Defers correctness to /code-review and security to /security-review.'
---

<!-- Generated from the steer plugin's skills/audit/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:audit` workflow for GitHub Copilot in VS Code.

**Purpose.** Repeatable, read-only, whole-repo health audit of a managed repo — sweeps the code across standards dimensions (architecture, data layer, validation, errors, tests, deps, design, spec coverage), vets each finding against the cited code, ranks by leverage (impact ÷ effort × confidence), proposes routing into /spec, and files findings in the tracker. Repository-read-only: it proposes spec changes and files tracker issues, but never edits code or spec and never commits. Defers correctness to /code-review and security to /security-review.

**When to use.** Use to audit overall code health, find the highest-leverage improvements, or do a periodic standards-conformance pass on a steady-state repo.

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:audit`); this capsule carries the intent so Copilot can drive the same workflow here.
