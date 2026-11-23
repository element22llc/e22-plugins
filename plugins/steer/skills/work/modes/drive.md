# `/steer:work drive` - one autonomous cycle over PRs, reviews and issues

Read this file only when `drive` is the subcommand. It is the orchestrator for
running steer without a prompt per step: one **cycle** finishes your open PRs,
reviews the PRs waiting on you, and hands the next ready issues to fresh
workers. The repetition belongs to the harness, not to this file (Repeat the
cycle, below).

**What this owns and where it stops.** This session triages, dispatches,
verifies cards and reports. It implements nothing itself; every change is made
by a fresh worker running the ordinary `resume` or `start` -> `finish` flow,
with every guarantee of that flow. It **never** merges, approves, posts a review,
deploys, pushes to the default or a protected branch, ratifies an ADR, creates
an issue, or touches real secrets - in any run, attended or not.

`drive [--max N] [--label <name>]` - `--max` caps new issues per cycle (default
3); `--label` narrows issue pickup to that label. `--reviewed` carries into each
worker as in `queue`; `--hotfix` is refused.

## Preconditions

- **PR flow only.** In a solo-trunk repo, refuse: unattended delivery straight
  to `main` has no gate (rule 45). Recommend `/steer:setup protect`. On a
  declared but unprotected `main`, say so once and recommend it too.
- **Tracker** - Preconditions 1-2 of `SKILL.md` hold; step 3 does not: `drive`
  finds work, it never creates an issue. A worker that discovers separate work
  returns it on its card instead of filing it; the report lists it for the human.
- **Unattended runs need the opt-in.** A run nobody watches - started by
  `/loop` or a cloud scheduled task, or one the dev says they will leave - runs
  only where `policy/automation.yml` declares `loops: true`. Where it does not,
  put the decision to the dev first: unattended spend on every cycle, PRs nobody
  watched being opened, and the PR flow above. On a yes, write the marker
  (create the file if absent, leave other keys alone) and a `/spec/history/`
  entry naming the decider and date, on a branch with its PR. **Merging that PR
  arms the loop** - until it merges, run attended only, as with no yes at all.
  The marker is what loads rule `53-autonomous-loops`.

**What the invocation authorizes.** Running `drive` is the implement request
for every issue it selects in Step 3, and for the review fixes in Step 1 - each
as `SKILL.md` -> Authorization describes, nothing beyond it.

## Step 0 - read state from metadata, spawn nothing yet

Three reads, nothing else:

```sh
gh pr list --author @me --state open --json number,title,isDraft,headRefName,headRefOid,reviewDecision,reviews,mergeable,statusCheckRollup,url
gh pr list --search "is:open review-requested:@me" --json number,title,isDraft,headRefOid,url
```

and, through `/steer:tracker-sync find`, the open issues in `ready-for-dev`
(with `--label`, only that label). A cycle whose three reads show nothing
actionable (below) spawns no subagent and reports idle.

## Step 1 - your open PRs first

Finishing work in flight comes before starting more. A PR of yours is
**actionable** when CI is red, it is `CONFLICTING`, or it has a review
requesting changes left on its current head - a `reviews` entry in state
`CHANGES_REQUESTED` whose `commit.oid` is the `headRefOid`, so nothing has been
pushed since (`latestReviews` leaves `commit.oid` empty; read `reviews`). A draft with nothing failing is the author's to ready, not this
cycle's - in an attended run, ask its unanswered reviewer notes as `review
--mine` does. **Skip, and report:**

- a PR whose branch is checked out in another worktree (`git worktree list`) -
  another session holds it (`SKILL.md` -> Concurrency & claims);
- a PR a worker already tried at its current head: this session sent one, or
  the issue's managed block records `drive: stuck at <sha>`. A head that has
  not moved means another try would repeat the last one; it waits for a human.

For each actionable PR whose branch names its issue (`issue/<n>-...` or a
`Closes #N` in the body), spawn one fresh worker as `queue` Step 2 describes,
running `/steer:work resume #N` in a worktree on the PR's branch, with this
addition to its brief: read the feedback with `gh pr view <n> --json
reviews,comments` and the inline threads (`gh api
repos/{owner}/{repo}/pulls/<n>/comments`; where that read is refused, work from
the reviews and say so), address each point or answer why not, push once to the
same branch when every point is done, then post one `gh pr comment` listing
each point and what changed, and re-request review from whoever asked for changes (`gh pr edit <n>
--add-reviewer <login>`). It never resolves a thread, dismisses a review or
force-pushes. On a ready PR, a worker that stops short on its budget pushes
only commits whose local gates are green, once, never a WIP checkpoint, and its
comment lists the points still open. A worker that pushes nothing records `drive: stuck at <sha>` and
its one reason in the issue's managed block. A PR with no issue link is
reported, not worked.

## Step 2 - PRs waiting on your review

**Attended:** run `modes/review.md` Steps 1-3 for the queue (one
`steer-pr-reviewer` per PR, the refute pass). **Skip any PR this session already
holds a card for at its current head SHA** - a repeated cycle must not re-review
unchanged work. Hold the cards for the report: nothing is approved, commented or
requested here. The human acts on them with `/steer:work review`.

