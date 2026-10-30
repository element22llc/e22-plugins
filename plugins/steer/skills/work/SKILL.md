---
name: work
description: "Implement a GitHub issue end-to-end - claim, branch, PR (or solo-trunk commit), CI, lifecycle transition - finding or creating the issue when a change needs one."
when_to_use: >-
  Use to work, fix, resume or finish an issue ("fix #123") or to implement a
  change now. `queue #A #B` works through several issues one after another,
  a fresh worker each. `--reviewed` adds a plan review gate for costly changes;
  `--hotfix` only for a real production incident ("prod is down"), never
  ordinary urgent work. Modes that take no issue: `promote` (ship main to
  production), `review` (clear the PR review queue, "review my PRs"), `tidy`
  (clean up the repo root, organize stray documents and diagrams),
  `walkthrough` (record a demo video). `issues`: backlog work with no code
  this turn - capture, triage, decompose, a ranked board.
argument-hint: "[start | resume | status | finish | queue | promote | tidy | review | walkthrough <feature> | issues <mode>] [--reviewed | --hotfix] [#issue ...]"
allowed-tools:
  - Bash(sh *scripts/scan-spine-state.sh*)
  - Bash(git status *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git fetch *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh auth status *)
  - Bash(gh pr create *)
  - Bash(gh pr edit *)
  - Bash(gh pr ready *)
  - Bash(gh pr list *)
  - Bash(gh repo view *)
  - Bash(gh pr checks *)
  - Bash(gh run view *)
  - Bash(gh run watch *)
  - mcp__github__create_pull_request
  - mcp__github__update_pull_request
  - mcp__github__list_pull_requests
  - mcp__plugin_steer_github__create_pull_request
  - mcp__plugin_steer_github__update_pull_request
  - mcp__plugin_steer_github__list_pull_requests
---
<!-- steer:modes start,resume,status,finish,queue,promote,tidy,review,walkthrough,issues -->

Implement work from a GitHub issue by following the `work` skill. This is the
**delivery** door of the issue-first workflow at both of its moments: the
`issues` modes manage the backlog and never edit code; the subcommands below
read an issue and deliver it.

## Guardrails

These hold for the whole run, in every mode.

- **Managed block only.** Progress updates rewrite only the `steer:managed` block,
  following the concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before
  write; stop and report on a concurrent edit; fail closed on duplicate/malformed
  blocks). Human content is never overwritten.
- **Never auto-resolve product decisions or drift** - those wait for the named
  human (see `ISSUE-WORKFLOW.md`). **Asking** that human in-session is how you
  obtain their answer (rule `61-gates`), never a licence to supply one.
- **The merge is the human gate** (rule 45), and not promptable in any mode -
  push and open the PR yourself, as a draft; never mark it ready, merge or
  deploy. Watching CI to conclusion and fixing a red build, once a PR is ready
  or on a trunk push, is **finishing the work**, not crossing that gate. In solo-trunk the trunk commit *is* delivery (Delivery mode below);
  deploy stays human-gated all the same.
