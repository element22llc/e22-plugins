---
mode: agent
description: 'Render a high-level, stakeholder-readable view of one feature spec as a shareable Claude Code Artifact — a private, hosted page on claude.ai, built around at-a-glance visuals (a status pipeline, an acceptance meter, a clickable user-journey, scope and open-question boards) so it reads in seconds instead of pages — with a Markdown fallback where Artifacts are unavailable. A read-only, derived view: the /spec and tracker item stay canonical; every visual encodes a real spec value, never fabricates status, dates, or acceptance criteria, never auto-generates per feature, and never writes into /spec, /apps, or /packages.'
---

<!-- Generated from the steer plugin's skills/explain/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:explain` workflow for GitHub Copilot in VS Code.

**Purpose.** Render a high-level, stakeholder-readable view of one feature spec as a shareable Claude Code Artifact — a private, hosted page on claude.ai, built around at-a-glance visuals (a status pipeline, an acceptance meter, a clickable user-journey, scope and open-question boards) so it reads in seconds instead of pages — with a Markdown fallback where Artifacts are unavailable. A read-only, derived view: the /spec and tracker item stay canonical; every visual encodes a real spec value, never fabricates status, dates, or acceptance criteria, never auto-generates per feature, and never writes into /spec, /apps, or /packages.

**When to use.** Use on demand when someone wants a plain-language, at-a-glance page of a feature to look at or hand to a non-technical stakeholder — "show me feature X", "make a shareable summary of this feature for the PO". Not for choosing the next action (that is /steer-next) or authoring/approving the spec (that is /steer-spec); this only presents what the spec already says.

**Arguments.** [feature-id]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/explain/SKILL.md` (invoked as `/steer:explain` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
