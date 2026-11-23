---
name: work
description: "Implement a GitHub issue end-to-end, from claim to PR (or solo-trunk commit) and CI, finding or creating the issue when a change needs one."
when_to_use: >-
  Use to work, fix, resume or finish an issue ("fix #123") or to implement a
  change now. Several issues ("fix #12 and #15") run as a queue
  automatically, one after another. `--reviewed` adds a plan review gate for
  costly changes; `--hotfix` only for a real production incident ("prod is
  down"), never ordinary urgent work. `debug` finds a bug's root cause before any fix
  ("why is this failing?"), diagnosis only when no fix is asked. `qa` clicks
  through a UI change's flows in a real browser. Modes that take no issue:
  `promote` (ship main to production), `review` (clear the PR review queue,
  "review my PRs"), `drive` (work on its own, attended or on a schedule:
  fix your open PRs, review the queue, hand ready issues to subagents), `tidy` (clean up the repo root, organize stray documents
  and diagrams), `walkthrough` (record a demo video). `issues`: backlog work
  with no code this turn - capture, triage, decompose, a ranked board.
argument-hint: "[start | resume | status | finish | queue | drive | debug | qa | promote | tidy | review | walkthrough <feature> | issues <mode>] [--reviewed | --hotfix] [#issue ...]"
allowed-tools:
  - Bash(sh *scripts/scan-spine-state.sh*)
  - Bash(sh *scripts/pr-assets.sh*)
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
  - Bash(gh pr view *)
  - Bash(gh pr diff *)
  - Bash(gh pr comment *)
  - Bash(gh repo view *)
  - Bash(gh pr checks *)
  - Bash(gh run view *)
  - Bash(gh run watch *)
  - Bash(orca reference add *)
  - Bash(orca skills get *)
  - Bash(orca worktree list *)
  - Bash(orca orchestration worker-start *)
  - mcp__github__create_pull_request
  - mcp__github__update_pull_request
  - mcp__github__list_pull_requests
  - mcp__plugin_steer_github__create_pull_request
  - mcp__plugin_steer_github__update_pull_request
  - mcp__plugin_steer_github__list_pull_requests
---
<!-- steer:modes start,resume,status,finish,queue,drive,debug,qa,promote,tidy,review,walkthrough,issues -->

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
  push and open the PR yourself (ready only on a clean code gate); never merge
  or deploy. Watching CI to conclusion
  and fixing a red build, once a PR is ready or on a trunk push, is **finishing
  the work**, not crossing that gate. In solo-trunk the trunk commit *is* delivery (Delivery mode below);
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
0b. **`promote`, `tidy`, `review`, `walkthrough` and a symptom-only `debug`
   skip steps 1 and 3** - none is issue-scoped, so none reads the tracker or
   finds-or-creates an issue. Read `modes/promote.md` / `modes/review.md` /
   `modes/debug.md` from Step 1; `tidy` and `walkthrough` -> their rows.
0c. **`drive` skips step 3** - it finds work, never creates it; read
   `modes/drive.md` after step 2.
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

> **Pre-approved shell scope.** `allowed-tools` covers read-only git/PR/CI
> inspection, `git fetch`, branch create/switch, `git add` / `git commit` / `git push`, and
> `gh pr create` / `edit` / `ready` / `view` / `diff` / `comment` (the MCP PR tools when `gh` is not
> authenticated), so the CI watch runs without a prompt per poll. It does **not**
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
  branch + `spec/.work` marker -> implement -> push -> open the PR (ready on a
  clean code gate, else draft) -> `validate`. On declared-but-unprotected `main`, run it unchanged, note the
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
| **`start #N`** | Validate and **claim** the issue, branch + work marker (pr-flow), load linked specs, implement. |
| **`resume #N`** | Rebuild context from the issue, recorded branch/PR and tree; continue from the real lifecycle state. |
| **`status #N`** | **Read-only** execution state - claimant, branch, PR, blockers, validation. Mutates nothing. |
| **`finish #N`** | Validate, code gate (non-Trivial), commit, push, PR (**ready** only on a clean gate, CI watched; else a **draft**), -> `validate`, **stop**. Never `done` because a PR opened, never on a *skipped* check. |
| **`queue #A #B ...`** | Several independent issues, one fresh worker each running `start` -> `finish`; ends at PRs. Automatic for two or more. -> [`modes/queue.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/queue.md) |
| **`drive [--max N] [--label <l>]`** | One autonomous cycle: your PRs with change requests or red CI, then the review queue (cards only), then up to N ready issues, each to a fresh worker. Ends on `Drive: idle` or `Drive: work remains` for `/goal` or `/loop` to repeat. Never merges, approves or creates an issue. -> [`modes/drive.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/drive.md) |
| **`debug [#N \| <symptom>]`** | Cause before fix; symptom only -> diagnosis only, not issue-scoped. Read `modes/debug.md` first. |
| **`qa [#N]`** | Opt-in: click through the flows the diff touches in a real browser, then attach before/after screenshots to the PR. Read `modes/qa.md` first. |
| **`promote`** | **Not issue-scoped** - opens the `release/*` -> `prod` Release PR from what is merged; **merging it deploys production and is the human's gate.** -> `modes/promote.md` |
| **`review [#PR ...] [--mine]`** | **Not issue-scoped** - batch-reviews the PR queue, approves only the PRs the human names; `--mine` readies your own. Never merges. -> `modes/review.md` |
| **`tidy`** | **Not issue-scoped** - file loose root documents into `/spec/reference`, `/spec/design`; renames and deletes wait for a yes. Never changes behavior. |
| **`walkthrough <feature>`** | **Not issue-scoped** - record a captioned video of the running app proving an approved intent. |
| **`issues <mode>`** | **Not issue-scoped** backlog layer, never edits code: `capture`, `triage`, `brainstorm`, `materialize`, `decompose`, `epic`, `status`, `board`, `reconcile`, `publish-*`, `bootstrap-labels`. |

**`tidy`, `walkthrough` and `issues` delegate, they do not restate:** invoke
`/steer:tidy`, `/steer:walkthrough` or `/steer:issues` and follow it - each owns
its procedure. A recommendation you hand back names `/steer:work <mode>`, never
the owning skill.

**`status #N` is not `issues status`.** `status #N` is one claimed issue's
execution (claimant, branch, PR, CI, validation); `issues status [#N |
<feature-id>]` joins it to the spine (intent, contract readiness, sub-issues).

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`; the phases stay distinct, and re-running one reconciles.
Two or more issues -> `queue` (Multiple issues).

**Read the full procedure before executing one:**
[`modes/subcommands.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/subcommands.md).

