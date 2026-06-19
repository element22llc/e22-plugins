---
name: work
description: "Execute a GitHub issue end-to-end from local Claude Code — read and validate the issue, claim it, create or reuse a branch, load linked specs, implement, test, update progress on the issue, open the PR, and transition lifecycle state. The execution counterpart to /steer:issues (which owns backlog management and never edits code). Routes all tracker-metadata I/O through /steer:tracker-sync; git and PR delivery follow the repo's commit/PR-autonomy rules. One issue per branch/PR by default."
when_to_use: Use when asked to work, start, resume, or finish a specific issue ("work on #123", "fix #123", "implement #123 and #124"), or when a code/config/behavior change in a GitHub-adopted repo needs an issue found-or-created and then implemented.
argument-hint: "[start | resume | status | finish] [#issue ...]"
allowed-tools:
  - Bash(git status *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(gh pr checks *)
  - Bash(gh run view *)
  - Bash(gh run watch *)
---
<!-- steer:modes start,resume,status,finish -->

Implement work from a GitHub issue by following the `work` skill. This is the
**execution** layer of the issue-first workflow: `/steer:issues` manages the
backlog and never edits code; `/steer:work` reads an issue and delivers it.

## Preconditions

1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop (manual flow only).
2. **Route all tracker reads/writes through `/steer:tracker-sync`** (the gateway —
   `search`/`get`/`find-or-create`/`update`/`comment`/`set-type`/`label`/
   `transition`/`assign`/`link-pr`/`close`). Never hit `gh`/MCP for issues
   directly. **Git and PR delivery are not gateway operations** — they are this
   skill's execution concern, under the repo's commit/PR-autonomy rules.
3. **No issue named but a mutation was requested?** Find-or-create one first
   (Issue-first), then `start`.

## Authorization (what an implement request grants)

A CLI "fix/implement #N" request authorizes, without extra confirmation:
read/search the issue, create-or-reuse the issue, claim it, update its managed
state, create/switch the local branch, modify the local repository, and run
tests. **Commit, push, and open/update PR follow the existing commit- and
PR-autonomy rules; merge and deploy are never implied.**

> **Pre-approved shell scope (frontmatter `allowed-tools`).** To cut repetitive
> prompts, this skill pre-approves only read-only git inspection (`status`, `diff`,
> `log`, `show`, `rev-parse`), branch create/switch (`checkout -b`, `switch`), the
> Rule-45-autonomous local mutations `git add` / `git commit`, and **read-only CI
> status** (`gh pr checks`, `gh run view`, `gh run watch`) so the post-push CI watch
> (see `finish`) runs without a prompt per poll. It deliberately does
> **not** pre-approve `git push`, `gh pr create/edit/merge`, `gh api`, `gh workflow run`,
> or destructive git (`reset --hard`, `clean -fdx`, `branch -D`) — those keep the human
> gate. Only those read-only CI reads are pre-approved; every `gh` *write* stays gated,
> and tracker I/O still routes through `/steer:tracker-sync`.

## Subcommands (distinct, idempotent)

- **`start #N`** — resolve + validate the issue (actionable? readiness met for
  its kind per `ISSUE-WORKFLOW.md`?); detect a conflicting claim or branch;
  **claim** it (`assign` the invoking GitHub user — self-assign — + set
  `steer:claimed-by`, `transition` → `in-progress`);
  create or reuse the branch; **write the local work marker**
  `spec/.work/<branch>.md` (slashes → underscores) in the marker format below, so
  the end-of-turn Stop-hook reconciliation recognizes the branch as
  issue-governed; load linked specs (`steer:spec-path`, acceptance criteria);
  begin implementation.
- **`resume #N`** — reconstruct context from the issue + recorded `steer:branch` /
  `steer:pull-request` + working tree; reconcile stale markers (e.g. a recorded
  branch that no longer exists, a PR that merged/closed while away). **If the
  marker's session list (below) has a head session different from the current
  one, surface it as a context source** — offer `claude --resume <id>` to re-enter
  that conversation, and (if present) the transcript located by globbing
  `"$CLAUDE_CONFIG_DIR"/projects/*/<id>.jsonl`. Treat it as a best-effort
  breadcrumb, never authority: the session may be gone or on another machine, so
  fall back cleanly to reconstruction from the issue + tree. Then record the
  current session at the head of the list. Continue from the actual lifecycle
  state.
- **`status #N`** — **read-only**: report state, claimant, branch, PR, blockers,
  spec readiness, and outstanding validation. Mutates nothing.
- **`finish #N`** — run the required validation; update progress (managed block +
  comment); when authorized, commit/push and open-or-update the PR; **then watch CI
  to conclusion** (`gh pr checks --watch`) before transitioning. On a red build,
  diagnose and fix it as part of the same unit of work — re-push (still
  human-gated) and re-watch — until checks are green or a remaining failure is
  legitimately non-blocking (and said so). Only transition to `validate` once CI is
  green; hand the reviewer a green PR, not a running or red one. A PR-scoped failure
  is fixed or commented on the PR, **not** filed as a tracker issue — defer to the
  CI-failure triage in `ISSUE-WORKFLOW.md` (only a reproducible default-branch
  failure becomes a `source:ci` bug). **Never mark `done` merely because a PR was
  opened.** If you have stepped away, the in-turn watch blocks the turn; re-enter
  monitoring via the harness `/loop` over `gh pr checks` or a background watch —
  steer ships no background poller.

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent — re-running a
phase reconciles rather than duplicates.

## Completion semantics

**Closure reason — not the mere fact of closure — decides the terminal state.**
Inspect it before transitioning a closed issue; keep merge state as independent
evidence (a merged PR is necessary for `done`, not sufficient on its own).

- Opening a PR → `validate` (never `done`).
- Closed as **`completed`** (PR merged **and** acceptance criteria accepted) →
  `done`.
- Closed as **`rejected` / `duplicate` / `obsolete` / `not-planned` /
  `superseded`** → **`cancelled`**, never `done` — record a replacement pointer
  where one applies. Cancelled work was not delivered.
- PR closed **without** merge → back to `in-progress` or `blocked`.
- `status` / `resume` / `finish` reconcile stale markers on the next interaction,
  reading the closure reason rather than assuming "closed == done."

## Branch naming

Use the repository's configured branch convention if one exists. Otherwise fall
back to `issue/<number>-<slug>` — **not** `fix/…`, which would mislabel feature,
docs, or infra work. Record the branch in `steer:branch` (tracker metadata) **and**
in the local marker `spec/.work/<branch>.md` (slashes → underscores; local-only —
`spec/.work/` is git-ignored). The marker is what the Stop-hook reconciliation
checks to confirm a branch is issue-governed, ahead of any branch-name guess; an
unconventional but claimed branch is still recognized. Optional housekeeping:
remove the marker when the issue is closed.

### Marker format

The marker is a small Markdown file. The `issue:` / `branch:` lines are written
once and never rewritten; the session list under the heading is the single source
of truth for "which Claude Code session(s) worked this branch" — the head is the
most recent. The Stop hook keeps that head current each turn, and `resume` reads
it (see above). Session ids are local breadcrumbs and **never** go into tracker
metadata.

```markdown
# Work marker — issue 123

- issue: 123
- branch: issue/123-export-fix

## Claude Code sessions (newest first)

- 64ae4a08-7069-4810-8cd0-d443c8511365
```

Seed the first session id from `$CLAUDE_CODE_SESSION_ID` (fail-open: if it is
empty, write the marker without a session bullet — its existence still governs).
The session heading + list must be the **last** block in the file. If a legacy
extensionless `spec/.work/<branch>` marker exists, upgrade it: carry over any
`issue`/`branch` it records, write the new `.md` file, then remove the old one.

## Concurrency & claims

Before claiming or mutating, check for conflicts: the issue is already assigned
to someone else, `steer:claimed-by` names another context, a different `steer:branch`
is recorded, the recorded branch is gone, the worktree is dirty, or two local
sessions exist for the same user. **A conflicting active branch or claimant
prevents automatic takeover** — report it and ask. GitHub *assignment* represents
the accountable human; the *branch* marker represents the active execution
context.

## Multiple issues

`Implement #123 and #124` → **one branch + PR per issue** by default. Combine only
when one issue explicitly depends on the other, separating them would produce an
invalid intermediate state, or the user explicitly asks for combined delivery —
otherwise issue-first traceability degrades into many-issues-to-one-PR.

## Discovered work — bounded scope

While implementing, if you find an unrelated bug, tech debt, a missing test, a
security concern, or a new feature request: keep the current issue's scope
bounded and **file a separate linked issue** (related/blocking) via
`/steer:tracker-sync find-or-create`. Create the separate issue when the work has
independent acceptance criteria, needs a new product decision, materially changes
risk, or is separately deliverable; necessary **localized supporting changes**
stay in the current issue and are documented in its managed block. Continue with
the separate work only when the current issue requires it.

## Recommend the next action

End every invocation with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. Per the **locality
rule**, consider only this issue, its branch, PR, criteria, validation, and any
blocker directly hit — not the wider workspace. Map execution state to actions
without redefining the subcommands above:

| State | Category | Action / suggested command |
|---|---|---|
| Acceptance criteria not yet met | Blocking now (next transition) | Continue — `/steer:work resume #N` |
| Required validation failing | Blocking now | Fix failures, then `/steer:work finish #N` |
| Implemented, PR not opened | Blocking now (next transition) | `/steer:work finish #N` |
| PR open, CI running | Blocking now (next transition) | Watch to conclusion — `gh pr checks --watch` (detached: `/loop` over `gh pr checks`) |
| PR open, CI red | Blocking now | Fix the failure, re-push, re-watch |
| PR open, CI green, in `validate`, awaiting review | Human decision required | A reviewer reviews the PR (no command) |
| PR merged but issue still `validate` (stale) | Blocking now | Reconcile to `done` — `/steer:work resume #N` |
| Issue `done` | Complete | Optional: start another ready issue — `/steer:work start #N`, else `No action is currently required.` |

Choose one `Current recommended action` by precedence. The block recommends only
— it never merges, deploys, or auto-advances state.

## Guardrails

- **Managed block only.** Progress updates rewrite only the `steer:managed` block,
  following the concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before
  write; stop and report on a concurrent edit; fail closed on duplicate/malformed
  blocks). Human content is never overwritten.
- **Never auto-resolve product decisions or drift** — those wait for the named
  human (see `ISSUE-WORKFLOW.md`).
- **The PR is the human gate.** Propose the PR; don't merge or deploy. Watching CI
  to conclusion and fixing a red build is **finishing the work**, not crossing that
  gate — it is expected, not a gate breach. Merge and deploy stay human-gated.
- References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`, the Issue-first, Commit
  autonomy, and Definition of Done rules.
