---
name: standards
description: Load the always-on operating manual on demand. In Claude Code the rules are already injected, so this only repeats them.
when_to_use: Use at the start of a session on any surface where the SessionStart hook does NOT auto-inject the rules — notably the Claude desktop/web Chat tab and chat-only surfaces, where plugin hooks do not run.
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

# Operating manual — on-demand load

The standards are normally injected once per session by the `steer`
SessionStart hook. That hook **does not fire on the Claude Desktop *Chat* tab or
claude.ai web chat** — those surfaces install plugins (so skills and MCP work) but
do **not** run hooks, so a session there starts with *none* of the org rules in
context. Run this skill first on those surfaces. (On Claude Code — the CLI, the
IDE extensions, and the Desktop *Code* tab — and in Cowork, the hook injects the
rules automatically and you don't need this skill.)

Do this now:

1. Read every rule file, in lexical (numeric-prefix) order, from:

   `${CLAUDE_PLUGIN_ROOT}/rules/`

   The files concatenate, in that order, to form the full operating manual.

2. Adopt their contents as your standing operating rules for the rest of this
   session — the same status they would have if they had been injected at
   startup. They override generic defaults and remain in force for every
   subsequent turn.

3. Give the user a one-line confirmation naming the plugin version (read it from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`) — e.g. "Standards
   vX.Y.Z loaded." Do **not** dump the full ruleset back to the user;
   just confirm and proceed.

The router (`00-router.md`) points to the on-demand reference skills
(`/steer:reference [conventions|traceability|design-sources|context-hygiene]`, `/steer:init`,
`/steer:adopt`) — those work normally on the Chat tab and web chat since skills
are supported there; only the always-on injection needed this fallback.
