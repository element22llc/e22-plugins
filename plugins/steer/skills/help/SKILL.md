---
name: help
description: "Human-facing capabilities menu — renders the router's intent-to-skill table in plain language, the six essentials first and the rest grouped by journey. Read-only; sources the live router table so it can never drift from actual routing."
when_to_use: >-
  Use to browse steer's capabilities — "what can steer do?", "what can you do?",
  "show me the commands", "list the skills". Discovery only: "what should I do
  next" routes to /steer:next.
argument-hint: "[optional: a skill or area to zoom into]"
disallowed-tools: Edit, NotebookEdit, EnterWorktree
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

## Phase 2 — Render: the essentials first, everything else behind a fold

The menu is **tiered** so a new user sees six lines, not twenty (progressive
disclosure). Still build every line from the live router table — the tiers
change presentation order only, never the source.

**Tier 1 — The essentials.** Lead with these, one compact line each, in this
order — the handful that covers a whole working life with steer:

1. `setup` — get a repo onto the standards
2. `spec` — think a feature through (works on any repo — no setup needed)
3. `build` — build an app idea as a non-technical owner
4. `work` — implement or fix something now
5. `next` — "what should I do next?"
6. `status` — a client-ready progress report

**Tier 2 — "More, by journey."** After the essentials, add the remaining
front-door rows under one explicit *"More (you can also just describe any of
these):"* fold, grouped by journey in this order — map each remaining router
row to its group; omit an empty group:

- **Start** — the specialized bootstrap doors (`protect`; note that `setup`
  dispatches to `init` / `adopt` / `sync` / `doctor`).
- **Spec & backlog** — absorb a PO document, capture/sequence the backlog,
  record decisions (`intake`, `issues`, `adr`).
- **Track & automate** — repo health and drift, the scheduled loop (`audit`,
  `loop`).
- **Report** — a shareable page of one feature (`explain`).
- **Govern & plumbing** — report a steer defect (`report`); load the manual or
  reference prose on chat-only surfaces (`standards`, `reference` — the two
  below-table entries).

For each entry render one compact line: the **plain-language goal** first (from
the router's "trying to…" column), then the invocation in backticks —
e.g. `- Think a feature through without building it — /steer:spec`. Lead with the
goal, not the skill name; the whole point is that the user recognizes their
intent, not that they memorize a command.

Close with one line reminding them they can just **say what they want in plain
language** — the router will pick the skill — and that `/steer:next` answers "what
should I do *now*" in a specific repo, which this menu deliberately does not.

## Phase 3 — offer a shareable visual menu (Artifact)

The inline menu above is the fast, always-available render — where the `Artifact`
tool is unavailable it already *is* the **Markdown fallback**, so say that rather
than treating it as a missing feature. When the tool **is** available, additionally
**offer** a shareable visual version: the same front-door areas as a browsable card
grid a user can hand to a teammate who is new to steer — an offer only, never
auto-published; a curious user often just wants the inline list. The cards are
still **derived from the live `00-router.md` table** (Phase 1), never a hardcoded
or invented capability. Render by the shared discipline — rule `88-artifacts`,
mechanics in `/steer:reference artifacts` — with the temp path
`<tempdir>/steer-help-menu.html`.

End the menu with one line inviting correction: if steer routed a recent ask to
the wrong workflow, or the menu misses what they were looking for, saying so
gets it reported upstream via `/steer:report` — real misroutes are how the
routing fixtures grow.

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
