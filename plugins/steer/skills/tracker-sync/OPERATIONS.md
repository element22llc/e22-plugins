# `/steer:tracker-sync` - the core issue-operation catalogue

Read this file before your first issue operation - it carries the API boundary
that binds every op, plus the **core**: the eight operations the issue lifecycle
runs on. The companion file carries the GitHub-native surface (labels, Issue
Types, milestones, issue fields, relationship edges); read it only when you are
about to perform an op it lists. The integration ladder (MCP-first -> `gh` ->
manual floor), the modes, the guardrails, and the coupling rules stay in
`SKILL.md` and apply to every operation in both files.

## What "core" means

The core is the set every tracker arm must be able to implement, so it is stated
in tracker-neutral terms: find a record, read one, open one, write the state
steer owns, take ownership, comment, point at what delivered it, close it. It
keys off **markers in the issue body**, which any tracker with a text body can
carry, never off GitHub-native metadata - a marker is canonical and a native
field or label is a derived projection of it.

Anything that has no equivalent outside GitHub lives in
[`OPERATIONS-GITHUB.md`](${CLAUDE_PLUGIN_ROOT}/skills/tracker-sync/OPERATIONS-GITHUB.md)
and degrades to a marker or a warning where the capability is absent. A few core
ops carry one **GitHub arm** paragraph, flagged as such: the operation is core,
the paragraph is how this arm performs it.

`/steer:work` and the `/steer:issues` capture, status and materialize modes use
**core ops only** - between them that is the whole delivery path, from an ask to
a closed issue. Every other caller reads the companion for the one op it is
about to perform: `triage`'s Priority floor and `board`'s ranking read
(`field-set` / `field-get`), `decompose`/`epic` (types, parent links),
`reconcile` (the labels and types it normalizes), `/steer:spec roadmap`
(milestones, dates), `/steer:next` and `/steer:status` (Priority and milestone
reads), and `/steer:setup init`/`adopt` (`bootstrap-fields`).

## The API boundary

This is the **only** layer that touches the GitHub API. `/steer:issues` and
`/steer:work` call these operations; they never hit `gh`/MCP directly. The boundary
is **tracker metadata only** - issues, relationships, comments, labels, Issue
Types, assignments, milestones, and the `steer:state` marker. **Git
operations and pull-request delivery are NOT gateway operations** - they belong
to `/steer:work` under the repo's execution/autonomy rules (otherwise `git push`
would violate the boundary).

**GraphQL is granted, and this boundary is what limits it.** Projects v2
issue-field I/O and native blocked-by edges have no `gh issue` subcommand, and
`gh api graphql` is the transport to reach for on `field-get` / `field-set` /
`link-blocked-by` / `bootstrap-fields`. The fallbacks named with those ops in the
companion are
real, but neither substitutes cleanly: the **REST** endpoints fall outside every
granted prefix, so reaching for one turns a documented read into a confirmation
(and widening the grant to `Bash(gh api:*)` is forbidden - see `SKILL.md`, where the
limit is a review obligation, not a gated one); the **MCP** github tools *are*
granted, but only expose issue fields if the org has enabled them, which is why those
ops hedge with "if it exposes issue fields" rather than promising a path.
`SKILL.md` pre-approves
`Bash(gh api graphql:*)` so a *read* never prompts on a direct invocation. That
grant matches a command-string prefix, so it would equally match a delivery-surface
mutation GraphQL can express (`mergePullRequest`, `createBranchProtectionRule`,
repository deletion). **Issue only the queries and mutations this file or its
companion enumerate.** Anything touching PR merge, branch protection, or
repo settings is
out of bounds here regardless of what the grant matches - it belongs to
`/steer:work` or `/steer:setup protect` under their own gating. Nothing checks this
mechanically; it is a prose boundary.

Each operation is MCP-first -> `gh` -> manual, and reports which path it took.

| Operations | Read |
|---|---|
| `find` · `get` · `create` · `update-state` · `claim` · `comment` · `link-delivery` · `close`/`reopen` | **this file**, below |
| `label` · `set-type` · `set-milestone` · `milestone-ensure` · `field-get` · `field-set` · `bootstrap-fields` · `link-parent` · `link-related` · `link-blocked-by` | [`OPERATIONS-GITHUB.md`](${CLAUDE_PLUGIN_ROOT}/skills/tracker-sync/OPERATIONS-GITHUB.md) |

The boundary above binds every operation in both files - an op in the companion
is no less bounded by it.

## Core operations

- **`find`** - locate issues and resolve identity. Searches by marker
  (`steer:finding-key`, `steer:feature-id`+kind, `steer:question-id`,
  `steer:dedupe-key`), by text, or by the arm's own metadata filters, across
  **all** states (open + closed), scoped to this repo. Identity resolves in the
  dedup order: explicit `#N` -> `finding-key` -> `feature-id`+kind ->
  `question-id` -> `dedupe-key` -> semantic title (**candidates only**). Exact
  match -> reuse; multiple exact matches -> stop and report; semantic candidate
  -> never silently reuse.

  **Find-or-create is this op plus `create`**, in that order, and callers name it
  that way: no match after the full dedup order is the one condition under which
  `create` may open a new issue.

