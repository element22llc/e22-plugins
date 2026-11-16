# `/steer:work queue` - deliver a list of issues, one fresh worker each

Read this file only when `queue` is the subcommand, named or entered
automatically for an implement ask naming two or more issues (`SKILL.md` ->
Multiple issues). It is issue-scoped -
Preconditions 1 and 2 hold - but every issue is named, so step 3 has nothing to
find-or-create.

**What this owns and where it stops.** This session is the orchestrator: it
triages the list, hands each issue to a fresh worker, checks what the worker
reports, and relays the human gates. It implements nothing itself. Each issue
is delivered by the ordinary `start` -> `finish` flow, so every guarantee of
that flow holds per issue: one branch and one PR off the default branch,
the local gates, the code gate. A worker's `finish` opens its PR ready when its
code gate came back clean, a draft otherwise. **The orchestrator never merges
and never readies a PR** - the run ends at open PRs.

`queue #A #B ... [--reviewed]` runs the issues in the order given. Every
non-Trivial issue gets the independent plan gate by default: nobody watches
each issue start, so a misread issue would otherwise cost a full
implementation and code gate before anyone saw it. `--reviewed` adds the human
plan sign-off on top, issue by issue. `--hotfix` is refused: an incident is one
issue, `/steer:work --hotfix #N`. A list of one is `start #N`.

## Step 1 - triage from metadata, before any worker

Read each issue through `/steer:tracker-sync`. Set aside, with its one reason,
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
Code: the Agent tool with `subagent_type: "general-purpose"` and `isolation:
"worktree"`; elsewhere `git worktree add` off the freshly fetched default
branch). Never a fork: a fork carries every
earlier issue's context into the next. Brief it to:

- load the rules first with `/steer:standards` - a fresh subagent sees steer's
  skills but not the rules the SessionStart hook injected here;
- run `/steer:work start #N`, then, before implementing, the plan gate in
  `modes/reviewed.md` unless the issue is Trivial (rule `80-change-class`).
  Without `--reviewed`, skip the human sign-off: revise on every high finding
  and implement, but return a plan whose high findings survive the
  bounded exit (`REVIEW-LOOP.md` section 2) as a gate question instead. Then
  `/steer:work finish #N`, with the vetted plan and its resolved findings in
  the PR's *Notes for the reviewer*;
- keep rule 45's worktree discipline - `mise trust` only as it allows, services
  only through `mise run ...`, `mise run docker:clean` before returning;
- never ask the human: on a gate, stop and return it;
- work to a budget of about **200 tool calls**: past it, stop instead of
  pressing on in a long context. Commit the work in progress so the tree ends
  clean, push it as a draft PR (a WIP checkpoint, `subcommands.md` -> `finish`),
  and return a **partial** card. In solo-trunk, commit nothing: leave the work
  in the main checkout for the worker that resumes it;
- return a card - issue, branch, PR URL or `none`, draft or ready, local gate
  result, high code-gate findings left open, the gate question or blocker, or
  `none`; a partial card says what is done and what is left.

**solo-trunk.** No worktree: `main` can be checked out in only one place. Run
each worker in the main checkout, one at a time, fast-forwarded to
`origin/<default>` before it starts.

**Orca workspaces, only when the dev asks (pr-flow).** The default stays the
subagent, which Orca's own guidance also prefers unless the dev wants to watch
each issue or use another agent. On request, give each issue a visible Orca
workspace with its setup run, instead of a subagent:

```sh
git fetch origin <default>
orca worktree create --name issue-<n> --base-branch origin/<default> \
  --branch issue/<n>-<slug> --reference <issue-url> --setup run \
  --agent claude --prompt "/steer:work #<n>" --json
```

Add `--reviewed` to the prompt when the queue has it. The default plan gate is
not added: it stands in for nobody watching each start, and here the dev does.
Launch them all; they run in parallel. Each is a top-level session: it loads
the rules itself, and its gates and questions are asked in its own workspace,
where the dev answers them. No card comes back, so the budget, partial cards
and Step 4's relay do not apply: Step 3 verifies each issue, its branch and PR
read from the tracker, when the dev returns to this session. The workspaces are
the dev's to remove in Orca, which runs the `orca.yaml` archive hook; never
remove one from here.

Keep only the cards here. Never pull a worker's diff or transcript into this
context; a long queue would otherwise rebuild the anchoring the fresh worker
exists to avoid.

## Step 3 - verify each card, do not trust it

- **pr-flow** - `gh pr list --head <branch> --json number,isDraft,baseRefName,url`:
  the PR exists and targets the default branch; a ready one (`isDraft`
  false) also has its checks green and none skipped (`gh pr checks <n>`). Through the
  gateway, the issue is in `validate` with its PR linked.
- **solo-trunk** - the closing commit is on `origin/<default>`.
- **A partial card** - pr-flow: its PR is a draft by design; verify it exists
  and the worktree is clean. Solo-trunk: nothing to verify yet.
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
- **A partial card** (the worker reached its budget): hand what is left to a
  fresh worker with the same Step 2 brief, running `resume #N` instead of
  `start` - in solo-trunk, next, before any other issue. A second partial on
  the same issue is recorded like any blocker: the issue is bigger than one
  worker, and wants `/steer:work issues decompose`.
- **Red gates or a blocker** after `finish`'s own bounded rounds: record it and
  move on.
- **Stop the whole queue** only on a failure that would hit every issue: tracker
  or `gh` auth, the same gate failing the same way on two issues in a row (a
  broken default branch, not a broken issue), or the human saying stop. Report
  the issues not started.

## Step 5 - report

One table, in run order: issue, outcome (`ready #n`, `draft #n`, `set aside`, `blocked`),
and the one fact that matters - a set-aside reason, an open high finding, a
blocker. Then the next-actions block (`NEXT-ACTION.md`).
