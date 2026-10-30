# `/steer-work queue` - deliver a list of issues, one fresh worker each

Read this file only when `queue` is the subcommand. It is issue-scoped -
Preconditions 1 and 2 hold - but every issue is named, so step 3 has nothing to
find-or-create.

**What this owns and where it stops.** This session is the orchestrator: it
triages the list, hands each issue to a fresh worker, checks what the worker
reports, and relays the human gates. It implements nothing itself. Each issue
is delivered by the ordinary `start` -> `finish` flow, so every guarantee of
that flow holds per issue: one branch and one draft PR off the default branch,
the local gates, the code gate. **It never merges and never readies a PR** -
the run ends at drafts.

`queue #A #B ... [--reviewed]` runs the issues in the order given. Every
non-Trivial issue gets the independent plan gate by default: nobody watches
each issue start, so a misread issue would otherwise cost a full
implementation and code gate before anyone saw it. `--reviewed` adds the human
plan sign-off on top, issue by issue. `--hotfix` is refused: an incident is one
issue, `/steer-work --hotfix #N`. A list of one is `start #N`.

## Step 1 - triage from metadata, before any worker

Read each issue through `/steer-tracker-sync`. Set aside, with its one reason,
any issue that is:

- claimed or assigned by someone else (Concurrency & claims in `SKILL.md`);
- not ready for its kind (`ISSUE-WORKFLOW.md`);
- in a rule `60-high-risk` area with no in/out scope recorded in the issue -
  that needs the dev's scoping, not a queue slot;
- dependent on another queued issue. Dependent work is a stack or a `batch/*`
  branch (rule 45), never a queue.

Print the run order and the set-asides, then start. The list is the implement
request: it authorizes each issue's delivery as `SKILL.md` -> Authorization
describes, and nothing beyond it.

## Step 2 - one fresh worker per issue, in order

Determine the delivery mode once (`SKILL.md` -> Delivery mode).

**pr-flow.** Spawn one fresh subagent per issue, in its own worktree (Claude
Code: the Agent tool with `isolation: "worktree"`; elsewhere `git worktree add`
off the freshly fetched default branch). Never a fork: a fork carries every
earlier issue's context into the next. Brief it to:

- load the rules first with `/steer-standards` - a fresh subagent sees steer's
  skills but not the rules the SessionStart hook injected here;
- run `/steer-work start #N`, then, before implementing, the plan gate in
  `modes/reviewed.md` unless the issue is Trivial (rule `80-change-class`).
  Without `--reviewed`, skip the human sign-off: revise on every high finding
  and implement, but return a plan whose high findings survive the 2-round
  cap (`REVIEW-LOOP.md` section 2) as a gate question instead. Then
  `/steer-work finish #N`, with the vetted plan and its resolved findings in
  the PR's *Notes for the reviewer*;
- keep rule 45's worktree discipline - `mise trust` only as it allows, services
  only through `mise run ...`, `mise run docker:clean` before returning;
- never ask the human: on a gate, stop and return it;
- return a card - issue, branch, PR URL or `none`, local gate result, high
  code-gate findings left open, the gate question or blocker, or `none`.

**solo-trunk.** No worktree: `main` can be checked out in only one place. Run
each worker in the main checkout, one at a time, fast-forwarded to
`origin/<default>` before it starts.

Keep only the cards here. Never pull a worker's diff or transcript into this
context; a long queue would otherwise rebuild the anchoring the fresh worker
exists to avoid.

## Step 3 - verify each card, do not trust it

- **pr-flow** - `gh pr list --head <branch> --json number,isDraft,baseRefName,url`:
  the PR exists, is a draft, and targets the default branch. Through the
  gateway, the issue is in `validate` with its PR linked.
- **solo-trunk** - the closing commit is on `origin/<default>`.
- A mismatch records the issue as blocked, with the fact that failed.
- Remove the worktree once its branch is pushed and the tree is clean: `git
  worktree remove <path>` refuses a dirty tree, so never add `--force`. A dirty
  or unpushed one stays, its path recorded.

## Step 4 - record and continue

The issues are independent branches, so one failure does not stop the next.

- **A gate question** (a `--reviewed` plan sign-off, a plan whose high
  findings would not resolve, a blocking `Proposed` ADR, a product question): ask the human now, per rule `61-gates`. Their answer
  goes back to that worker (Claude Code: `SendMessage`), else to a fresh worker
  running `resume #N` with it. `Decide later` records the issue and moves on.
- **Red gates or a blocker** after `finish`'s own bounded rounds: record it and
  move on.
- **Stop the whole queue** only on a failure that would hit every issue: tracker
  or `gh` auth, the same gate failing the same way on two issues in a row (a
  broken default branch, not a broken issue), or the human saying stop. Report
  the issues not started.

## Step 5 - report

One table, in run order: issue, outcome (`draft #n`, `set aside`, `blocked`),
and the one fact that matters - a set-aside reason, an open high finding, a
blocker. Then the next-actions block (`NEXT-ACTION.md`).
