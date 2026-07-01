---
name: tracker-sync
description: "The GitHub Issues tracker-metadata gateway for the /spec spine — the single low-level layer /steer:issues and /steer:work call. Generic issue operations (search, get, find-or-create, create, update, comment, set-type, label, set-milestone, milestone-ensure, field-get, field-set, bootstrap-fields, transition, assign/claim, link-parent, link-pr, link-related, link-blocked-by, close/reopen) plus the higher-level PULL (materialize issues for /steer:audit spec, import acceptance criteria) and PUSH (spec-drift issues, promoted questions, feature requests) flows. MCP-first, gh CLI fallback, manual export floor. Moves tracker metadata, never the spec — and never git/PR delivery, which is an execution concern. Reads /spec/tracker.md and refuses to invent tracker state."
when_to_use: Use when /spec/tracker.md points at GitHub Issues and you need any issue read/write — find-or-create, update a managed block, transition state, set type/labels, set or ensure a milestone, link a PR, pull issues into the /steer:audit spec export, import acceptance criteria, or push spec-drift/question/feature-request issues out.
argument-hint: "[issue <op> | pull | push] [#issue | feature-id]"
# Internal gateway: driven by /steer:issues and /steer:work, and also by
# /steer:spec (materialize step), /steer:roadmap, /steer:intake (reconcile), and
# /steer:next's read-only state reconstruction — plus the read flows of
# /steer:audit spec. Never a direct user entry point. Model-callable, hidden from
# the slash menu, so it never competes with the orchestrators above it.
user-invocable: false
---
<!-- steer:modes issue,pull,push -->

# Sync the /spec spine with GitHub Issues

The plugin treats the tracker as a **pointer**, with `/spec` as the source of
truth. This skill is the **GitHub accelerator** for that pointer: it pulls issues
in (so `/steer:audit spec` doesn't need copy-paste) and pushes findings out (so
`spec-drift` issues and promoted questions actually get filed). It moves
**pointers and findings across the GitHub boundary** — it never makes GitHub
Issues the spec home, and for any non-GitHub tracker it degrades to the existing
manual export. It is glue, not a new source of truth.

## Integration: MCP-first → `gh` fallback → manual floor

The steer plugin ships GitHub MCP to every repo that enables it (the plugin's
own `.mcp.json` — `api.githubcopilot.com/mcp/`, `GITHUB_PAT`), so MCP is
preferred — its tools
take a JSON `body` field, making multi-line markdown issue bodies clean with no
shell escaping. Detect capability **in this order, every run**:

1. **Read `/spec/tracker.md`.** Confirm the frontmatter key `system: github`
   (the lowercase enum value — not prose). If the tracker
   is Jira/Linear/Azure DevOps/other, print the manual-export instructions (the
   same paste/path flow `/steer:audit spec` uses today) and **stop** — there is no
   GitHub API path for a non-GitHub tracker. Don't fabricate one.
2. **Probe for GitHub MCP tools** (e.g. an issues list/get/create tool exposed by
   the github MCP server). If present → **MCP path**.
3. **Else probe `gh auth status`.** If authenticated → **`gh` CLI path**
   (`gh issue list --json …`, `gh issue create --body-file …` — use
   `--body-file`/heredoc for markdown bodies, never inline `--body` for
   multi-line text).
4. **Else** → manual paste/path export, same as `/steer:audit spec`. Say which path you
   took so the user knows whether issues were actually touched.

