---
mode: agent
description: 'Render one feature spec as a stakeholder-readable, shareable Claude Artifact (Markdown fallback) — status pipeline, acceptance meter, user journey, scope and open-question boards. A read-only derived view: every visual encodes a real spec value; never writes into /spec, /apps, or /packages.'
---

<!-- Generated from the steer plugin's skills/explain/SKILL.md — do not edit by hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot step). -->

This mirrors steer's `/steer:explain` workflow for GitHub Copilot in VS Code.

**Purpose.** Render one feature spec as a stakeholder-readable, shareable Claude Artifact (Markdown fallback) — status pipeline, acceptance meter, user journey, scope and open-question boards. A read-only derived view: every visual encodes a real spec value; never writes into /spec, /apps, or /packages.

**When to use.** Use when someone wants a plain-language, at-a-glance page of one feature to look at or hand to a non-technical stakeholder — "show me feature X", "make a shareable summary for the PO".

**Arguments.** [feature-id]

**How to run this here.** Drive the workflow in Copilot now — apply the org engineering standards already loaded from `.github/copilot-instructions.md` (plus any path-scoped `.github/instructions/*.instructions.md`), and follow the intent above. Where the workflow calls for an independent, read-only standards/drift review, hand off to the `steer-reviewer` custom agent (`.github/agents/steer-reviewer.agent.md`). The fully authored procedure lives in the steer plugin's `skills/explain/SKILL.md` (invoked as `/steer:explain` in Claude Code); this capsule carries the intent so Copilot drives the same workflow on the same standards.
