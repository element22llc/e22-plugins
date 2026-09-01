---
name: standards
description: Load the full operating manual on demand — the always-on core plus the path-scoped rules — where the SessionStart hook cannot inject it or had to drop rules.
when_to_use: Use at the start of a session on any surface where the SessionStart hook does NOT auto-inject the rules — notably the Claude desktop/web Chat tab and chat-only surfaces, where plugin hooks do not run.
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

# Operating manual — on-demand load

The standards are normally injected by the `steer` SessionStart hook, which runs
on `startup`, `resume`, `clear` **and** `compact` — the last so a compaction that
drops the rules from context gets them back. That hook **does not fire on the
Claude Desktop *Chat* tab or
claude.ai web chat** — those surfaces install plugins (so skills and MCP work) but
do **not** run hooks, so a session there starts with *none* of the org rules in
context. Run this skill first on those surfaces. (On Claude Code — the CLI, the
IDE extensions, and the Desktop *Code* tab — and in Cowork, the hook injects the
rules automatically and you don't need this skill.)

Do this now:

1. Read every rule file, in lexical (numeric-prefix) order, from **both**
   directories — the ruleset is split across them:

   - `${CLAUDE_PLUGIN_ROOT}/rules/` — the always-on core (5 files). This is all
     the SessionStart hook can carry: Claude Code caps a hook's stdout at 10,000
     characters.
   - `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/claude/rules/steer-*.md` — the
     other 24. In a managed repo these are installed as `.claude/rules/` and load
     automatically when Claude reads a file their `paths:` frontmatter matches.
     On a surface with no hooks, or in a repo that never adopted them, nothing
     loads them — which is why this skill reads them from the plugin directly.
     Skip their YAML frontmatter and the `steer:managed` banner; the rule text is
     what carries.

   Together they form the full operating manual.

2. Adopt their contents as your standing operating rules for the rest of this
   session — the same **authority** they would carry had the hook injected them.
   They override generic defaults and remain in force for every subsequent turn.

   The **set** is deliberately wider than any single session receives: the hook
   carries only the core, and the path-scoped rules load one at a time as files
   are touched. Reading everything here loads all of them at once. Apply the ones
   that fit the work in front of you and ignore the rest — a code rule in a
   specs-only folder is inert, not a contradiction.

3. Give the user a one-line confirmation naming the plugin version (read it from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`) — e.g. "Standards
   vX.Y.Z loaded." Do **not** dump the full ruleset back to the user;
   just confirm and proceed.

The router (`00-router.md`) points to the on-demand reference skills
(`/steer:reference [conventions|traceability|design-sources|context-hygiene|architecture-diagrams|artifacts|gates|polyrepo]`, `/steer:init`,
`/steer:adopt`) — those work normally on the Chat tab and web chat since skills
are supported there; only the always-on injection needed this fallback.