- References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`, the Issue-first, Commit
  autonomy, and Definition of Done rules.

## Preconditions

0. **Member (`spec/PRODUCT.md`)? Resolve the spine first**, before step 1, by
   the ladder in `/steer:reference polyrepo`: the tracker and every feature's
   `intent.md` / `contract.md` live in the workspace, so read both from
   **there**. A missing local `intent.md` means the workspace has not been read
   yet, never that the feature is unspecified - **never** author product-level
   spec files here to fill the gap.
0b. **`promote`, `tidy`, `review` and `walkthrough` skip steps 1 and 3** -
   none is issue-scoped (`promote` ships what is merged, `tidy` moves files,
   `review` works the PR queue, `walkthrough` records a demo of an approved
   intent), so none reads the tracker or finds-or-creates an issue. Read
   `modes/promote.md` / `modes/review.md` from Step 1; `tidy` and
   `walkthrough` -> their rows.
0d. **`issues <mode>` is exempt from step 3.** The backlog modes write no code,
   so there is nothing to find-or-create - a capture or triage ask must never
   open an issue for itself. Steps 1 and 2 hold, step 2 with the one carve-out
   `issues` already declares (`bootstrap-labels` runs `gh label create` inline,
   a repo-level op the gateway exposes none for), and `/steer:issues` re-runs
   the same tracker gate on entry; enter the mode rather than repeating it here.
1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop (manual flow only). In a member,
   this is the **workspace's** `spec/tracker.md` resolved in step 0 - a member
   never carries its own.
2. **Route all tracker reads/writes through `/steer:tracker-sync`**, whose own
   operations table is the interface. Never hit `gh`/MCP for issues directly.
   Execution needs its **core** ops only, so `OPERATIONS.md` is the only
   catalogue file this skill reads.
   **Git and PR delivery are not gateway operations** - they are this
   skill's execution concern, under the repo's commit/PR-autonomy rules.
3. **No issue named but a mutation was requested?** Find-or-create one first
   (Issue-first - work outside its two cases needs none), then `start`.

## Authorization (what an implement request grants)

A CLI "fix/implement #N" request authorizes, without extra confirmation:
read/search the issue, create-or-reuse the issue where Issue-first requires
one, claim it, update its managed state, create/switch the local branch, modify the local repository, run tests,
commit, push, and open/update the PR - the full delivery loop up to the merge
(Commit autonomy). **Merge and deploy are never implied.**

> **Pre-approved shell scope.** The `allowed-tools` frontmatter above
> pre-approves read-only git and PR inspection, `git fetch`, branch
> create/switch, the Rule-45-autonomous `git add` / `git commit`, the delivery
> moves `git push` / `gh pr create` / `gh pr edit`, and read-only CI status, so
> the post-push CI watch runs without a prompt per poll; with no authenticated
> `gh`, the MCP `create_pull_request` / `update_pull_request` /
> `list_pull_requests` tools stand in for the PR moves. It does **not**
> pre-approve `gh pr merge`, `gh pr review`, `gh api`, `gh workflow
> run`, or destructive git (`push --force` flag-first, `reset --hard`, `clean -fdx`,
> `branch -D`) - merge and approval stay human; tracker I/O routes through
> `/steer:tracker-sync`.
> Two hooks can still ask: the trunk-push gate in an ungraduated solo-trunk
> repo (`/steer:reference gates`), and the stacked-PR gate (rule 45).

## Delivery mode

The two-state delivery model - pr-flow vs solo-trunk, the `CLAUDE.md`
delivery-mode marker (absent -> pr-flow) and what each mode authorizes - is
canonical in **rule 45 (Commit autonomy)**, the trunk-push gate in
`/steer:reference gates`; determine the mode once at
`start` / `finish` and apply it, don't re-derive it. **Issue-first holds in both
modes**; they differ only in the branch/PR ceremony.

- **pr-flow** (default) - the flow described throughout: claim -> `issue/<n>`
  branch + `spec/.work` marker -> implement -> push -> open a draft PR ->
  `validate`; its author marks it ready, which runs CI. On declared-but-unprotected `main`, run it unchanged, note the
  missing wall and recommend `/steer:setup protect`.
- **solo-trunk** - substitute the trunk commit wherever a step says *branch*,
  *marker* or *PR*; still claim the issue, and close it from that commit
  (`Closes #N`, or `Closes owner/repo#N` when the tracker repo differs - see
  Closing ref). Everything else - validation, managed-block
  progress, closure-reason semantics - is identical. While a graduation signal
  stands and no waiver is recorded, the trunk-push hook surfaces the session's
  first push for a human yes (`/steer:reference gates`).

## Subcommands (distinct, idempotent)

