# `/steer:tracker-sync` — the issue-operation catalogue

Read this file before performing any issue operation. The integration ladder
(MCP-first → `gh` → manual floor), the modes, the guardrails, and the coupling
rules stay in `SKILL.md` and apply to every operation here.

This is the **only** layer that touches the GitHub API. `/steer:issues` and
`/steer:work` call these operations; they never hit `gh`/MCP directly. The boundary
is **tracker metadata only** — issues, relationships, comments, labels, Issue
Types, assignments, milestones, and the `steer:state` marker. **Git
operations and pull-request delivery are NOT gateway operations** — they belong
to `/steer:work` under the repo's execution/autonomy rules (otherwise `git push`
would violate the boundary).

Each operation is MCP-first → `gh` → manual, and reports which path it took:

- **`search`** — find issues by marker (`steer:finding-key`, `steer:feature-id`+kind,
  `steer:question-id`, `steer:dedupe-key`), label, type, or text. Searches **all**
  states (open + closed), scoped to this repo.
- **`get #N`** — fetch one issue's full body + metadata.
- **`find-or-create`** — resolve identity in the dedup order (explicit `#N` →
  `finding-key` → `feature-id`+kind → `question-id` → `dedupe-key` → semantic
  title = candidates only). Exact match → reuse; multiple exact matches → stop
  and report; semantic candidate → never silently reuse. No match → create.
- **`create`** — open an issue from a rendered contract body (markers + headings
  + managed block). Set the GitHub Issue **Type** when available (see below).
  **Render every spec/code file path in the body as a Markdown link** to
  `REPO_BLOB_BASE/<path>` — resolve `<owner>/<repo>` and the `<default-branch>`
  (usually `main`) from the active repo, append a `#L<n>` anchor when a line is
  cited, and fall back to the bare code-fenced path only when the blob base can't
  be resolved (`ISSUE-SCHEMA.md` → Clickable references).
- **`update #N`** — rewrite **only** the `steer:managed` block, following the
  concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before write, stop on
  a second concurrent change, fail closed on duplicate/malformed blocks).
- **`comment #N`** — add a comment (e.g. progress, AI synthesis on a human issue).
- **`set-type #N <Feature|Bug|Task|Epic>`** — set the Issue Type via
  `gh issue edit --type` / MCP. **Capability-degrading:** detect support + the
  configured Type names first; if Issue Types are unavailable or unknown, keep
  the `steer:kind` marker, emit a non-blocking warning, and do **not** add a
  duplicate `bug`/`feature` label to compensate. **`Epic` is org-defined and may be
  absent even when `Feature`/`Bug`/`Task` exist** — detect that *specific* Type
  name, not just whether Issue Types are on; if `Epic` is missing, keep
  `steer:kind=epic`, **leave the Type unset** (never substitute `Feature`), warn,
  and do not invent an `epic` label.
- **`label #N`** — add/remove labels. The `source:*` label is *derived* from the
  `steer:source` marker; never treat the label as the source of truth.
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
  `/steer:roadmap`) has shown the proposed milestone set + due dates and a human
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
  (`/steer:issues`), not this op — and `field-set` has **no managed-block
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
  a human configured. `/steer:init` and `/steer:adopt` call it during setup (next to
  `bootstrap-labels`); it is safe to re-run.
- **`transition #N <state>`** — set the `steer:state` marker (base source of truth).
  Honor the authority table in `ISSUE-WORKFLOW.md` — perform only where permitted.
  For a feature, the derived spec `Status:` follows the Status↔state crosswalk in
  `ISSUE-WORKFLOW.md`; this op never writes the spec — `/steer:spec` /
  `/steer:work` reconcile it from the new state.
- **`assign/claim #N`** — set GitHub assignment (accountable human) and/or the
  `steer:claimed-by` marker (active execution context). **Default subject is the
  invoking user** (self-assign): resolve it as `@me` on the `gh` path
  (`gh issue edit #N --add-assignee @me`) or the authenticated user's login on
  the MCP path. **Add**, never replace — preserve any existing assignees rather
  than clobbering them. A conflicting existing claim/assignment is reported,
  **never** auto-overridden.
