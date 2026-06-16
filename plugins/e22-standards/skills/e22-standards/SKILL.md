---
name: e22-standards
description: Load Element 22's always-on operating manual on demand. In Claude Code the rules are already injected, so this only repeats them.
when_to_use: Use at the start of a session on any surface where the SessionStart hook does NOT auto-inject the rules — notably Claude Cowork or the Claude desktop app, where plugin hooks currently do not fire.
---

# Element 22 operating manual — on-demand load

The E22 standards are normally injected once per session by the `e22-standards`
SessionStart hook. That hook **does not fire in Claude Cowork / the desktop app**
today (Cowork runs the agent in a sandbox VM that silently ignores plugin hooks —
tracked upstream in anthropics/claude-code#40495). On those surfaces a session
starts with *none* of the org rules in context, so run this skill first.

Do this now:

1. Read every rule file, in lexical (numeric-prefix) order, from:

   `${CLAUDE_PLUGIN_ROOT}/rules/`

   The files concatenate to form the full operating manual:
   `00-router`, `05-roles`, `10-stack`, `15-commands`, `20-layout`,
   `22-housekeeping`, `30-spec-workflow`, `32-living-docs`, `35-issue-tracker`,
   `40-testing`, `45-commit-autonomy`, `50-definition-of-done`,
   `55-drift-gates`, `60-high-risk`, `70-secrets`, `75-compliance`,
   `80-change-size`, `85-practices`, `90-design-sources`, `95-not-the-gate`,
   `99-end-of-session`.

2. Adopt their contents as your standing operating rules for the rest of this
   session — the same status they would have if they had been injected at
   startup. They override generic defaults and remain in force for every
   subsequent turn.

3. Give the user a one-line confirmation naming the plugin version (read it from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`) — e.g. "Element 22
   standards vX.Y.Z loaded." Do **not** dump the full ruleset back to the user;
   just confirm and proceed.

The router (`00-router.md`) points to the on-demand reference skills
(`/e22-standards:e22-conventions`, `/e22-standards:e22-traceability`, `/e22-standards:e22-design-sources`,
`/e22-standards:e22-spec-scaffold`, `/e22-standards:e22-init`, `/e22-standards:e22-adopt`) — those work normally in
Cowork since skills are supported there; only the always-on injection needed
this fallback.
