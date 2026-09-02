# `/steer-tracker-sync` — planning operations (types, milestones, issue fields)

Read this file **only when** you are about to perform one of the operations it
lists: `set-type`, `set-milestone`, `milestone-ensure`, `field-get`,
`field-set`, `bootstrap-fields`. The API boundary, the integration ladder and
the core lifecycle ops are in
[`OPERATIONS.md`](OPERATIONS.md) and
bind everything here — in particular the rule that **only the queries and
mutations these files enumerate** may be issued, and that nothing touching PR
merge, branch protection, or repo settings belongs to this gateway at all.

These ops are **capability-degrading by design**: Issue Types and native issue
fields are org settings, so each detects support first and reports a gap rather
than fabricating config or falling back to a label.

## Operations

- **`set-type #N <Feature|Bug|Task|Epic>`** — set the Issue Type via
  `gh issue edit --type` / MCP. **Capability-degrading:** detect support + the
  configured Type names first; if Issue Types are unavailable or unknown, keep
  the `steer:kind` marker, emit a non-blocking warning, and do **not** add a
  duplicate `bug`/`feature` label to compensate. **`Epic` is org-defined and may be
  absent even when `Feature`/`Bug`/`Task` exist** — detect that *specific* Type
  name, not just whether Issue Types are on; if `Epic` is missing, keep
  `steer:kind=epic`, **leave the Type unset** (never substitute `Feature`), warn,
  and do not invent an `epic` label.

- **`set-milestone #N <title>`** — set or clear the issue's native GitHub
  **Milestone** (the field a Projects v2 release/roadmap view groups by) via
  `gh issue edit #N --milestone "<title>"` (clear with `--remove-milestone`) or
  the MCP equivalent. The milestone **must already exist** in the repo; if it does
  not, **report it and stop** — never fabricate or silently create one. GitHub
  allows a single milestone per issue, so changing it replaces the prior value:
  name the old value when you change it. Milestone assignment is **on-demand**,
  not auto-managed — the issue and `/spec` stay the source of truth (see the
  Projects-v2 compatibility boundary in `ISSUE-SCHEMA.md`).

- **`milestone-ensure <title> [--due <date>]`** — create a repo **Milestone** if it
  does not already exist (else fetch the existing one), so a milestone can be filled
  before `set-milestone` attaches issues to it. This is the **only** op that creates
  a milestone, and it preserves the "never silently fabricate" guarantee by being
  **strictly confirmation-gated**: invoke it only after the caller (e.g.
  `/steer-roadmap`) has shown the proposed milestone set + due dates and a human
  confirmed them. It **never invents a due date** — `--due` carries the
  human-confirmed date, and is omitted when the human set none. Create via the MCP
  create-milestone tool, else `gh api --method POST repos/{owner}/{repo}/milestones`
  (`-f title=… -f due_on=…`), else the manual floor (tell the user to create it in
  the GitHub UI). **Create-or-leave on re-run:** if the milestone exists, leave its
  title and due date as they are — never overwrite a value a human edited.

- **`field-get #N [<field>]`** — read native **issue field** values (Priority,
  Effort, Start/Target date, and any org custom field) for one issue via the
  GraphQL `issueFieldValues` connection (else the MCP github tool if it exposes
  issue fields, else report the capability is unavailable). Read-only; never
  confirms. Concrete query shape + typed value variants + the
  `viewerCanSetFields` capability probe: **`ISSUE-SCHEMA.md` §"Reading & writing
  issue fields"**.

- **`field-set #N <field> <value>`** — set one native issue field via the GraphQL
  `setIssueFieldValue` mutation (or the REST issue-field-values endpoint); writes
  exactly one field. The value is the **single source of truth**; callers that
  auto-set Priority own the escalate-only + managed-block **ledger** provenance
  (`/steer-issues`), not this op — and `field-set` has **no managed-block
  concurrency guard**, so report the prior value when you change it. **Capability-
  degrading:** if the org has not enabled issue fields, or the named field/option
  does not exist, emit a non-blocking warning and **stop** — **never** fabricate a
  field or option, or fall back to a `priority:*`/`effort:*` label or a body marker
  (the field is the only home). **Never reach for the Projects API** — a same-named
  board column is a read-only projection with no writable option ids. Concrete
  mutation + REST recipes, option-**id**-vs-**name**, and the POST-not-`PUT` trap:
  **`ISSUE-SCHEMA.md` §"Reading & writing issue fields"**.

- **`bootstrap-fields`** — verify/reconcile the **org-level** issue-field
  definitions `steer` relies on (Priority + the default Effort / Start date /
  Target date set), so `field-set` can attach values. Issue fields are an **org
  setting**, not a repo file: this op **detects and reports**, it does not create
  org config silently. Probe via `gh api graphql`: if issue fields are unavailable
  → report capability absent and stop. If the **Priority** field exists but its
  options differ from `issue_priority` (`Urgent|High|Medium|Low` — e.g. an org using
  `P0/P1/P2`) → **report the mismatch and stop**; never rename or fabricate options.
  Like `milestone-ensure`, it is **create-or-leave**: never overwrite an option set
  a human configured. `/steer-init` and `/steer-adopt` call it during setup (next to
  `bootstrap-labels`); it is safe to re-run.
