---
name: steer-help
description: Internal renderer for the capability menu - the shipped skill set in plain language, essentials first, the rest by journey, every line built from live frontmatter. Read-only; optional Artifact menu.
argument-hint: '[optional: a skill or area to zoom into]'
user-invocable: false
---

<!-- Generated from the steer plugin's skills/help/SKILL.md - do not edit by hand.
     Refresh with /steer:sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Reached via /steer-next capabilities - not a direct entry point.

> **Read-only on this surface - enforced by instruction, not by tooling.**
> In Claude Code this skill runs with `Edit`, `NotebookEdit`, `EnterWorktree` removed from the tool pool, but
> only for the turn that invokes it - upstream clears the restriction at the
> user's next message - so even there it is a rule the skill keeps across a
> multi-turn run rather than a guarantee the runtime holds. No other agent has
> even that much: here it is a hard instruction. Treat those capabilities as
> unavailable for the whole run, and read any claim below that they "are
> unavailable" as a rule you must keep rather than a guarantee you can rely on.

# Browse what steer can do (read-only menu)

`/steer-next capabilities` is the one surface a curious user can point at to see
the **whole** capability set at a glance, and this skill is what it renders. Everything steer does is normally reached by
describing a goal in plain language and letting the router pick the skill (see
`00-router.md`) - you never *have* to know a skill name. This skill is for the
person who wants to look at the map anyway: it prints the menu.

It changes nothing. It reads the skill set and re-presents it; it never edits,
commits, routes, or runs another skill. If the user then picks something, that's
a separate turn.

## Single source of truth - render the skill listing, don't retype it

The authoritative capability list is the set of skills shipped under
`https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/skills/*/SKILL.md` - the same files whose frontmatter the
router routes from. Read their frontmatter now and build the menu from it.
**Do not hardcode the list here** - if you transcribe it, the menu drifts the
moment a skill is added or renamed. Every entry you show must come from a
`SKILL.md` as it stands this session, so a new skill appears in the menu
automatically.

Skip any skill whose frontmatter says `user-invocable: false` - the internal
gateways and the skills a front door has absorbed as a mode, this one included.
A user cannot type them, so listing them as commands would hand out invocations
the harness rejects. You may mention that a front door auto-routes to specialized skills
(`setup` -> `init` / `adopt` / `sync` / `doctor` / `protect`; `spec` ->
`questions` / `adr` / `intake` / `roadmap`; `work` -> `issues` / `tidy`), but
don't enumerate those unless the user asks to zoom in.

## Phase 1 - Read the listing

`Glob` `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/skills/*/SKILL.md` and, for each file, read only
the frontmatter: `name`, `description`, `when_to_use`, `user-invocable`. The
plain-language goal for an entry is the first clause of `description` (what it
does), sharpened by the first quoted trigger phrase in `when_to_use` if there is
one. Drop everything else - mechanics belong in the zoom-in, not the menu.

## Phase 2 - Render: the essentials first, everything else behind a fold

The menu is **tiered** so a new user sees six lines, not twenty (progressive
disclosure). Still build every line from the live frontmatter - the tiers change
presentation order only, never the source.

**Tier 1 - The essentials.** Lead with these, one compact line each, in this
order - the handful that covers a whole working life with steer:

1. `setup` - get a repo onto the standards
2. `spec` - think a feature through (works on any repo - no setup needed)
3. `build` - build an app idea as a non-technical owner
4. `work` - implement or fix something now
5. `next` - "what should I do next?"
6. `status` - a client-ready progress report, or `status feature <id>` for a
   shareable page of one feature

**Tier 2 - "More, by journey."** After the essentials, add every remaining
user-invocable skill under one explicit *"More (you can also just describe any
of these):"* fold, grouped by journey in this order - map each remaining skill
to its group; omit an empty group:

- **Start** - empty, and omitted. `init`, `adopt`, `sync`, `doctor` and
  `protect` are all `setup`'s modes, not skills a user types, so they never
  appear here as entries of their own.
- **Spec & backlog** - empty, and omitted. Capturing and sequencing the backlog
  is `work`'s `issues` mode; absorbing a PO document, laying out a release
  timeline, sweeping open questions and recording a decision are `spec`'s
  `intake`, `roadmap`, `questions` and `adr` modes. None is a skill a user
  types.
- **Ship & respond** - the emergency door: `/steer-work --hotfix` for a
  production incident on a deployed system (from `work`'s `argument-hint`).
- **Track & automate** - repo health and drift, the scheduled loop (`audit`,
  `loop`); the tidy-up itself is `/steer-work tidy`, the backlog
  `/steer-work issues`.
- **Govern & plumbing** - report a steer defect (`report`); load the manual or
  reference prose on chat-only surfaces (`standards`, `reference`).

**Completeness check before you render.** The groups above are placement
guidance, not the source of truth: the skill listing is. After grouping, confirm
every user-invocable skill you read in Phase 1 appears exactly once in the
output. The `user-invocable: false` skip in Phase 1 is the only omission, and it
is the harness's own boundary rather than a judgement call. If a skill matches no
group, put it under **Govern & plumbing** rather than
dropping it; a skill silently missing from this menu is the failure mode this
check exists to prevent.

For each entry render one compact line: the **plain-language goal** first (from
the frontmatter, in your words), then the invocation in backticks -
e.g. `- Think a feature through without building it - /steer-spec`. Lead with the
goal, not the skill name; the whole point is that the user recognizes their
intent, not that they memorize a command.

Close with one line reminding them they can just **say what they want in plain
language** - the router will pick the skill - and that `/steer-next` with no mode
answers "what should I do *now*" in a specific repo, which this menu deliberately
does not.

## Phase 3 - offer a shareable visual menu (Artifact)

The inline menu above is the fast, always-available render - where the `Artifact`
tool is unavailable it already *is* the **Markdown fallback**, so say that rather
than treating it as a missing feature. When the tool **is** available, additionally
**offer** a shareable visual version: the same journey groups as a browsable card
grid a user can hand to a teammate who is new to steer - an offer only, never
auto-published; a curious user often just wants the inline list. The cards are
still **derived from the live skill frontmatter** (Phase 1), never a hardcoded
or invented capability. Render by the shared discipline -
mechanics in `/steer-reference artifacts` - with the temp path
`<tempdir>/steer-capabilities-menu.html`.

End the menu with the last journey group and nothing after it - no line inviting
correction, no offer to file a report (rule `03-output` § Responses: no closing offer). A
user who wants to flag a misroute says so, and rule `00-router` § When steer itself misbehaves files it
then; a standing invitation on every menu is tail nobody reads.

## Zooming in (optional argument)

If the user named a skill or area (`$ARGUMENTS`), skip the full menu and expand
just that one: read the target skill's `SKILL.md` frontmatter (`description` +
`when_to_use` + `argument-hint`) and summarize what it does, when to use it, and
which front door reaches it (per the hand-off list above). Still read-only -
describe it; don't run it.

## What this skill is not

- Not a **navigator**: it never reconstructs repo state or recommends an action.
  That is `/steer-next`'s default mode - the same front door, the other question.
  An ask about what to do *now* belongs there, not in the menu.
- Not a **dispatcher**: it never bootstraps or picks init/adopt/sync. That's
  `/steer-setup`.
- Not a place to **restate the rules**: the always-on manual loads via the
  SessionStart hook (or `/steer-standards` on chat surfaces). This is just the
  capability index.
