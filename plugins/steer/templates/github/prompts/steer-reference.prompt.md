---
mode: agent
description: 'Load one of steer''s full reference prose documents by topic — `conventions` (versioning, mise toolchain & lockfiles, backend placement, local services, monorepo, pnpm/uv, Biome/Ruff, Vitest/pytest, commit messages, baseline patterns), `traceability` (natural-language-to-spec routing, action history, app knowledge docs, client-agnostic tracker integration, drift gates, SOC 2 / ISO 27001-aligned delivery), `design-sources` (Claude Design URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md), `context-hygiene` (delegating heavy runs to subagents, keeping durable state in files so it survives compaction), or `architecture-diagrams` (the global system diagram: Mermaid by default vs an opt-in LikeC4 C4 model, which diagram types, and keeping it current). A read-only loader: it points at the bundled reference file and answers from it.'
---

<!-- Generated from the steer plugin's skills/reference/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:reference` workflow for GitHub Copilot in VS Code.

**Purpose.** Load one of steer's full reference prose documents by topic — `conventions` (versioning, mise toolchain & lockfiles, backend placement, local services, monorepo, pnpm/uv, Biome/Ruff, Vitest/pytest, commit messages, baseline patterns), `traceability` (natural-language-to-spec routing, action history, app knowledge docs, client-agnostic tracker integration, drift gates, SOC 2 / ISO 27001-aligned delivery), `design-sources` (Claude Design URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md), `context-hygiene` (delegating heavy runs to subagents, keeping durable state in files so it survives compaction), or `architecture-diagrams` (the global system diagram: Mermaid by default vs an opt-in LikeC4 C4 model, which diagram types, and keeping it current). A read-only loader: it points at the bundled reference file and answers from it.

**When to use.** Use for any tooling/convention question or the rationale behind a stack default (conventions); any question about living docs, tracker refs, drift flags, audit evidence, or the PO-facing vs dev-facing split (traceability); a feature originating from a Claude Design export/URL, Figma, or screenshots (design-sources); how to keep a long/multi-phase run from bloating the session or losing constraints across compaction (context-hygiene); or how to author/maintain the system architecture diagram — Mermaid vs LikeC4 (architecture-diagrams).

**Arguments.** [conventions | traceability | design-sources | context-hygiene | architecture-diagrams]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:reference`); this capsule carries the intent so Copilot can drive the same workflow here.