| Subcommand | What it does |
|---|---|
| **`start #N`** | Resolve + validate the issue, detect a conflicting claim, **claim** it, create/reuse the branch and write the work marker (pr-flow only), load linked specs, begin implementing. |
| **`resume #N`** | Reconstruct context from the issue + recorded branch/PR + working tree, reconcile stale markers, continue from the actual lifecycle state. |
| **`status #N`** | **Read-only**: state, claimant, branch, PR, blockers, spec readiness, outstanding validation. Mutates nothing. |
| **`finish #N`** | Validate, run the independent code gate (non-Trivial changes), update progress, commit, push, open-or-update the PR **as a draft**, transition to `validate`, and **stop** - its author marks it ready, which runs CI. Never `done` merely because a PR was opened - and never on a *skipped* check. |
| **`queue #A #B ...`** | Deliver several independent issues one after another: triage the list, then one fresh worker per issue runs `start` -> `finish` in its own worktree, each card verified, blockers recorded and the queue continued. Ends at draft PRs. -> [`modes/queue.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/queue.md) |
| **`promote`** | **Not issue-scoped** - what ships is everything already merged. Reads `policy/delivery.yml`'s `production_gate`, shows what would ship, cuts the consumer changelog, and opens the production promotion PR. Stops there: **merging it deploys production and is the human's gate.** -> [`modes/promote.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/promote.md) |
| **`review [#PR ...] [--mine]`** | **Not issue-scoped** - batch-reviews the PR queue in parallel and approves only the PRs the human names; `--mine` readies your own. Never merges. -> [`modes/review.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/review.md) |
| **`tidy`** | **Not issue-scoped** - sweep the loose files at the repo root into their correct home (`/spec/reference`, `/spec/design`): move the confidently-classified strays now, propose every rename and delete for a yes. Changes where files live, never behavior. |
| **`walkthrough <feature>`** | **Not issue-scoped** - record a captioned walkthrough video of the running app that proves an approved intent: plan scenes from it, commit a re-recordable script and a `mise run demo:record` task, verify the frames, hand over the MP4. |
| **`issues <mode>`** | **Not issue-scoped** - the backlog layer, which never edits code: `capture`, `triage`, `brainstorm`, `materialize`, `decompose`, `epic`, `status`, `board`, `reconcile`, the `publish-*` family, `bootstrap-labels`. Its mode map names the one procedure file each mode needs. |

**`tidy`, `walkthrough` and `issues` delegate, they do not restate.** All three
are internal skills (`user-invocable: false`) that own their procedure -
`/steer:tidy` loads `HOUSEKEEPING.md`, `/steer:walkthrough` the demo templates,
`/steer:issues` the one mode file its mode map names. Invoke the skill and follow
it; re-derive none of it here. They are modes of this door because each changes
the repo or its **work state**, which is what it owns - the issue captured today
is the one `start` claims tomorrow. A recommendation you hand
back to a user names `/steer:work <mode>`, never the owning skill.

**`status #N` and `issues status` are different views.** `status #N` is one
claimed issue's execution - claimant, branch, PR, CI, validation. `issues status
[#N | <feature-id>]` joins the issue to the spine - intent, contract readiness,
sub-issues, an epic's rollup. "How is my PR doing?" vs "is this feature ready?".

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent - re-running a
phase reconciles rather than duplicates.

**Read the full procedure before executing one:**
[`modes/subcommands.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/subcommands.md).

## Optional flags - read the procedure only when the flag is passed

- **`--reviewed`** - add an independent plan gate and a human plan sign-off
  before implementing, on top of the code gate `finish` always runs on
  non-Trivial work. Triage trivial work out of the gates.
  -> procedure: [`modes/reviewed.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/reviewed.md)
- **`--hotfix`** - the production-incident fast path (rule `61-gates` -> Hotfix): a
  `hotfix/<n>-slug` branch, issue after-the-fact, one expedited reviewer, and a
  mandatory traceability follow-up. Relaxes ceremony, never the human gates.
  **Only** for an active incident on a confirmed-deployed production; else normal flow.
  -> procedure: [`modes/hotfix.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/hotfix.md)

Neither flag changes the subcommands above; both leave the merge and deploy
gates exactly where they are.

## Closing ref - check the tracker repo first

A bare `Closes #N` names an issue in the PR's own repo; a tracker in another
repo needs `Closes owner/repo#N`, or the issue silently stays open - and,
because this skill treats the merged PR as transition evidence, unadvanced.

- **No `repository:` declared in `/spec/tracker.md`, or the value is absent / a
  placeholder / unreadable** -> write `Closes #N`. Nothing further to do.
- **A `repository:` is declared** -> resolve both sides and compare before
  writing any closing ref:
  [`CLOSING-REF.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/CLOSING-REF.md).

Divert **only on positive proof of a mismatch**.

In a **polyrepo member** the mismatch is structural, not incidental: the tracker
is the workspace's, so a member PR closes its issue only through the qualified
`Closes owner/repo#N` - write it every time, confirm the close after merge, and
land the spec update
(the owning `contract.md`) as its own change in the **workspace** repo - those two
PRs cannot be atomic (`/steer:reference polyrepo`).

## Completion semantics

**Closure reason - not the mere fact of closure - decides the terminal state.**
Inspect it before transitioning a closed issue; keep delivery state as independent
evidence (a merged PR - or, in solo-trunk, the closing trunk commit - is
necessary for `done`, not sufficient on its own).

- Opening the draft PR, local gates green -> `validate` (never `done`). **(Solo-trunk has no PR - the
  trunk commit that closes the issue is the delivery; go straight to the closure
  reasons below.)**
- Closed as **`completed`** (delivered - PR merged or trunk commit landed - **and**
  acceptance criteria accepted) -> `done`.
- Closed as **`rejected` / `duplicate` / `obsolete` / `not-planned` /
  `superseded`** -> **`cancelled`**, never `done` - record a replacement pointer
  where one applies. Cancelled work was not delivered.
- PR closed **without** merge -> back to `in-progress` or `blocked`.
- `status` / `resume` / `finish` reconcile stale markers on the next interaction,
  reading the closure reason rather than assuming "closed == done." **They never
  touch the spec's `Status:`** - delivery progress lives only in the issue marker,
  and an `approved` intent whose issue is `in-progress`, `validate`, or `done` is
  correct, not drift (crosswalk in `ISSUE-WORKFLOW.md`). The one spec-side state
  this flow can legitimately surface is a `live` intent whose issue never reached a
  terminal state; report it, never rewrite it.

## Branch naming

Use the repository's configured branch convention if one exists. Otherwise fall
back to `issue/<number>-<slug>` - **not** `fix/...`, which would mislabel feature,
docs, or infra work. Record the branch in `steer:branch` (tracker metadata) **and**
in the local marker `spec/.work/<branch>.md` (slashes -> underscores; local-only -
`spec/.work/` is git-ignored). The marker is what the Stop-hook reconciliation
checks to confirm a branch is issue-governed, ahead of any branch-name guess; an
unconventional but claimed branch is still recognized. Optional housekeeping:
remove the marker when the issue is closed.

In **`--hotfix` mode**, use `hotfix/<n>-slug` instead (see `modes/hotfix.md`).

Its exact format - the write-once `issue:`/`branch:` lines, the newest-first
session list the Stop hook keeps current, seeding from `$CLAUDE_CODE_SESSION_ID`,
and the legacy extensionless-marker upgrade - is in
[`WORK-MARKER.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/WORK-MARKER.md).

## Concurrency & claims

Before claiming or mutating, check for conflicts: the issue is already assigned
to someone else, `steer:claimed-by` names another context, a different `steer:branch`
is recorded, the recorded branch is gone, the worktree is dirty, or two local
sessions exist for the same user. **A conflicting active branch or claimant
prevents automatic takeover** - report it and ask. GitHub *assignment* represents
the accountable human; the *branch* marker represents the active execution
context.

## Multiple issues

`Implement #123 and #124` -> **one branch + PR per issue** by default (in
solo-trunk, **one trunk commit per issue**, each closing its own `#N`). Combine only
when one issue explicitly depends on the other, separating them would produce an
invalid intermediate state, or the user explicitly asks for combined delivery -
otherwise issue-first traceability degrades into many-issues-to-one-PR.
To deliver them in one run, one fresh worker each, use `queue`
([`modes/queue.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/queue.md)).

Native `/batch`, `/autofix-pr`, plan mode and `claude --worktree` fit this flow
as `/steer:reference conventions` -> Native Claude Code delivery features lays
out - read it before driving one.

## Discovered work - bounded scope

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
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, obeying its
**locality rule** - only this issue, its branch, PR, criteria, validation, and
any blocker directly hit, never the wider workspace. This skill's execution
state -> action mapping (and how it reads in solo-trunk) is in
[`NEXT-ACTION.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/NEXT-ACTION.md) - **read it
when you get here.** The block recommends only; it never merges, deploys, or
auto-advances state.
