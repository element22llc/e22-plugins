---
name: e22-tracker-sync
description: "The GitHub Issues tracker-metadata gateway for the /spec spine — the single low-level layer /e22-standards:e22-issues and /e22-standards:e22-work call. Generic issue operations (search, get, find-or-create, create, update, comment, set-type, label, transition, assign/claim, link, close/reopen, add-to-project) plus the higher-level PULL (materialize issues for /e22-standards:e22-drift, import acceptance criteria) and PUSH (spec-drift issues, promoted questions, feature requests) flows. MCP-first, gh CLI fallback, manual export floor. Moves tracker metadata, never the spec — and never git/PR delivery, which is an execution concern. Reads /spec/tracker.md and refuses to invent tracker state."
when_to_use: Use when /spec/tracker.md points at GitHub Issues and you need any issue read/write — find-or-create, update a managed block, transition state, set type/labels, link a PR, pull issues into the /e22-standards:e22-drift export, import acceptance criteria, or push spec-drift/question/feature-request issues out.
argument-hint: "[issue <op> | pull | push] [#issue | feature-id]"
---

# Sync the /spec spine with GitHub Issues

The plugin treats the tracker as a **pointer**, with `/spec` as the source of
truth. This skill is the **GitHub accelerator** for that pointer: it pulls issues
in (so `/e22-standards:e22-drift` doesn't need copy-paste) and pushes findings out (so
`spec-drift` issues and promoted questions actually get filed). It moves
**pointers and findings across the GitHub boundary** — it never makes GitHub
Issues the spec home, and for any non-GitHub tracker it degrades to the existing
manual export. It is glue, not a new source of truth.

## Integration: MCP-first → `gh` fallback → manual floor

The org ships GitHub MCP in every repo via `scaffold/mcp.json`
(`api.githubcopilot.com/mcp/`, `GITHUB_PAT`), so MCP is preferred — its tools
take a JSON `body` field, making multi-line markdown issue bodies clean with no
shell escaping. Detect capability **in this order, every run**:

1. **Read `/spec/tracker.md`.** Confirm the frontmatter key `system: github`
   (the lowercase enum value — not prose). If the tracker
   is Jira/Linear/Azure DevOps/other, print the manual-export instructions (the
   same paste/path flow `/e22-standards:e22-drift` uses today) and **stop** — there is no
   GitHub API path for a non-GitHub tracker. Don't fabricate one.
2. **Probe for GitHub MCP tools** (e.g. an issues list/get/create tool exposed by
   the github MCP server). If present → **MCP path**.
3. **Else probe `gh auth status`.** If authenticated → **`gh` CLI path**
   (`gh issue list --json …`, `gh issue create --body-file …` — use
   `--body-file`/heredoc for markdown bodies, never inline `--body` for
   multi-line text).
4. **Else** → manual paste/path export, same as `/e22-standards:e22-drift`. Say which path you
   took so the user knows whether issues were actually touched.

## Issue operations (the gateway)

This is the **only** layer that touches the GitHub API. `/e22-standards:e22-issues` and
`/e22-standards:e22-work` call these operations; they never hit `gh`/MCP directly. The boundary
is **tracker metadata only** — issues, relationships, comments, labels, Issue
Types, assignments, the `e22:state` marker, and optional Project sync. **Git
operations and pull-request delivery are NOT gateway operations** — they belong
to `/e22-standards:e22-work` under the repo's execution/autonomy rules (otherwise `git push`
would violate the boundary).

Each operation is MCP-first → `gh` → manual, and reports which path it took:

- **`search`** — find issues by marker (`e22:finding-key`, `e22:feature-id`+kind,
  `e22:question-id`, `e22:dedupe-key`), label, type, or text. Searches **all**
  states (open + closed), scoped to this repo.
- **`get #N`** — fetch one issue's full body + metadata.
- **`find-or-create`** — resolve identity in the dedup order (explicit `#N` →
  `finding-key` → `feature-id`+kind → `question-id` → `dedupe-key` → semantic
  title = candidates only). Exact match → reuse; multiple exact matches → stop
  and report; semantic candidate → never silently reuse. No match → create.
- **`create`** — open an issue from a rendered contract body (markers + headings
  + managed block). Set the GitHub Issue **Type** when available (see below).
- **`update #N`** — rewrite **only** the `e22:managed` block, following the
  concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before write, stop on
  a second concurrent change, fail closed on duplicate/malformed blocks).
- **`comment #N`** — add a comment (e.g. progress, AI synthesis on a human issue).
- **`set-type #N <Feature|Bug|Task>`** — set the Issue Type via
  `gh issue edit --type` / MCP. **Capability-degrading:** detect support + the
  configured Type names first; if Issue Types are unavailable or unknown, keep
  the `e22:kind` marker, emit a non-blocking warning, and do **not** add a
  duplicate `bug`/`feature` label to compensate.
- **`label #N`** — add/remove labels. The `source:*` label is *derived* from the
  `e22:source` marker; never treat the label as the source of truth.
- **`transition #N <state>`** — set the `e22:state` marker (base source of truth)
  and, when `project.enabled`, mirror it to the Project `Status` field. Honor the
  authority table in `ISSUE-WORKFLOW.md` — perform only where permitted.
- **`assign/claim #N`** — set GitHub assignment (accountable human) and/or the
  `e22:claimed-by` marker (active execution context). A conflicting existing
  claim/assignment is reported, **never** auto-overridden.
- **`link-parent #N <parent>`** — native sub-issue link, else `e22:parent-issue`.
- **`link-pr #N <pr>`** — record `e22:pull-request` / cross-link the PR.
- **`close/reopen #N`** — close (with resolution mode) or reopen. A reopened
  issue is re-assessed before returning to `inbox`/`exploring`/`ready-for-dev`.
- **`add-to-project #N`** — add the issue to the configured Project when
  `project.enabled`; degrade cleanly when permissions are insufficient.

## Modes

### `pull` — tracker → spec (introspect)

- **Export for drift.** Fetch issues (filterable by label / milestone / state)
  and write **one markdown file per issue** into a temp export directory in the
  shape `/e22-standards:e22-drift` expects: title, tracker key (`#123`), labels, state, body,
  and acceptance criteria. Then offer to chain straight into `/e22-standards:e22-drift` with
  that directory as its tracker-spec input — no pasting.
- **Import criteria into an intent.** Given an issue ref and a feature `[id]`,
  copy the issue's acceptance criteria into `spec/features/[id]/intent.md` and
  set its `> Tracker:` line (Rule 35: the spec is the in-repo source of truth;
  the ref points back). **Never overwrite human-authored prose** — append/merge,
  and flag conflicts as `## Open questions` rather than clobbering.

### `push` — spec → tracker (create)

- **`spec-drift` issues.** Consume a `/e22-standards:e22-drift` finding set (from a just-run
  drift report or a findings file) and open one `spec-drift`-labelled issue per
  finding that needs a human decision — the step `/e22-standards:e22-drift` describes but does
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
2. Take the drift findings (from a just-run `/e22-standards:e22-drift`, or a findings file the
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
`/e22-standards:e22-traceability` reference; the spec ↔ code resolution rules live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill only
moves pointers and findings across the GitHub boundary — those references govern
what the pointers mean and how drift gets resolved.
