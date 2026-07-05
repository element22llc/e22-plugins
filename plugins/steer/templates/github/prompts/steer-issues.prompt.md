---
mode: agent
description: 'High-level GitHub Issues lifecycle for the /spec spine — capture, triage, brainstorm, materialize, decompose, epic grouping, status, a ranked relationship-aware board view, and bounded reconcile. A thin orchestrator: it delegates product/spec reasoning to /steer:spec, audit findings to /steer:audit, drift to /steer:audit spec, and question promotion to /steer:questions, and routes GitHub reads/writes through /steer:tracker-sync (MCP-first, gh fallback, manual floor) — with one sanctioned exception, the bootstrap-labels mode''s inline label creation. Agent-authored issues follow the machine-readable contract (stable headings + hidden markers + managed blocks). /spec stays product truth; the issue is the work/decision layer.'
---

<!-- Generated from the steer plugin's skills/issues/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:issues` workflow for GitHub Copilot in VS Code.

**Purpose.** High-level GitHub Issues lifecycle for the /spec spine — capture, triage, brainstorm, materialize, decompose, epic grouping, status, a ranked relationship-aware board view, and bounded reconcile. A thin orchestrator: it delegates product/spec reasoning to /steer:spec, audit findings to /steer:audit, drift to /steer:audit spec, and question promotion to /steer:questions, and routes GitHub reads/writes through /steer:tracker-sync (MCP-first, gh fallback, manual floor) — with one sanctioned exception, the bootstrap-labels mode's inline label creation. Agent-authored issues follow the machine-readable contract (stable headings + hidden markers + managed blocks). /spec stays product truth; the issue is the work/decision layer.

**When to use.** Use to drive a PO idea from capture to a draft spec to decomposed work without losing open questions or overwriting human content.

**Arguments.** [capture | triage | brainstorm | materialize | decompose | epic | status | board | reconcile | publish-audit | publish-drift | publish-adoption | publish-findings | bootstrap-labels] [#issue | feature-id]

Apply the org engineering standards already loaded from `.github/copilot-instructions.md`. The authoritative procedure lives in the steer plugin (in Claude Code, `/steer:issues`); this capsule carries the intent so Copilot can drive the same workflow here.
