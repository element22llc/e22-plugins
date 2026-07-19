---
name: status
description: "Client-facing, time-boxed progress report across the whole /spec spine — what shipped, what's in progress, what needs the client's input, and what's next — rendered as a shareable Claude Artifact with a Markdown fallback. Read-only and derived; never fabricates counts, dates, or status."
when_to_use: >-
  Use for a progress update to hand a client or Product Owner — "give me a
  status report", "what did we ship this week", "weekly status for the client",
  "where are we on <milestone>".
argument-hint: "[this-week | since <date> | milestone [<name>]]"
# Read-only by construction. Pre-approve ONLY the tracker *read* verbs that
# /steer:tracker-sync performs while this skill is the invoked one (a skill's
# allowed-tools apply only to the invoked skill — so, unlike /steer:roadmap which
# grants nothing and lets reads fall through to settings.json, listing them here
# means the MCP-first → gh read path works without a per-call prompt, including
# headless). No write verb is granted — a tracker or repo write is not
# pre-approved and stays gated. Edit/NotebookEdit/EnterWorktree are disallowed so
# the skill cannot mutate a repo file, branch, or worktree; Write stays for the
# temp-dir artifact only.
allowed-tools:
  - mcp__github__issue_read
  - mcp__github__list_issues
  - mcp__github__search_issues
  - Bash(gh issue list:*)
  - Bash(gh issue view:*)
  - Bash(gh search issues:*)
  - Bash(gh auth status:*)
disallowed-tools: Edit, NotebookEdit, EnterWorktree
---
<!-- steer:modes this-week,since,milestone -->

# Status report — a shareable, plain-language progress update

**Scope boundary:** this summarizes progress across the whole spine over a
time window. Choosing the next action is `/steer:next`; a forward timeline is
`/steer:roadmap`; one feature in depth is `/steer:explain`. Never write into
/spec, /apps, /packages, or the tracker, and never auto-generate on a schedule.

Turn the current state of the workspace into a **client-readable progress report
for a time window**: what shipped this period, what's in flight, what's waiting on
the client, and what's next — published as a **Claude Code Artifact** (a private,
hosted page on claude.ai you can then share) or rendered as **Markdown** where
Artifacts are unavailable.

This is the **periodic, cross-cutting** counterpart to the roster's other
PO-facing views: `/steer:explain` presents **one feature** in depth; `/steer:roadmap`
lays out the **forward** timeline; `status` reports **progress over a window across
the whole spine** — the answer to "what's the status?".

## Render, don't own — this is a derived view

Mirror `/steer:explain` and `/steer:roadmap`: **`/spec` and the tracker are
canonical**. The report is a **snapshot** of what they already say — it goes stale
the moment the spine or tracker changes; regenerate to refresh.

- **Never fabricate.** Render only real, sourced values — closed-issue counts,
  milestone completion, open-question counts, feature `Status:` lines. A missing
  or untracked source shows as *"not tracked"* or *"no items this period"*, never
  an invented number, date, or status.
- **Read-only over canonical sources — never writes back.** `Edit`,
  `NotebookEdit`, and `EnterWorktree` are **disallowed in frontmatter**, so —
  tool-enforced — this skill cannot edit a repo file, create a branch, or open a
  worktree. It writes **nothing** to `/spec`, `/apps`, `/packages`, or the
  tracker: its `allowed-tools` pre-approve **only read verbs** (the MCP issue-read
  tools and the scoped `gh issue list`/`view`/`search` reads `/steer:tracker-sync`
  uses), so no write is pre-approved — a tracker or repo write stays gated and is
  a hard prose violation besides. `Bash` is **not** blanket-disallowed — unlike
  `/steer:explain` (which reads only local files), this skill reads the *tracker*
  and the `gh` read fallback runs through `Bash` — but only the read verbs above
  are pre-approved; a mutating `git`/`gh` command is neither granted nor run. The
  **one** thing it writes is the report's HTML source (via `Write`, not disallowed)
  — bound by a hard invariant: **only to a system temp directory, never a path
  under the repo working tree**. Discover the spine with `Glob`/`Read`.
- **GitHub reads go through `/steer:tracker-sync`.** Like `/steer:roadmap`, this
  skill never calls the GitHub API directly — it asks `/steer:tracker-sync` to read
  closed issues and milestone progress (MCP-first → `gh` → manual floor), and says
  which path was taken so the reader knows whether the tracker was consulted. On
  the `gh` path those reads are read-only issue/search queries; the skill issues no
  writes.
- **On demand, human-run.** Produce a report when asked. Do **not** auto-generate
  on a schedule or persist the Artifact URL anywhere in the repo — a status report
  is a disposable view. (Running it on a weekly cadence is fine — that is the human
  choosing to run it, not the plugin generating copies unbidden.)

## Shipped = completed work, not commits

The client cares about **what got done**, in their language. Source "shipped" from
**closed issues + milestone completion**, grouped by feature — the work/decision
layer, per `${CLAUDE_PLUGIN_ROOT}/templates/reference/ISSUE-WORKFLOW.md`. Do **not**
source it from `git log` or merged PRs: commit/PR detail is dev-facing noise for
this audience, and shell/git is disallowed here anyway. If a repo tracks work
outside issues, say the report covers tracked issues only — don't guess at the rest.

## First, every run

