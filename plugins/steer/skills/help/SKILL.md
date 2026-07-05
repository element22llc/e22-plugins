---
name: help
description: >-
  Human-facing capabilities menu — renders the router's intent→skill table in
  plain language, grouped by workflow, so a user can browse what steer can do
  without knowing any skill name. Read-only; sources the live router table so it
  can never drift from actual routing.
when_to_use: >-
  Use when the user wants to browse steer's capabilities rather than run one —
  "what can steer do?", "what can you do?", "show me the commands", "list the
  skills", "I'm new here, what's available?". This is discovery, not navigation:
  for "what should I do next" in a real repo route to /steer:next, and for
  getting a repo onto the standards route to /steer:setup.
argument-hint: "[optional: a skill or area to zoom into]"
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

# Browse what steer can do (read-only menu)

`/steer:help` is the one surface a curious user can point at to see the **whole**
capability set at a glance. Everything steer does is normally reached by
describing a goal in plain language and letting the router pick the skill (see
`00-router.md`) — you never *have* to know a skill name. This skill is for the
person who wants to look at the map anyway: it prints the menu.

It changes nothing. It reads the router table and re-presents it; it never edits,
commits, routes, or runs another skill. If the user then picks something, that's
a separate turn.

## Single source of truth — render the router table, don't retype it

The authoritative capability list is the **`## Intent → skill` front-door table**
in `${CLAUDE_PLUGIN_ROOT}/rules/00-router.md`. Read that file now and build the
menu from its rows. **Do not hardcode the list here** — if you transcribe it, the
menu drifts the moment a skill is added or a front door changes. Every row you
show must come from that table as it stands this session, so a new front door
appears in the menu automatically.

Include the **front doors** (the `Intent → skill` table) plus the two
user-invocable skills the router surfaces only in its below-table prose —
`/steer:standards` and `/steer:reference` (take their one-line purpose from that
prose). Do not surface the internal gateways (`user-invocable: false` —
`tracker-sync`, `spec-scaffold`); they are never a user's entry point. You may
mention that each front door auto-routes to specialized skills, but don't
enumerate those unless the user asks to zoom in.

## Phase 1 — Read the router

Read `${CLAUDE_PLUGIN_ROOT}/rules/00-router.md`. Take the front-door rows from the
`## Intent → skill` table: each row's "trying to…" phrase and its target skill.

## Phase 2 — Group and render

Present the front doors grouped into these plain-language areas, in this order.
Map each router row to the area its target skill belongs to; omit an area that has
no rows this session (so the menu stays honest if the table changes).

- **Get set up** — bootstrap or maintain a repo on the standards (`setup` and the
  specialized `init` / `adopt` / `sync` / `doctor` it dispatches to; `protect`).
- **Shape the work** — think a feature through, absorb a PO's document, capture
  and sequence the backlog (`spec`, `build`, `intake`, `issues`, `adr`).
- **Do the work** — implement a change or fix an issue now, including hotfixes
  (`work`, `work --hotfix`).
- **Find your bearings** — figure out where things stand and what matters most
  (`next`, `audit`), get a shareable stakeholder-readable page of one feature
  (`explain`), and this menu itself (`help`).
- **Plumbing** — report a defect in the steer plugin upstream (`report`), and load
  the operating manual or reference prose on chat-only surfaces (`standards`,
  `reference` — the two below-table entries).

For each entry render one compact line: the **plain-language goal** first (from
the router's "trying to…" column), then the invocation in backticks —
e.g. `- Think a feature through without building it — /steer:spec`. Lead with the
goal, not the skill name; the whole point is that the user recognizes their
intent, not that they memorize a command.

Close with one line reminding them they can just **say what they want in plain
language** — the router will pick the skill — and that `/steer:next` answers "what
should I do *now*" in a specific repo, which this menu deliberately does not.

## Zooming in (optional argument)

If the user named a skill or area (`$ARGUMENTS`), skip the full menu and expand
just that one: read the target skill's `SKILL.md` frontmatter (`description` +
`when_to_use`) and summarize what it does, when to use it, and which front door
reaches it (per `00-router.md`). Still read-only — describe it; don't run it.

## What this skill is not

- Not a **navigator**: it never reconstructs repo state or recommends an action.
  That's `/steer:next`. If the user asks "what should I do next", route there.
- Not a **dispatcher**: it never bootstraps or picks init/adopt/sync. That's
  `/steer:setup`.
- Not a place to **restate the rules**: the always-on manual loads via the
  SessionStart hook (or `/steer:standards` on chat surfaces). This is just the
  capability index.
