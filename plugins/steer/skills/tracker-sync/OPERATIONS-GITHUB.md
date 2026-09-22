# `/steer:tracker-sync` - the GitHub-native operations

Read this file **only when** you are about to perform one of the operations it
lists: `label`, `set-type`, `set-milestone`, `milestone-ensure`, `field-get`,
`field-set`, `bootstrap-fields`, `link-parent`, `link-related`,
`link-blocked-by`. The API boundary, the integration ladder and the core
operations are in
[`OPERATIONS.md`](${CLAUDE_PLUGIN_ROOT}/skills/tracker-sync/OPERATIONS.md) and
bind everything here - in particular the rule that **only the queries and
mutations these files enumerate** may be issued, and that nothing touching PR
merge, branch protection, or repo settings belongs to this gateway at all.

These ops are what the GitHub arm can do **on top of** the core, so nothing in
the issue lifecycle may depend on one: labels, Issue Types, milestones and
native issue fields are repo or org settings, and native relationship edges are
a GitHub feature. Every op here is **capability-degrading by design** - it
detects support first and reports a gap rather than fabricating config - and the
`steer:*` marker the core writes stays canonical when it degrades.

Who reads this file: `/steer:spec roadmap` (milestones, dates), `/steer:issues
decompose`/`epic` (types, parent and related links), `reconcile` (the labels and
types it normalizes), `triage` and `board` (the Priority floor and the ranking
read), `/steer:next` and `/steer:status` (Priority and milestone reads), and
`/steer:setup init`/`adopt` (`bootstrap-fields`). `/steer:work` and the capture,
status and materialize modes do not - the delivery path is core-only.

## Labels and types

- **`label #N`** - add/remove labels. The `source:*` label is *derived* from the
  `steer:source` marker; never treat the label as the source of truth. Same for
  every other label that mirrors a marker: the label exists so a human can filter
  a board, and losing it loses nothing steer reads. (`/steer:issues
  bootstrap-labels` creates the taxonomy itself, inline, and says so - it is the
  documented exception to this gateway.)

- **`set-type #N <Feature|Bug|Task|Epic>`** - set the Issue Type via
  `gh issue edit --type` / MCP. **Capability-degrading:** detect support + the
  configured Type names first; if Issue Types are unavailable or unknown, keep
  the `steer:kind` marker, emit a non-blocking warning, and do **not** add a
  duplicate `bug`/`feature` label to compensate. **`Epic` is org-defined and may be
  absent even when `Feature`/`Bug`/`Task` exist** - detect that *specific* Type
  name, not just whether Issue Types are on; if `Epic` is missing, keep
  `steer:kind=epic`, **leave the Type unset** (never substitute `Feature`), warn,
  and do not invent an `epic` label.

## Milestones and issue fields

- **`set-milestone #N <title>`** - set or clear the issue's native GitHub
  **Milestone** (the field a Projects v2 release/roadmap view groups by) via
  `gh issue edit #N --milestone "<title>"` (clear with `--remove-milestone`) or
  the MCP equivalent. The milestone **must already exist** in the repo; if it does
  not, **report it and stop** - never fabricate or silently create one. GitHub
  allows a single milestone per issue, so changing it replaces the prior value:
  name the old value when you change it. Milestone assignment is **on-demand**,
  not auto-managed - the issue and `/spec` stay the source of truth (see the
  Projects-v2 compatibility boundary in `ISSUE-SCHEMA.md`).

- **`milestone-ensure <title> [--due <date>]`** - create a repo **Milestone** if it
  does not already exist (else fetch the existing one), so a milestone can be filled
  before `set-milestone` attaches issues to it. This is the **only** op that creates
  a milestone, and it preserves the "never silently fabricate" guarantee by being
  **strictly confirmation-gated**: invoke it only after the caller (e.g.
  `/steer:spec roadmap`) has shown the proposed milestone set + due dates and a human
  confirmed them. It **never invents a due date** - `--due` carries the
  human-confirmed date, and is omitted when the human set none. Create via the MCP
  create-milestone tool, else `gh api --method POST repos/{owner}/{repo}/milestones`
  (`-f title=... -f due_on=...`), else the manual floor (tell the user to create it in
  the GitHub UI). **Create-or-leave on re-run:** if the milestone exists, leave its
  title and due date as they are - never overwrite a value a human edited.

- **`field-get #N [<field>]`** - read native **issue field** values (Priority,
  Effort, Start/Target date, and any org custom field) for one issue via the
  GraphQL `issueFieldValues` connection (else the MCP github tool if it exposes
  issue fields, else report the capability is unavailable). Read-only; never
  confirms. Concrete query shape + typed value variants + the
  `viewerCanSetFields` capability probe: **`ISSUE-SCHEMA.md` §"Reading & writing
  issue fields"**.

