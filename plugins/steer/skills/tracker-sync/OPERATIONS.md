# `/steer:tracker-sync` — the issue-operation catalogue

Read this file before your first issue operation — it carries the API boundary
that binds every op, plus the core lifecycle operations. The two companion
files below carry the planning and relationship ops; read one only when you are
about to perform an op it lists. The integration ladder (MCP-first → `gh` →
manual floor), the modes, the guardrails, and the coupling rules stay in
`SKILL.md` and apply to every operation in all three files.

This is the **only** layer that touches the GitHub API. `/steer:issues` and
`/steer:work` call these operations; they never hit `gh`/MCP directly. The boundary
is **tracker metadata only** — issues, relationships, comments, labels, Issue
Types, assignments, milestones, and the `steer:state` marker. **Git
operations and pull-request delivery are NOT gateway operations** — they belong
to `/steer:work` under the repo's execution/autonomy rules (otherwise `git push`
would violate the boundary).

**GraphQL is granted, and this boundary is what limits it.** Projects v2
issue-field I/O and native blocked-by edges have no `gh issue` subcommand, and
`gh api graphql` is the transport to reach for on `field-get` / `field-set` /
`link-blocked-by` / `bootstrap-fields`. The fallbacks named with those ops below are
real, but neither substitutes cleanly: the **REST** endpoints fall outside every
granted prefix, so reaching for one turns a documented read into a confirmation
(and widening the grant to `Bash(gh api:*)` is forbidden — see `SKILL.md`, where the
limit is a review obligation, not a gated one); the **MCP** github tools *are*
granted, but only expose issue fields if the org has enabled them, which is why those
ops hedge with "if it exposes issue fields" rather than promising a path.
`SKILL.md` pre-approves
`Bash(gh api graphql:*)` so a *read* never prompts on a direct invocation. That
grant matches a command-string prefix, so it would equally match a delivery-surface
mutation GraphQL can express (`mergePullRequest`, `createBranchProtectionRule`,
repository deletion). **Issue only the queries and mutations this file or its
two companions enumerate.** Anything touching PR merge, branch protection, or
repo settings is
out of bounds here regardless of what the grant matches — it belongs to
`/steer:work` or `/steer:protect` under their own gating. Nothing checks this
mechanically; it is a prose boundary.

Each operation is MCP-first → `gh` → manual, and reports which path it took.

**The catalogue is split by domain — read only the file for the operations you
are about to perform.** This file (the core issue lifecycle) is the one every
caller needs; the other two are read *only* when a listed op is actually
invoked, so a plain `get` or a `/steer:work` finish never pays for the planning
and relationship prose.

| Operations | Read |
|---|---|
| `search` · `get` · `find-or-create` · `create` · `update` · `comment` · `label` · `transition` · `assign`/`claim` · `link-pr` · `close`/`reopen` | **this file**, below |
| `set-type` · `set-milestone` · `milestone-ensure` · `field-get` · `field-set` · `bootstrap-fields` | [`OPERATIONS-PLANNING.md`](${CLAUDE_PLUGIN_ROOT}/skills/tracker-sync/OPERATIONS-PLANNING.md) |
| `link-parent` · `link-related` · `link-blocked-by` | [`OPERATIONS-LINKS.md`](${CLAUDE_PLUGIN_ROOT}/skills/tracker-sync/OPERATIONS-LINKS.md) |

The boundary above binds every operation in all three files — an op moved to a
companion file is no less bounded by it.

## Core issue lifecycle

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

- **`label #N`** — add/remove labels. The `source:*` label is *derived* from the
  `steer:source` marker; never treat the label as the source of truth.

- **`transition #N <state>`** — set the `steer:state` marker, the **single lifecycle
  store**. Honor the authority table in `ISSUE-WORKFLOW.md` — perform only where
  permitted. This op never writes the spec, and no delivery transition has a spec
  counterpart to write: a feature's `Status:` holds product state only
  (`draft`/`approved`/`live`) and is moved by `/steer:spec approve` and the release,
  never by a state change here (crosswalk in `ISSUE-WORKFLOW.md`).

- **`assign/claim #N`** — set GitHub assignment (accountable human) and/or the
  `steer:claimed-by` marker (active execution context). **Default subject is the
  invoking user** (self-assign): resolve it as `@me` on the `gh` path
  (`gh issue edit #N --add-assignee @me`) or the authenticated user's login on
  the MCP path. **Add**, never replace — preserve any existing assignees rather
  than clobbering them. A conflicting existing claim/assignment is reported,
  **never** auto-overridden.

- **`link-pr #N <pr>`** — record `steer:pull-request` / cross-link the PR, **and
  update the visible `Delivery` line** in the managed block (`PR: #<pr>` +
  `Branch: \`<branch>\``) so the delivering PR is clickable, not just a hidden
  marker (`ISSUE-SCHEMA.md` → Clickable references). The marker stays canonical;
  the line is the derived view.

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