**Sandboxed chat surfaces (Claude Cowork).** Cowork does **not** read the
plugin's `.mcp.json`, and its no-install sandbox has no `${GITHUB_PAT}` shell and
no `gh` CLI — so steps 2–3 only succeed when the user has enabled Cowork's
**built-in GitHub connector** (Customize → Connectors), which exposes the
repo-scoped issue tools the MCP path probes for. With it on, triage works; without
it, you land on the manual floor (step 4) — the `gh` fallback is unavailable.
The connector is **repo-scoped**, so org-level ops (`set-type` Issue Types,
`field-get`/`field-set` native fields) degrade per their own capability checks.
See [Known limitations → Claude Cowork's sandbox](https://github.com/element22llc/e22-plugins/blob/main/docs/reference/known-limitations.md).

## Issue operations (the gateway)

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
  Effort, Start/Target date, and any org custom field) for one issue. **Native
  issue fields have no `gh issue` subcommand** — query via `gh api graphql` on the
  issue's **`issueFieldValues`** connection (not `fieldValues` — that does not
  exist on `Issue`), else the MCP github tool if it exposes issue fields, else
  report the capability is unavailable. Each value node is a typed variant —
  `IssueFieldSingleSelectValue { name optionId }` for Priority, plus
  `…TextValue` / `…DateValue` / `…NumberValue` / `…MultiSelectValue`; the value's
  `field` is the definition union **`IssueFields`** (`IssueFieldSingleSelect`,
  `IssueFieldText`, `IssueFieldDate`, `IssueFieldNumber`, `IssueFieldMultiSelect`).
  Use `issue.viewerCanSetFields` as the capability probe. (Writes also have a REST
  path — see the `field-set` recipe below.) Read-only; never confirms.
- **`field-set #N <field> <value>`** — set one native issue field. Resolve the
  field's node id, its **type**, and (for single-selects like **Priority**) the
  option id from the **org field definition** via `gh api graphql`, then call the
  `setIssueFieldValue` mutation. **Its input is `issueId` + an `issueFields` list**
  (`setIssueFieldValue(input:{ issueId:"…", issueFields:[ … ] })`) — `fieldId` and
  the value do **not** sit at the top level; each list element is an
  `IssueFieldCreateOrUpdateInput` of `{ fieldId, <one typed value> }`. The typed
  value key is `singleSelectOptionId` (an option **id**, not its name) for a
  single-select like Priority, `dateValue` for a date, `numberValue` / `textValue`
  / `multiSelectOptionIds` as the field's type dictates (never assume Effort's
  type — read it); set `delete: true` on the element to clear a value. One mutation
  can carry several elements, but `field-set` writes exactly one.
  **Capability-degrading:** if the
  org has not enabled issue fields, or the named field / option does not exist,
  emit a non-blocking warning and **stop** — **never** fabricate a field, fabricate
  an option, or fall back to a `priority:*`/`effort:*` label or a body marker (the
  field is the only home; see `ISSUE-SCHEMA.md`). The value is the **single source
  of truth**; callers that auto-set Priority own the escalate-only + managed-block
  **ledger** provenance (`/steer:issues`), not this op. `field-set` is a separate
  mutation with **no managed-block concurrency guard** — report the prior value
  when you change it so a concurrent human edit is visible.
  **Never reach for the Projects API for these fields.** A same-named Projects board
  column (Priority/Effort/dates) is a **read-only projection** of the native field:
  `updateProjectV2Field` / `gh project item-edit` fail with `Only custom fields can be
  updated …`, and the column exposes no option ids. The native issue field is the
  only writable home (see the Projects-v2 boundary in `ISSUE-SCHEMA.md`).
  **Working write recipe** (when the GitHub MCP server exposes no issue-field tool):
  read the option **names/ids** from `gh api /orgs/{org}/issue-fields` (each field's
  choices live under `.options`), then write the value via **either** the GraphQL
  `setIssueFieldValue` mutation (above) **or** the one-line REST equivalent —
  `gh api --method POST /repos/{owner}/{repo}/issues/{n}/issue-field-values
  -H "X-GitHub-Api-Version: 2026-03-10" -f issue_field_values='[{"field_id":<id>,"value":"High"}]'`
  (the REST `value` is the option **name**, e.g. `High`, not its id — unlike the
  GraphQL `singleSelectOptionId`, which is the id). Use **POST** to add/update this
  one field; **never `PUT`** that endpoint for a single-field set — `PUT` *replaces
  all* of the issue's field values, silently clearing Effort/dates you didn't pass.
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