**Unattended:** spawn no reviewer. List the queue - number, title, head SHA -
and stop; cards held by nobody would be paid for again on every run
(`modes/review.md`).

## Step 3 - new issues, up to `--max`

From Step 0's issues, drop any claimed or assigned to someone else, any whose
branch or PR already exists, and apply `queue` Step 1's set-asides (not ready
for its kind, High-risk without recorded scope, dependent on another selected
issue). Order the rest by the composite sort key in `NEXT-ACTIONS.md`, from
what `find` returns: delivery reads core ops only, so Priority, blocked-by and
milestone rank as unset and lifecycle depth, age and number decide. Take the
first `--max`, minus the workers Step 1 already started. Run them as
`queue` Steps 2-4, with one change: **a worker in an unattended run always
opens a draft** (rule 53).

## Step 4 - verify and report

Verify every card as `queue` Step 3 does. A gate question goes to the human now
when present (rule `61-gates`), and a draft's reviewer notes are asked as
`queue` Step 4 does; otherwise it is recorded and the issue left claimed and
waiting. Stop the cycle on `queue`'s whole-run stop conditions.

Report one table - item, what happened (`fixed #n`, `ready #n`, `draft #n`,
`carded`, `set aside`, `blocked`), the one fact that matters - then the review
cards' buckets, then everything waiting on a human: merges, approvals, gate
questions, set-aside scoping. **End with exactly one status line**, the line a
stop check reads:

- `Drive: idle` - this cycle started no worker, and every remaining item waits
  on a human or on CI (carding the review queue does not count as work: the
  cards wait on the human);
- `Drive: work remains` - a worker ran, or an actionable item was left for the
  next cycle (`--max`, a partial card).

## Repeat the cycle

`drive` is one pass; the harness repeats it. In Claude Code:

- **Drain now** - `/goal run /steer:work drive until a report ends with
  "Drive: idle", or after 10 cycles`. Setting the goal starts the first turn.
  The goal's evaluator reads only the conversation, which is why the status
  line is exact; the cycle cap stops a backlog that keeps refilling. Gates
  waiting on the human do not keep it running: they count toward idle.
- **Keep watching while the session stays open** - `/loop /steer:work drive`
  (self-paced) picks up new reviews and CI results between cycles. It stops when
  the session exits, and it is an unattended run (the opt-in above).
- **On a schedule, under Orca** - an Orca automation (Under Orca, below). It
  runs your local Claude with your plugins, so steer loads.
- **On a schedule, in the cloud** - a cloud scheduled task (`/schedule`) with the prompt
  `/steer:work drive`, created by the dev, never on their behalf. A cloud
  session loads steer only where the org delivers it through server-managed
  settings; without that the run has no steer skills, so do not offer it.
  It pushes with the dev's identity: require `/steer:setup protect apply` with
  admins enforced first.

Elsewhere (Copilot, Codex), run `drive` again by hand; the cycle is the same.

## Under Orca

Only when the session runs under Orca (`ORCA_WORKTREE_ID` set, `orca` on the
PATH), and only for what the dev asks for. Subagents stay the default: Orca's
own guidance prefers them unless a worker needs its own visible workspace.

**Visible workers.** On request, each Step 1 and Step 3 worker becomes an Orca
worker the dev can watch and talk to. Read `orca skills get orchestration` once,
then per item:

```sh
orca orchestration worker-start --agent claude --task-title "#<n> <title>" \
  --worktree new-top-level --repo path:<repo-root> --name issue-<n> \
  --base-branch origin/<default> --spec-file <brief>
```

A Step 1 PR whose branch already has an Orca workspace (`orca worktree list
--json`) takes `--worktree branch:<branch>` instead, unless an agent is working
there - then skip it as before. The brief is the subagent's, with three changes:
the worker is a top-level session, so its rules arrive on their own; it asks a
gate question with `orca orchestration ask` instead of returning it; and it
reports its card with `worker_done`. Start every worker, then **end the turn**:
Orca wakes this session per question and per `worker_done`. Answer a question
only when the answer follows from the issue, else ask the dev (rule `61-gates`).
Verify the cards (Step 4) once all have settled. The workspaces are the dev's to
remove in Orca. **Not under `/goal`:** the goal would resume the session before
Orca wakes it - repeat the cycle with an automation or by hand.

**An automation as the schedule.** Once the opt-in PR has merged, and on the
dev's explicit yes to the exact command shown first - creating it arms the loop:

```sh
orca automations create --name "steer drive" --provider claude \
  --trigger weekdays --time 09:00 --prompt "/steer:work drive" \
  --workspace <a workspace kept on the default branch> --fresh-session
```

Confirm the cadence with the dev; keep it modest. Runs fire only while Orca is
running, and every run is unattended: drafts only, no reviewers. Record the
automation in the opt-in's `/spec/history/` entry; `orca automations remove`
disarms it.

Then the next-actions block (`NEXT-ACTION.md`).