- **`get #N`** - fetch one issue's full body + metadata.

- **`create`** - open an issue from a rendered contract body (markers + headings
  + managed block), after `find` has come back empty.
  **Render every spec/code file path in the body as a Markdown link** to
  `REPO_BLOB_BASE/<path>` - resolve `<owner>/<repo>` and the `<default-branch>`
  (usually `main`) from the active repo, append a `#L<n>` anchor when a line is
  cited, and fall back to the bare code-fenced path only when the blob base can't
  be resolved (`ISSUE-SCHEMA.md` -> Clickable references).

  **GitHub arm:** rendering an issue also stamps the Issue **Type** and the
  derived `source:*` label, as part of this op - a caller does not open the
  companion to create one. Both are capability-degrading, and the markers written
  here stay canonical either way, so a create that cannot stamp them is complete,
  not partial. The companion's `set-type` and `label` are for **changing** either
  afterwards.

- **`update-state #N`** - the guarded write of everything steer owns in the issue
  body: the **`steer:managed` block**, and the **`steer:state` marker** when the
  call moves the lifecycle. One op, because both are the same read-modify-write
  against the same body - follow the concurrency-safe protocol in
  `ISSUE-SCHEMA.md` (re-fetch before write, stop on a second concurrent change,
  fail closed on duplicate/malformed blocks), and preserve every byte outside the
  block.

  A call that moves `steer:state` honors the **authority table** in
  `ISSUE-WORKFLOW.md` - perform only where permitted; a progress rewrite that
  leaves the state alone carries no such gate. `steer:state` is the **single
  lifecycle store**. This op never writes the spec, and no delivery transition
  has a spec counterpart to write: a feature's `Status:` holds product state only
  (`draft`/`approved`/`live`) and is moved by `/steer:spec approve` and the
  release, never by a state change here (crosswalk in `ISSUE-WORKFLOW.md`).

- **`claim #N`** - take ownership: set assignment (the accountable human) and/or
  the `steer:claimed-by` marker (the active execution context). A separate op
  rather than a flavour of `update-state`, because the check it carries is a
  precondition of *ownership*, not of a state move: an already-assigned or
  already-claimed issue is **reported, never auto-overridden**, and folding that
  into `update-state` would make every unrelated transition assert ownership.
  **Default subject is the invoking user** (self-assign): resolve it as `@me` on
  the `gh` path (`gh issue edit #N --add-assignee @me`) or the authenticated
  user's login on the MCP path. A caller may name another subject instead -
  promoting an open question assigns the `owner:` role's login from
  `/spec/tracker.md` (`ISSUE-WORKFLOW.md`) - which sets assignment without
  `steer:claimed-by`: accountability is not an execution claim. **Add**, never replace - preserve any existing
  assignees rather than clobbering them. Claiming and moving to `in-progress` are
  two calls; the claim comes first, so a conflict stops the work before the state
  says it started.

- **`comment #N`** - add a comment (e.g. progress, AI synthesis on a human issue).

- **`link-delivery #N <ref>`** - record what delivers the issue: the PR in
  pr-flow (`steer:pull-request`), or the closing **trunk commit** in solo-trunk,
  plus `steer:branch` where there is one. **Update the visible `Delivery` line**
  in the managed block (`PR: #<pr>` + `Branch: \`<branch>\``, or the commit sha)
  so the delivering change is clickable, not just a hidden marker
  (`ISSUE-SCHEMA.md` -> Clickable references). The markers stay canonical; the
  line is the derived view. Marker **names** do not change with the arm -
  `steer:pull-request` is the schema's name for the delivery ref, and issues in
  the wild already carry it.

- **`close/reopen #N`** - close (with resolution mode) or reopen. `reopen` is the
  documented inverse and is load-bearing: the dedup rule in `ISSUE-SCHEMA.md`
  reopens a **closed exact match** only when it is genuinely the same unfinished
  work, and opens a linked follow-up otherwise. A reopened issue is re-assessed
  before returning to `inbox`/`exploring`/`ready-for-dev`.

  **GitHub arm - this is the only closure path when the tracker repo is not the
  code repo.** GitHub honours closing keywords only within one repository, so a
  merged PR carrying `Closes #N` cannot close an issue in a different repo - it
  renders as a plain cross-reference and the issue silently stays open. Whenever
  `steer_tracker_repo` (`lib/scope.sh`) and `gh repo view --json nameWithOwner`
  **prove** a mismatch, the PR must carry `Refs owner/repo#N` instead and the
  caller must invoke this operation explicitly after the merge. Every write here
  is already cross-repo-safe - the gateway addresses issues by
  `repository:` - so no other operation changes. Only positive proof diverts;
  any unreadable value keeps the ordinary `Closes #N` path untouched.