## Modes

### `pull` — tracker → spec (introspect)

- **Export for drift.** Fetch issues (filterable by label / milestone / state)
  and write **one markdown file per issue** into a temp export directory in the
  shape `/steer:audit spec` expects: title, tracker key (`#123`), labels, state, body,
  and acceptance criteria. Then offer to chain straight into `/steer:audit spec` with
  that directory as its tracker-spec input — no pasting.
- **Import criteria into an intent.** Given an issue ref and a feature `[id]`,
  copy the issue's acceptance criteria into `spec/features/[id]/intent.md` and
  set its `> Tracker:` line (Rule 35: the spec is the in-repo source of truth;
  the ref points back). **Never overwrite human-authored prose** — append/merge,
  and flag conflicts as `## Open questions` rather than clobbering.

### `push` — spec → tracker (create)

- **`spec-drift` issues.** Consume a `/steer:audit spec` finding set (from a just-run
  drift report or a findings file) and open one `spec-drift`-labelled issue per
  finding that needs a human decision — the step `/steer:audit spec` describes but does
  not execute. Scope to *actual* drift (Diverged, Done-but-Missing, genuine
  conflicts) — **never** expected-Missing backlog.
- **Promote an open question.** Take a `## Open questions` entry that needs an
  external owner or scheduling, open an issue from it, then **replace the
  question with the ref** (`#123`) — closing the Rule-35 loop automatically.
- **New feature request.** From an approved `intent.md`, open a feature-request
  issue using the repo's `.github/ISSUE_TEMPLATE/feature.yml` form fields (or the
  machine-readable issue contract — see the issue-schema reference), and write
  the returned `#` back into the intent's `> Tracker:` line.

## Guardrails

- **Read `/spec/tracker.md` first, every run** (step 1). Non-GitHub tracker →
  manual path, no API calls, no pretending.
- **Idempotent pushes.** Before creating any issue, search existing open issues
  for a match (finding key / question text / feature id) and **skip duplicates**;
  log what was skipped. Re-running `push` must not double-file.
- **Intent-aware confirmation.** Reads never confirm. Creation follows intent,
  not a blanket "outward-facing → confirm" rule: an explicit capture or
  implementation request ("create an issue for…", "add to the backlog", "fix
  this bug", "implement #123") creates without confirmation. A **large inferred
  batch of unrelated** issues takes one confirmation; ambiguous conversation that
  did not request capture does **not** create; security-sensitive public
  disclosure takes human review.
- **No code, no spec rewrites beyond refs.** The only spec edits this skill makes
  are: an `intent.md` `> Tracker:` line, importing acceptance criteria
  (append/merge), and striking a promoted `## Open questions` item for its ref.
  It never edits `/apps`, `/packages`, or `contract.md` behavior.

## Steps (happy path — `push` from a drift run)

1. Read `/spec/tracker.md`; confirm GitHub. Detect MCP vs `gh` (above).
2. Take the drift findings (from a just-run `/steer:audit spec`, or a findings file the
   dev points to).
3. Dedup against existing open `spec-drift` issues.
4. Show the proposed issue list (title + which finding/feature each maps to); get
   one confirmation.
5. Create via the MCP create-issue tool (preferred) or `gh issue create
   --body-file`.
6. Report the opened `#`s; where a finding maps to a feature, write the ref into
   that feature's `intent.md` `> Tracker:` line.

## Coupling rules

Tracker-integration conventions are canonical in rule `35-issue-tracker` and the
`/steer:reference traceability` reference; the spec ↔ code resolution rules live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`. This skill only
moves pointers and findings across the GitHub boundary — those references govern
what the pointers mean and how drift gets resolved.