1. **Read `/spec/tracker.md`.** If `system: github`, the shipped/milestone sections
   are available. On a **non-GitHub tracker**, say so and degrade: render the
   spec-sourced sections (feature status, open questions, next features) and mark
   the tracker-sourced sections *"tracker not connected — reads unavailable"*.
   Never fabricate tracker state.
2. **Locate the spine.** If there is no `/spec`, there is nothing to report on yet —
   redirect to `/steer:setup` (which routes to `/steer:init` or `/steer:adopt`) and
   stop.
3. **Detect capability via `/steer:tracker-sync`** (MCP vs `gh` vs manual) and say
   which path you took.

## Resolve the reporting period

Pick the window from the argument; default to **`this-week`**:

- **`this-week`** (default) — the last 7 days, ending today. Use the current date
  from context; do not shell out for it.
- **`since <date>`** — an explicit start date (e.g. `since 2026-07-01`), for a
  since-last-report window the human supplies.
- **`milestone [<name>]`** — scope to a release milestone's span (its start →
  due date, both human-set on the milestone). With no name, use the current/next
  open milestone. Milestone dates come from the tracker; **never invent one** — a
  milestone with no due date reports its span as *"date not set"*.

State the resolved window at the top of the report so the reader knows what it
covers.

## Gather the sections (all read-only, all sourced)

Ask `/steer:tracker-sync` for the tracker reads; read `/spec` directly for the rest.

- **Shipped this period** — issues **closed within the window**
  (`/steer:tracker-sync` reads closed issues; the `gh` path filters
  `closed:>=<start>`), grouped by feature, in plain language. Include **milestone
  completion** (closed vs total) as a progress meter per active milestone.
- **In progress** — open issues in an in-progress state (assigned / an
  in-progress label / linked to a feature currently `implemented` but not `live`).
- **Needs your input** — open questions with `impact: blocking` **and**
  `owner: product` across the spine (`spec/features/*/intent.md`, `vision.md`),
  counted and titled in plain language. The follow-up that lets the client
  actually answer them is `/steer:questions bundle` — recommend it, don't inline
  the questionnaire here.
- **What's next** — the next milestone's issues / the highest-status unshipped
  features (`Status:` `approved`/`implemented`), described as outcomes, not tasks.
- **Feature pipeline** — each feature's `Status:` (`draft → approved → implemented
  → validated → live`, the enum in `${CLAUDE_PLUGIN_ROOT}/templates/reference/ENUMS.md`)
  as an at-a-glance pipeline. Tick only what the spec marks; never advance a state
  the spec leaves behind.

## Render the report

Render by the shared Artifact discipline — rule `88-artifacts`, mechanics in
`/steer:reference artifacts` — as a **high-level page a client can read in
seconds**: a header banner with the period and headline (e.g. *"3 features shipped,
Milestone 2 82% complete"*), then the sections above as compact visual blocks —
milestone progress meters, a shipped list grouped by feature, an "in progress"
list, a "needs your input" callout with the open-question count, and a "what's
next" list. Publish to the temp path `<tempdir>/steer-status-<period>.html` (stable
per window so a same-session re-run redeploys to the same URL); publishing stays
human-gated. Where Artifacts are unavailable, print the **Markdown fallback**
inline with the same section shape — never write it to a file under the repo.

When the reader is the client/PO — see rule `05` (Who you are working with) —
render in plain product language: **no** safety-level codes, issue numbers, ADR/CI
jargon, or milestone-mechanics. Keep outcomes and dates; drop the plumbing.

## Updating a previously shared report

Within the same session, re-running for the same window redeploys to the same
Artifact URL. Updating a report shared from a **different** session needs its URL —
steer does not store it (see the "Updating a previously shared page" note in
`/steer:reference artifacts`).

## What this skill is *not*

- **Not** the next-action navigator — "what should I do now?" is `/steer:next`.
- **Not** a forward plan — the release timeline is `/steer:roadmap`.
- **Not** a single-feature deep view — that is `/steer:explain`.
- **Not** a spec author or a tracker writer — it renders what `/spec` and the
  tracker already say and writes nothing back.
- **Not** an auto-publisher — no scheduled or per-window generation by the plugin;
  a human runs it when a report is wanted.

## Recommend the next action

After rendering, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, scoped to this run,
delegating each to its owner:

| Observed state | Category | Action / suggested command |
|---|---|---|
| Open `owner: product` blocking questions in the report | Recommended | Hand the client the questionnaire — `/steer:questions bundle` |
| A feature is `implemented` but not `validated`/`live` | Recommended | Confirm acceptance — `/steer:spec validate <id>` |
| Milestone dates missing / roadmap stale vs shipped work | Recommended | Refresh the timeline — `/steer:roadmap sync` |
| Report rendered, nothing outstanding for the client | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence. This skill is read-only in
all cases; it recommends the next step, it never performs it.

## Coupling rules

Issue lifecycle/state in `ISSUE-WORKFLOW.md`; the status enum in `ENUMS.md`; the
open-question contract (`impact`/`owner`) in `SPEC-FRAMEWORK.md`; Artifact
mechanics in rule `88-artifacts` / `/steer:reference artifacts`; milestone
conventions in `/spec/tracker.md` and rule `35-issue-tracker`. GitHub I/O is
`/steer:tracker-sync`'s job. This skill only aggregates those into a client-facing
progress snapshot.
