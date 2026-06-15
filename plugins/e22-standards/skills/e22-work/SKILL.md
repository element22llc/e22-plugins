---
name: e22-work
description: "Execute a GitHub issue end-to-end from local Claude Code — read and validate the issue, claim it, create or reuse a branch, load linked specs, implement, test, update progress on the issue, open the PR, and transition lifecycle state. The execution counterpart to /e22-issues (which owns backlog management and never edits code). Routes all tracker-metadata I/O through /e22-tracker-sync; git and PR delivery follow the repo's commit/PR-autonomy rules. One issue per branch/PR by default."
when_to_use: Use when asked to work, start, resume, or finish a specific issue ("work on #123", "fix #123", "implement #123 and #124"), or when a code/config/behavior change in a GitHub-adopted repo needs an issue found-or-created and then implemented.
argument-hint: "[start | resume | status | finish] [#issue ...]"
---

Implement work from a GitHub issue by following the `e22-work` skill. This is the
**execution** layer of the issue-first workflow: `/e22-issues` manages the
backlog and never edits code; `/e22-work` reads an issue and delivers it.

## Preconditions

1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop (manual flow only).
2. **Route all tracker reads/writes through `/e22-tracker-sync`** (the gateway —
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

## Subcommands (distinct, idempotent)

- **`start #N`** — resolve + validate the issue (actionable? readiness met for
  its kind per `ISSUE-WORKFLOW.md`?); detect a conflicting claim or branch;
  **claim** it (`assign` + `e22:claimed-by`, `transition` → `in-progress`);
  create or reuse the branch; load linked specs (`e22:spec-path`,
  acceptance criteria); begin implementation.
- **`resume #N`** — reconstruct context from the issue + recorded `e22:branch` /
  `e22:pull-request` + working tree; reconcile stale markers (e.g. a recorded
  branch that no longer exists, a PR that merged/closed while away); continue
  from the actual lifecycle state.
- **`status #N`** — **read-only**: report state, claimant, branch, PR, blockers,
  spec readiness, and outstanding validation. Mutates nothing.
- **`finish #N`** — run the required validation; update progress (managed block +
  comment); when authorized, commit/push and open-or-update the PR; transition to
  `validate`. **Never mark `done` merely because a PR was opened.**

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent — re-running a
phase reconciles rather than duplicates.

## Completion semantics

- Opening a PR → `validate` (never `done`).
- PR merged or issue otherwise closed → `done` (a closed issue).
- PR closed **without** merge → back to `in-progress` or `blocked`.
- `status` / `resume` / `finish` reconcile stale markers on the next interaction.

## Branch naming

Use the repository's configured branch convention if one exists. Otherwise fall
back to `issue/<number>-<slug>` — **not** `fix/…`, which would mislabel feature,
docs, or infra work. Record the branch in `e22:branch`.

## Concurrency & claims

Before claiming or mutating, check for conflicts: the issue is already assigned
to someone else, `e22:claimed-by` names another context, a different `e22:branch`
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
`/e22-tracker-sync find-or-create`. Create the separate issue when the work has
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
| Acceptance criteria not yet met | Blocking now (next transition) | Continue — `/e22-work resume #N` |
| Required validation failing | Blocking now | Fix failures, then `/e22-work finish #N` |
| Implemented, PR not opened | Blocking now (next transition) | `/e22-work finish #N` |
| PR open, in `validate`, awaiting review | Human decision required | A reviewer reviews the PR (no command) |
| PR merged but issue still `validate` (stale) | Blocking now | Reconcile to `done` — `/e22-work resume #N` |
| Issue `done` | Complete | Optional: start another ready issue — `/e22-work start #N`, else `No action is currently required.` |

Choose one `Current recommended action` by precedence. The block recommends only
— it never merges, deploys, or auto-advances state.

## Guardrails

- **Managed block only.** Progress updates rewrite only the `e22:managed` block,
  following the concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before
  write; stop and report on a concurrent edit; fail closed on duplicate/malformed
  blocks). Human content is never overwritten.
- **Never auto-resolve product decisions or drift** — those wait for the named
  human (see `ISSUE-WORKFLOW.md`).
- **The PR is the human gate.** Propose the PR; don't merge or deploy.
- References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`, the Issue-first, Commit
  autonomy, and Definition of Done rules.
