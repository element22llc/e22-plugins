---
name: help
description: "Human-facing capabilities menu — renders the shipped skill set in plain language, the six essentials first and the rest grouped by journey. Read-only; every line comes from the live skill frontmatter, and a completeness check proves no user-invocable skill was dropped. Optionally renders an Artifact menu."
when_to_use: >-
  Use to browse steer's capabilities — "what can steer do?",
  "show me the commands", "list the skills". Discovery only: "what should I do
  next" is /steer:next.
argument-hint: "[optional: a skill or area to zoom into]"
disallowed-tools: Edit, NotebookEdit, EnterWorktree
---

# Browse what steer can do (read-only menu)

`/steer:help` is the one surface a curious user can point at to see the **whole**
capability set at a glance. Everything steer does is normally reached by
describing a goal in plain language and letting the router pick the skill (see
`00-router.md`) — you never *have* to know a skill name. This skill is for the
person who wants to look at the map anyway: it prints the menu.

It changes nothing. It reads the skill set and re-presents it; it never edits,
commits, routes, or runs another skill. If the user then picks something, that's
a separate turn.

## Single source of truth — render the skill listing, don't retype it

The authoritative capability list is the set of skills shipped under
`${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` — the same files whose frontmatter the
router routes from. Read their frontmatter now and build the menu from it.
**Do not hardcode the list here** — if you transcribe it, the menu drifts the
moment a skill is added or renamed. Every entry you show must come from a
`SKILL.md` as it stands this session, so a new skill appears in the menu
automatically.

Skip any skill whose frontmatter says `user-invocable: false` (the internal
gateways — `tracker-sync`, `spec-scaffold`); they are never a user's entry
point. You may mention that a front door auto-routes to specialized skills
(`setup` → `init` / `adopt` / `sync`; `audit` → `tidy`; `issues` / `spec` →
`questions`; `issues` → `roadmap`), but don't enumerate those unless the user
asks to zoom in.

## Phase 1 — Read the listing

`Glob` `${CLAUDE_PLUGIN_ROOT}/skills/*/SKILL.md` and, for each file, read only
the frontmatter: `name`, `description`, `when_to_use`, `user-invocable`. The
plain-language goal for an entry is the first clause of `description` (what it
does), sharpened by the first quoted trigger phrase in `when_to_use` if there is
one. Drop everything else — mechanics belong in the zoom-in, not the menu.

## Phase 2 — Render: the essentials first, everything else behind a fold

The menu is **tiered** so a new user sees six lines, not twenty (progressive
disclosure). Still build every line from the live frontmatter — the tiers change
presentation order only, never the source.

**Tier 1 — The essentials.** Lead with these, one compact line each, in this
order — the handful that covers a whole working life with steer:

1. `setup` — get a repo onto the standards
2. `spec` — think a feature through (works on any repo — no setup needed)
3. `build` — build an app idea as a non-technical owner
4. `work` — implement or fix something now
5. `next` — "what should I do next?"
6. `status` — a client-ready progress report

**Tier 2 — "More, by journey."** After the essentials, add every remaining
user-invocable skill under one explicit *"More (you can also just describe any
of these):"* fold, grouped by journey in this order — map each remaining skill
to its group; omit an empty group:

- **Start** — the specialized bootstrap doors (`init`, `adopt`, `sync`,
  `doctor`, `protect`; note that `setup` dispatches to the first three).
- **Spec & backlog** — absorb a PO document, capture/sequence the backlog,
  sweep open questions, record decisions (`intake`, `issues`, `roadmap`,
  `questions`, `adr`).
- **Ship & respond** — the emergency door: `/steer:work --hotfix` for a
  production incident on a deployed system (from `work`'s `argument-hint`).
- **Track & automate** — repo health and drift, tidy-up, the scheduled loop
  (`audit`, `tidy`, `loop`).
- **Report** — a shareable page of one feature (`explain`).
- **Govern & plumbing** — report a steer defect (`report`); load the manual or
  reference prose on chat-only surfaces (`standards`, `reference`).

**Completeness check before you render.** The groups above are placement
guidance, not the source of truth: the skill listing is. After grouping, confirm
every user-invocable skill you read in Phase 1 appears exactly once in the
output (`/steer:help` itself is the one fair omission — the user is already in
it). If a skill matches no group, put it under **Govern & plumbing** rather than
dropping it; a skill silently missing from this menu is the failure mode this
check exists to prevent.

For each entry render one compact line: the **plain-language goal** first (from
the frontmatter, in your words), then the invocation in backticks —
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
**offer** a shareable visual version: the same journey groups as a browsable card
grid a user can hand to a teammate who is new to steer — an offer only, never
auto-published; a curious user often just wants the inline list. The cards are
still **derived from the live skill frontmatter** (Phase 1), never a hardcoded
or invented capability. Render by the shared discipline — rule `88-artifacts`,
mechanics in `/steer:reference artifacts` — with the temp path
`<tempdir>/steer-help-menu.html`.

End the menu with the last journey group and nothing after it — no line inviting
correction, no offer to file a report (rule `03-responses`: no closing offer). A
user who wants to flag a misroute says so, and rule `97-self-report` files it
then; a standing invitation on every menu is tail nobody reads.

## Zooming in (optional argument)

If the user named a skill or area (`$ARGUMENTS`), skip the full menu and expand
just that one: read the target skill's `SKILL.md` frontmatter (`description` +
`when_to_use` + `argument-hint`) and summarize what it does, when to use it, and
which front door reaches it (per the hand-off list above). Still read-only —
describe it; don't run it.

## What this skill is not

- Not a **navigator**: it never reconstructs repo state or recommends an action.
  That's `/steer:next`. If the user asks "what should I do next", route there.
- Not a **dispatcher**: it never bootstraps or picks init/adopt/sync. That's
  `/steer:setup`.
- Not a place to **restate the rules**: the always-on manual loads via the
  SessionStart hook (or `/steer:standards` on chat surfaces). This is just the
  capability index.
