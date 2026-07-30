---
mode: agent
description: 'Load one of steer''s full reference docs on demand: conventions (toolchain, stack defaults, commit style), traceability (spec routing, living docs, tracker, drift, audit evidence), design-sources, context-hygiene (subagents, durable state on long runs), architecture-diagrams (Mermaid vs LikeC4), artifacts, gates, or polyrepo. Read-only loader.'
---

<!-- Generated from the steer plugin's skills/reference/SKILL.md — do not edit by hand. Refresh with /steer-sync in a managed repo, or mise run gen:copilot in the plugin repo. -->

This mirrors steer's `/steer:reference` workflow for GitHub Copilot in VS Code.

**Purpose.** Load one of steer's full reference docs on demand: conventions (toolchain, stack defaults, commit style), traceability (spec routing, living docs, tracker, drift, audit evidence), design-sources, context-hygiene (subagents, durable state on long runs), architecture-diagrams (Mermaid vs LikeC4), artifacts, gates, or polyrepo. Read-only loader.

**When to use.** Use for any tooling/convention question or stack-default rationale, living- docs/tracker/drift questions, a feature built from a design export or screenshots, keeping a long multi-phase run lean across compaction, the system architecture diagram, rendering a shareable Artifact, ratifying an ADR or approving an intent in-session, or a product whose spine spans several repos.

**Arguments.** [conventions | traceability | design-sources | context-hygiene | architecture-diagrams | artifacts | gates | polyrepo]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/reference/SKILL.md` (invoked as `/steer:reference` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
