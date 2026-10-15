---
name: steer-weekly-update
description: 'Internal tracker writer - applies a week''s work to an Artifact-hosted project tracker (Copilot: a packet to paste).'
argument-hint: '[<tracker-url>] [<the week in your words>]'
user-invocable: false
---

<!-- Generated from the steer plugin's skills/weekly-update/SKILL.md - do not edit by hand.
     Refresh with /steer:setup sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Reached from rule 00 for a weekly tracker update.

> **Read-only on this surface - enforced by instruction, not by tooling.**
> In Claude Code this skill runs with `Edit`, `Write`, `NotebookEdit`, `EnterWorktree` removed from the tool pool, but
> only for the turn that invokes it - upstream clears the restriction at the
> user's next message - so even there it is a rule the skill keeps across a
> multi-turn run rather than a guarantee the runtime holds. No other agent has
> even that much: here it is a hard instruction. Treat those capabilities as
> unavailable for the whole run, and read any claim below that they "are
> unavailable" as a rule you must keep rather than a guarantee you can rely on.

# Weekly update - apply a week's progress to an Artifact tracker

**Scope boundary:** this writes delivery status into a project tracker that
lives in a claude.ai Artifact's shared database - the page is the tracker,
there is no repo file. Reporting progress to a reader is `/steer-status`;
GitHub issues are `/steer-work issues`. Never touch the repo, `/spec` or
GitHub from here.

## The tracker contract

A tracker this skill can update keeps two things in its page database:

- **`items`** - one document per scope item, document id = item id (`A1`,
  `C3`). Plan fields (`title`, `section`, `requirement`, `blocks`, `owner`,
  `resources`, `startWeek`, `endWeek`, `days`, `trComment`, `issue`, `order`,
  `source`) are the plan and are **never** written from an update. The
  updatable fields are exactly:

  | Field | Values | Page label |
  |---|---|---|
  | `trStatus` | `not_started` / `in_progress` / `received` / `blocked` - has the client's input arrived | TR status |
  | `delivery` | `planned` / `in_progress` / `done` / `at_risk` - our delivery of the item | E22 delivery |
  | `trOwner` | free text - the person on the client side | TR owner |
  | `sessionDate` | `YYYY-MM-DD`, or `""` to clear | session date |
  | `nextStep` | free text, replaces the previous one | next step |
  | `notes` | internal notes - never replaced by an update, see `note` below | notes |

  Every item write also sets `updatedAt` (ISO 8601 time) and `updatedBy`.
- **`meta/log`** - `{ "entries": [{ "at", "by", "item", "field", "from", "to" }] }`,
  oldest first, capped at the last 300. `field` is the page label above;
  `from`/`to` are display values - status labels (`Not started`, `In
  progress`, `Received`, `Blocked`, `Planned`, `Done`, `At risk`), dates as
  `Oct 22`, text as written.

A page whose database does not have this `items` shape is not this kind of
tracker: say so and stop. Never improvise a field mapping.

## The update packet

Both surfaces produce the same packet, and the tracker's import box accepts
exactly this:

```json
{
  "format": "steer.tracker-update/v1",
  "asOf": "2026-10-16",
  "updates": [
    { "id": "A2", "trStatus": "received", "nextStep": "Wire the DEV credentials into the cluster", "note": "Databases provisioned by the infrastructure team" },
    { "id": "C3", "delivery": "at_risk", "note": "Immuta access still pending; likely slips to W6" }
  ]
}
```

- **Only real ids, only the five set fields plus `note`.** Enum values are the
  keys (`received`), never the labels.
- **Changed fields only.** Leave out anything the week did not change; an
  empty `updates` list is a valid answer.
- **`note` appends, never replaces.** It becomes the line `<asOf>: <note>` at
  the top of the item's `notes`.
- **`asOf`** is the date the update describes - today unless the user says
  otherwise. Relative dates ("Thursday") resolve against it.
- **Never invent.** A field moves only when the user's words say it did. "TR
  sent it" is `received`; "still waiting" is not `blocked` unless the user calls
  it blocked or at risk.

## Steps

1. **Get the tracker URL** - from the arguments, else ask. The `?sk=` part is a
   share key: never write the URL into a repo file, issue, commit or PR.
2. **Read the register.**
   - **Claude Code** (the `ArtifactData` tool exists): `list` the `items`
     collection (`query.limit: 100`) and `get` `meta/log`; keep each
     document's `version`.
   - **Copilot, or any surface without it:** ask for the page's **Export JSON**
     (TR inputs tab) unless one is attached - its `items` array has the same
     fields. Without it, accept only ids the user names and say the import box
     will reject the rest.
3. **Map the notes to items** by id or title. One compact question for any
   phrase that matches several items or none - never guess an id.
4. **Build the packet**, dropping every field whose value is already current.
5. **Preview and wait.** Show one table - item, field, now, becomes - and list
   anything in the notes you did not map. Apply nothing until the user says yes.
6. **Apply.**
   - **Claude Code:** one `ArtifactData` `batch`:
     - an `update` per changed item, `if_version` pinned, carrying the changed
       fields, the rebuilt `notes` for a `note`, `updatedAt` (now) and
       `updatedBy: ""`;
     - a `set` of `meta/log`, `if_version` pinned, with one entry per changed
       field appended (`by: ""`, `field: "note added"` and `to: <note>` for a
       note) and the list trimmed to the last 300.

     A pinned write that fails means someone edited the page meanwhile:
     re-read, rebuild that item's diff, and preview again if it changed.
   - **Copilot / no `ArtifactData`:** print the packet in one `json` block and
     tell the user: open the tracker, **Import weekly update**, paste, Preview,
     Apply. It needs edit access to the page.
7. **Confirm.** Claude Code: re-read the changed items and report how many
   items and log entries changed, with the page link. Copilot: the packet is
   the result.

## Gotchas

- **`notes` is one field the page overwrites whole.** Writing `notes` from a
  `note` without prepending to the current value erases the team's history.
- **`updatedBy` from Claude Code is `""`.** The tool has no viewer id to
  write, and keeping the previous id would credit the wrong person; the page
  then shows no name and Activity says "Someone". The import box records the
  real editor.
- **No-op writes pollute Activity.** The page's own save skips unchanged
  fields; skip them too, or Activity fills with "set X to X".
- **A batch holds 50 writes.** 25 items plus the log fit; split a bigger
  register into batches of 49 plus one log write at the end.

## Recommend the next action

Close with `## Recommended next actions - /steer-weekly-update` per the shared
next-actions contract: on Copilot, pasting the packet into the import box; on
Claude Code, `No action is currently required.` - or `/steer-status` when the
user also wants a status note to send.