## Optional flags - read the procedure only when the flag is passed

- **`--reviewed`** - an independent plan gate and a human plan sign-off before
  implementing, on top of `finish`'s code gate. Trivial work skips the gates;
  High-risk work gets them automatically (the sign-off is the rule
  `60-high-risk` scoping).
  -> procedure: [`modes/reviewed.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/reviewed.md)
- **`--hotfix`** - the production-incident fast path (rule `61-gates` -> Hotfix): a
  `hotfix/<n>-slug` branch, issue after-the-fact, an expedited review, and a
  mandatory traceability follow-up. Relaxes ceremony, never the human gates.
  **Only** for an active incident on a confirmed-deployed production; else normal flow.
  -> procedure: [`modes/hotfix.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/hotfix.md)

Neither flag changes the subcommands (`queue` refuses `--hotfix`) or moves
the merge and deploy gates.

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

**Closure reason - not the mere fact of closure - decides the terminal state**
(`ISSUE-WORKFLOW.md` -> Completion rules and crosswalk). PR open, local
gates green -> `validate`, never `done`; solo-trunk has no PR, its closing trunk
commit is the delivery. Closed `completed` (delivered **and** acceptance
accepted) -> `done`. Closed `rejected` / `duplicate` / `obsolete` /
`not-planned` / `superseded` -> **`cancelled`**, never `done`, with a
replacement pointer where one applies. PR closed without merge -> `in-progress`
or `blocked`. `status` / `resume` / `finish` reconcile stale markers by the
closure reason and **never touch the spec's `Status:`**: an `approved` intent
whose issue is `in-progress`, `validate` or `done` is correct; a `live` intent
whose issue never reached a terminal state is reported, never rewritten.

## Branch naming

Use the repository's configured branch convention if one exists. Otherwise fall
back to `issue/<number>-<slug>` - **not** `fix/...`, which would mislabel feature,
docs, or infra work. Record the branch in `steer:branch` (tracker metadata) **and**
in the local marker `spec/.work/<branch>.md` (slashes -> underscores;
git-ignored). A closed issue's marker is removed, never left to read as a live
claim. In **`--hotfix` mode**, use `hotfix/<n>-slug` instead. Marker format and
removal: [`WORK-MARKER.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/WORK-MARKER.md).

## Concurrency & claims

Before claiming or mutating, check for conflicts: the issue is already assigned
to someone else, `steer:claimed-by` names another context, a different `steer:branch`
is recorded, the recorded branch is gone, the worktree is dirty, or two local
sessions exist for the same user. **A conflicting active branch or claimant
prevents automatic takeover** - report it and ask. GitHub *assignment* represents
the accountable human; the *branch* marker represents the active execution
context.

## Multiple issues

An implement ask naming two or more issues - `Implement #123 and #124`, `start
#A #B`, a bare `#A #B` - **runs as `queue`** without being asked: say so in one
line and follow `modes/queue.md`, carrying `--reviewed` over (`--hotfix` stays
refused). Each issue gets **one branch + PR** (in solo-trunk, **one trunk
commit**, closing its own `#N`). `status #A #B` stays read-only.

## Discovered work - bounded scope

An unrelated bug, tech debt, missing test, security concern or feature request
found while implementing gets **a separate linked issue** (related/blocking, `/steer:tracker-sync
find-or-create`) when it has its own acceptance criteria, needs a new product
decision, materially changes risk, or is separately deliverable. Necessary **localized
supporting changes** stay in this issue, noted in its managed block. Do the
separate work only when this issue requires it.

## Recommend the next action

End every invocation with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, obeying its
**locality rule** - only this issue, its branch, PR, criteria, validation, and
any blocker directly hit, never the wider workspace. This skill's execution
state -> action mapping (and how it reads in solo-trunk) is in
[`NEXT-ACTION.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/NEXT-ACTION.md) - **read it
when you get here.** The block recommends only; it never merges, deploys, or
auto-advances state.