- **`field-set #N <field> <value>`** - set one native issue field via the GraphQL
  `setIssueFieldValue` mutation (or the REST issue-field-values endpoint); writes
  exactly one field. The value is the **single source of truth**; callers that
  auto-set Priority own the escalate-only + managed-block **ledger** provenance
  (`/steer:work issues`), not this op - and `field-set` has **no managed-block
  concurrency guard**, so report the prior value when you change it. **Capability-
  degrading:** if the org has not enabled issue fields, or the named field/option
  does not exist, emit a non-blocking warning and **stop** - **never** fabricate a
  field or option, or fall back to a `priority:*`/`effort:*` label or a body marker
  (the field is the only home). **Never reach for the Projects API** - a same-named
  board column is a read-only projection with no writable option ids. Concrete
  mutation + REST recipes, option-**id**-vs-**name**, and the POST-not-`PUT` trap:
  **`ISSUE-SCHEMA.md` §"Reading & writing issue fields"**.

- **`bootstrap-fields`** - verify/reconcile the **org-level** issue-field
  definitions `steer` relies on (Priority + the default Effort / Start date /
  Target date set), so `field-set` can attach values. Issue fields are an **org
  setting**, not a repo file: this op **detects and reports**, it does not create
  org config silently. Probe via `gh api graphql`: if issue fields are unavailable
  -> report capability absent and stop. If the **Priority** field exists but its
  options differ from `issue_priority` (`Urgent|High|Medium|Low` - e.g. an org using
  `P0/P1/P2`) -> **report the mismatch and stop**; never rename or fabricate options.
  Like `milestone-ensure`, it is **create-or-leave**: never overwrite an option set
  a human configured. `/steer:setup init` and `/steer:setup adopt` call it during
  setup (next to `bootstrap-labels`); it is safe to re-run.

## Relationships

Two invariants span the three link ops: **one representation only** (a native
edge and a managed-block line for the same pair are never both written), and a
link **informs** ranking or a human decision but never sets `steer:state` or
closes an issue on its own.

- **`link-parent #N <parent>`** - native sub-issue link, else `steer:parent-issue`.
**Tier-agnostic:** the same op links a Feature under an Epic and a Task under a
Feature - each is one single-parent edge, so an `Epic -> Feature -> Task` hierarchy
is built by linking each hop. The marker fallback is single-valued (one direct
parent per issue), which holds for every hop of the chain.

- **`link-related #N <other> <relationship>`** - record a non-hierarchical
  connection between two issues. `<relationship>` is an `issue_relationship` value
  (`relates-to` · `depends-on` · `blocks` · `conflicts-with` · `supersedes` ·
  `superseded-by` - see `ENUMS.md`); reject anything outside the enum. For
  **`depends-on`/`blocks`**, prefer the native relationship via `link-blocked-by`
  (below) when available - it is board-visible and feeds ranking. Otherwise (and
  for the relationship types GitHub has no native form for -
  `relates-to`/`conflicts-with`/`supersedes`), this writes the link as a
  managed-block `Related issues` line (`#<other> - <relationship> (why)`) on `#N`
  per `ISSUE-SCHEMA.md` - the `#<other>` mention makes GitHub
  auto-create the backlink. **Reciprocity is the caller's choice:** by default
  record the symmetric line on `<other>` too (`relates-to`/`conflicts-with` are
  symmetric; `depends-on`<->`blocks` and `supersedes`<->`superseded-by` invert), but
  only when permitted to write that issue's managed block. Idempotent - a line for
  the same `(other, relationship)` pair is updated in place, not duplicated.
  **Never** reclassify or close either issue: a `conflicts-with`/`supersedes` link
  is surfaced for a human, not acted on.

- **`link-blocked-by #N <blocker>`** - record a **native** GitHub issue
  dependency (`#N` is blocked by `#blocker`; the reciprocal "blocks" edge is
  created by GitHub automatically). Native relationships have no `gh issue`
  subcommand - use the blocked-by add/remove mutations via `gh api graphql` (issue
  **node id**, not number), else the MCP equivalent if it exposes them. **Capability-degrading:** where native issue
  relationships are unavailable, fall back to `link-related #N <blocker>
  depends-on`. **One representation only:** when the native edge is written, do
  **not** also add a managed-block `depends-on`/`blocks` line for the same pair -
  the native edge is canonical, the marker is the fallback (this avoids
  double-counting in ranking; see `ISSUE-SCHEMA.md`). Idempotent. A blocked-by edge
  **informs** ranking and may *suggest* `steer:state=blocked`, but **never sets**
  it - `steer:state` stays canonical and a transition is the caller's decision.