- **`link-parent #N <parent>`** — native sub-issue link, else `steer:parent-issue`.
**Tier-agnostic:** the same op links a Feature under an Epic and a Task under a
Feature — each is one single-parent edge, so an `Epic → Feature → Task` hierarchy
is built by linking each hop. The marker fallback is single-valued (one direct
parent per issue), which holds for every hop of the chain.
- **`link-pr #N <pr>`** — record `steer:pull-request` / cross-link the PR, **and
  update the visible `Delivery` line** in the managed block (`PR: #<pr>` +
  `Branch: \`<branch>\``) so the delivering PR is clickable, not just a hidden
  marker (`ISSUE-SCHEMA.md` → Clickable references). The marker stays canonical;
  the line is the derived view.
- **`link-related #N <other> <relationship>`** — record a non-hierarchical
  connection between two issues. `<relationship>` is an `issue_relationship` value
  (`relates-to` · `depends-on` · `blocks` · `conflicts-with` · `supersedes` ·
  `superseded-by` — see `ENUMS.md`); reject anything outside the enum. For
  **`depends-on`/`blocks`**, prefer the native relationship via `link-blocked-by`
  (below) when available — it is board-visible and feeds ranking. Otherwise (and
  for the relationship types GitHub has no native form for —
  `relates-to`/`conflicts-with`/`supersedes`), this writes the link as a
  managed-block `Related issues` line (`#<other> — <relationship> (why)`) on `#N`
  per `ISSUE-SCHEMA.md` — the `#<other>` mention makes GitHub
  auto-create the backlink. **Reciprocity is the caller's choice:** by default
  record the symmetric line on `<other>` too (`relates-to`/`conflicts-with` are
  symmetric; `depends-on`↔`blocks` and `supersedes`↔`superseded-by` invert), but
  only when permitted to write that issue's managed block. Idempotent — a line for
  the same `(other, relationship)` pair is updated in place, not duplicated.
  **Never** reclassify or close either issue: a `conflicts-with`/`supersedes` link
  is surfaced for a human, not acted on.
- **`link-blocked-by #N <blocker>`** — record a **native** GitHub issue
  dependency (`#N` is blocked by `#blocker`; the reciprocal "blocks" edge is
  created by GitHub automatically). Native relationships are GraphQL-only — use the
  blocked-by add/remove mutations via `gh api graphql` (issue **node id**, not
  number), else the MCP equivalent. **Capability-degrading:** where native issue
  relationships are unavailable, fall back to `link-related #N <blocker>
  depends-on`. **One representation only:** when the native edge is written, do
  **not** also add a managed-block `depends-on`/`blocks` line for the same pair —
  the native edge is canonical, the marker is the fallback (this avoids
  double-counting in ranking; see `ISSUE-SCHEMA.md`). Idempotent. A blocked-by edge
  **informs** ranking and may *suggest* `steer:state=blocked`, but **never sets**
  it — `steer:state` stays canonical and a transition is the caller's decision.
- **`close/reopen #N`** — close (with resolution mode) or reopen. A reopened
  issue is re-assessed before returning to `inbox`/`exploring`/`ready-for-dev`.

  **This is the only closure path when the tracker repo is not the code repo.**
  GitHub honours closing keywords only within one repository, so a merged PR
  carrying `Closes #N` cannot close an issue in a different repo — it renders as
  a plain cross-reference and the issue silently stays open. Whenever
  `steer_tracker_repo` (`lib/scope.sh`) and `gh repo view --json nameWithOwner`
  **prove** a mismatch, the PR must carry `Refs owner/repo#N` instead and the
  caller must invoke this operation explicitly after the merge. Every write here
  is already cross-repo-safe — the gateway addresses issues by
  `repository:` — so no other operation changes. Only positive proof diverts;
  any unreadable value keeps the ordinary `Closes #N` path untouched.
