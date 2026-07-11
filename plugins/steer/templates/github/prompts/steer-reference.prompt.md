---
mode: agent
description: 'Load one of steer''s full reference prose documents by topic — `conventions` (versioning, mise toolchain & lockfiles, backend placement, local services, monorepo, pnpm/uv, Biome/Ruff, Vitest/pytest, commit messages, baseline patterns), `traceability` (natural-language-to-spec routing, action history, app knowledge docs, client-agnostic tracker integration, drift gates, SOC 2 / ISO 27001-aligned delivery), `design-sources` (Claude Design URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md), `context-hygiene` (delegating heavy runs to subagents, keeping durable state in files so it survives compaction), `architecture-diagrams` (the global system diagram: Mermaid by default vs an opt-in LikeC4 C4 model, which diagram types, and keeping it current), or `artifacts` (producing shareable Claude Artifacts — discipline, CSP/inline mechanics, Markdown fallback). A read-only loader: it points at the bundled reference file and answers from it.'
---

<!-- Generated from the steer plugin's skills/reference/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:reference` workflow for GitHub Copilot in VS Code.

**Purpose.** Load one of steer's full reference prose documents by topic — `conventions` (versioning, mise toolchain & lockfiles, backend placement, local services, monorepo, pnpm/uv, Biome/Ruff, Vitest/pytest, commit messages, baseline patterns), `traceability` (natural-language-to-spec routing, action history, app knowledge docs, client-agnostic tracker integration, drift gates, SOC 2 / ISO 27001-aligned delivery), `design-sources` (Claude Design URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md), `context-hygiene` (delegating heavy runs to subagents, keeping durable state in files so it survives compaction), `architecture-diagrams` (the global system diagram: Mermaid by default vs an opt-in LikeC4 C4 model, which diagram types, and keeping it current), or `artifacts` (producing shareable Claude Artifacts — discipline, CSP/inline mechanics, Markdown fallback). A read-only loader: it points at the bundled reference file and answers from it.

**When to use.** Use for any tooling/convention question or stack-default rationale (conventions); living docs, tracker refs, drift flags, audit evidence, or the PO-vs-dev split (traceability); a feature from a Claude Design export/URL, Figma, or screenshots (design-sources); keeping a long/multi-phase run from bloating the session or losing constraints across compaction (context-hygiene); authoring the system architecture diagram — Mermaid vs LikeC4 (architecture-diagrams); or rendering a shareable page as a Claude Artifact (artifacts).

**Arguments.** [conventions | traceability | design-sources | context-hygiene | architecture-diagrams | artifacts]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:reference`); this capsule carries the intent so Copilot can drive the same workflow here.
