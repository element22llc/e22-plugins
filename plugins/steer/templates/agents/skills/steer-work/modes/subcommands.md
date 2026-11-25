# `/steer-work` - the four subcommands in full

Read this file before executing a subcommand. The guardrails, preconditions,
authorization scope, delivery mode, closing-ref rule, completion semantics,
branch naming, concurrency rules, and the recommended-next-actions block stay in
`SKILL.md` and govern all four.

## Subcommands (distinct, idempotent)

- **`start #N`** - resolve + validate the issue (actionable? readiness met for
  its kind per `ISSUE-WORKFLOW.md`?); detect a conflicting claim or branch;
  **claim** it (`claim` - self-assign the invoking GitHub user + set
  `steer:claimed-by` - then `update-state` -> `in-progress`);
  **(pr-flow)** create or reuse the branch - a new one **from the freshly
  fetched default branch** (`git fetch origin <default>`, then
  `git switch -c <branch> origin/<default>`), never from whatever is checked
  out: a branch cut from another work branch silently stacks on it. Base it on
  another work branch only when this issue needs that PR's unmerged code; then
  open the PR with `--base <that branch>` and name the dependency in its
  description. When the dev batches fixes into one merge, branch from the
  default branch as usual and open the PR with `--base batch/<slug>` - a
  sibling, not a stack - and **write the local work marker**
  `spec/.work/<branch>.md` (slashes -> underscores) in the format `WORK-MARKER.md`
  defines (section "Marker format"), so
  the end-of-turn Stop-hook reconciliation recognizes the branch as
  issue-governed - **in solo-trunk, skip both: stay on `main`, no marker**;
  **(pr-flow) a new branch for work an open PR of yours already carries** -
  one you authored whose head is an `issue/<N>-` branch or that closes #N
  (`gh pr list --author @me --state open --json
  number,headRefName,closingIssuesReferences,url`), other than the PR this
  branch stacks on or a `batch/` PR - leaves that PR to rot: reusing its branch
  stays the default, and when you cut a new one anyway, propose closing it with
  a comment pointing at the new branch (and its PR once open); close it (`gh pr
  close <n> --comment "<pointer>"`) only on a yes, and in a `queue` or
  `drive` worker or an unattended run, report it on the card instead;
  prune the markers of closed issues (`WORK-MARKER.md` -> Removal); under
  Orca, link the issue to the workspace (Orca workspace links, below); load
  linked specs (`steer:spec-path`, acceptance criteria); **pick up the
  questions this slice settles** - each open `impact: non-blocking` question in
  the feature's `## Open questions` gated at `required_before: implementation`
  is a decision the build makes: build the option it names (else the simplest)
  and keep the list for `finish` (a *blocking* one already fails readiness,
  above); **check prior
  learnings** - grep `spec/learnings/*.md` frontmatter (`area:`, `symptoms:`,
  `applies_when:`) for terms from the issue and the paths you expect to touch,
  and read only the files that match (no directory, nothing to do);
  **classify the change** (rule `80-change-class`, the heavier class when
  arguable) - High-risk runs the plan gate in [`reviewed.md`](reviewed.md)
  even without `--reviewed`; begin implementation - a defect through
  [`debug.md`](debug.md), cause before fix.

  **A lagging scaffold - checked after the readiness check, before the claim
  and any branch.** When the issue, as written, touches rule `60-high-risk`'s
  *Deployment & release logic* or *Infrastructure*, or the delivery files steer
  ships (`compose.yaml`, `mise.toml` tasks, a `Dockerfile`,
  `policy/delivery.yml`), Read `spec/.version` and
  `https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/.claude-plugin/plugin.json`. The repo lags when its
  stamp is an older major, or the same major and a minor one or more lower.
  Then say so, naming both versions - the current scaffold may already ship
  what the issue asks for - and offer `/steer-setup sync` first. On a yes, stop
  `start` here and run the sync on the default branch, fast-forwarded
  (`git switch <default>`, `git pull --ff-only`) - never a detached
  `origin/<default>`, since sync takes its PR base from the checked-out branch
  name - then re-run `start #N` once that PR merges. Declined, under
  `--hotfix`, or with nobody to ask (a `queue` or `drive` worker): continue and
  note the lag under the PR's *Notes for the reviewer* (in solo-trunk, the
  trunk commit body). No stamp (an `openspec` or unmanaged repo): skip.
- **`resume #N`** - reconstruct context from the issue + recorded `steer:branch` /
  `steer:pull-request` + working tree; reconcile stale markers (e.g. a recorded
  branch that no longer exists, a PR that merged/closed while away) and prune
  the markers of closed issues (`WORK-MARKER.md` -> Removal). **If the
  marker's session list (`WORK-MARKER.md` -> Claude Code sessions) has a head
  session different from the current
  one, surface it as a context source** - offer `claude --resume <id>` to re-enter
  that conversation, and (if present) the transcript located by globbing
  `"$CLAUDE_CONFIG_DIR"/projects/*/<id>.jsonl`. Treat it as a best-effort
  breadcrumb, never authority: the session may be gone or on another machine, so
  fall back cleanly to reconstruction from the issue + tree. Then record the
  current session at the head of the list. Continue from the actual lifecycle
  state.
- **`status #N`** - **read-only**: report state, claimant, branch, PR, blockers,
  spec readiness, outstanding validation, and any marker a closed issue still
  holds. Mutates nothing.
- **`finish #N`** - run the required validation **locally, before any push**:
  the fullest gate `mise tasks` lists (`mise run ci`, else `mise run check`,
  else the repo's lint, typecheck and test tasks), fixed until green. **CI is
  the confirming run, not the iteration loop** - every push to a ready PR re-runs
  the whole pipeline on billed runner minutes, so a fix you could have found
  locally costs a full CI run. **On a ready PR or a trunk push, push once per
  round, not per commit**: a round is the work one message from the dev or one
  review asks for (a red build: below) - each fix committed as you go, the local
  gates green, then one push at the end of that turn. Never hold commits for
  asks not yet made. A push that cannot wait for the round's end goes to a
  draft (Draft or ready, below); on a ready PR you may not move back to draft,
  push only commits whose local gates are green, once, never a WIP checkpoint.
  A PR `finish` opens is a **draft** (`gh pr
  create --draft`), which the shipped `ci.yml` does not run, unless the code
  gate comes back clean (Draft or ready, below); a push made before the local
  gates are green (a WIP checkpoint, a backup) always goes to a draft, and
  leaves the issue `in-progress`. **Then commit and run the code gate**
  before the first push, unless the change is Trivial (rule
  `80-change-class`, the heavier class when arguable; a `--hotfix` never is):
  fresh read-only reviewer subagents, never this context and not
  `steer-reviewer` (no git), read `git diff origin/<default>...HEAD` and score
  it against the code-gate rubric in
  [`REVIEW-LOOP.md`](https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/reference/REVIEW-LOOP.md) section 4,
  handing each its absolute path to Read - the
  general reviewer (a fresh general-purpose subagent on the session model,
  briefed diff-first to about 80 tool calls, `REVIEW-LOOP.md` section 6) plus
  one `steer-pr-reviewer` per specialist
  lens the diff triggers, in one message, then the refute pass on their high
  findings, its verifiers `steer-pr-reviewer` too; every reviewer and the
  refute pass report back before anything is pushed. Under Orca, only when the
  dev asks for a second opinion from another agent, and only in a top-level
  session whose checkout is the Orca workspace (never a `queue` worker, which
  cannot end its turn to be woken), add one Codex reviewer to the first round
  through Orca orchestration: read `orca skills get orchestration`, run `orca
  orchestration worker-start --worktree current --agent codex` with the
  general reviewer's brief as its `--spec`, marked read-only since it shares
  this working tree, and end the turn until Orca delivers its `worker_done`.
  It never replaces a gate reviewer; its high findings go through the same
  refute pass and count toward the round. A later
  `finish` on an open PR re-runs it on the commits since the last gate only.
  Fix every confirmed high finding, re-run the local gates, and re-review; stop
  on a round with no confirmed high finding, on one whose count did not drop
  from the round before, or after 4 rounds (`REVIEW-LOOP.md` section 2), and name
  any high finding left open, unconfirmed ones as their own list. Put each medium finding you leave, and each design
  question with the decision taken, under the PR's *Notes for the reviewer* (in
  solo-trunk, the trunk commit body), so the human confirms rather than
  discovers. A skipped gate gets one line saying why.
  **Ask the author, don't leave them a note.** When the PR's author is in the
  session - the session is attended and its `gh` user is, or on create will
  be, the PR's author (`gh pr view --json author`); never an unattended run
  (rule `53-autonomous-loops`), a `queue` or `drive` worker, or any spawned
  subagent - put each of those notes to them before the push, one question per
  note: what it is, its tradeoff, your recommended resolution first, `Decide
  later` last, none pre-selected. In solo-trunk the author is the session's
  human and the ask comes before the trunk commit; under `--hotfix` it comes
  after the push, never holding the fix. These are the author's calls on
  review notes, not rule `61-gates` ratifications. A `finish` on an open draft
  asks the notes already in its PR the same way, except those answered
  `Decide later` in this conversation. An answer that changes the code is a
  fix like any other: commit it, local gates green, then one code-gate round on
  those commits unless they are Trivial; a new note from that round is asked
  the same way once, and any further one stays for the reviewer. Record each answer under the note as decided in-session, by
  whom and when; `Decide later` leaves the note as it was. An open high finding
  or a flagged drift class is never offered for a waiver here - it stays for
  the reviewer.
  **Capture what was learned** -
  if the work turned on reasoning that is non-obvious and absent from the final
  code, tests and docs, put it on the first rung of the enforcement ladder that
  can carry it: regression test -> lint rule or hook -> `contract.md` rule ->
  product `CLAUDE.md` pattern -> `/steer-report` for a steer defect -> only then
  `spec/learnings/<slug>.md` from
  `https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/spec/learning.md`, updating a matching
  learning over adding one (`/steer-reference traceability` section 3). Writing
  nothing is the normal outcome; whatever is written ships in this delivery.
  Then update progress (`update-state` on the managed block + `comment`);
  commit, push, and open-or-update the PR (autonomous - Commit
  autonomy; merge is not yours), writing its **Spec delta** when the branch
  changes a `contract.md` (below), and listing each question `start` picked up
  as settled by this change, for its owner to confirm on the running change. An
  answer its owner gave in-session is folded now (resolved, with its
  `_Resolution:_`, per `/steer-questions` step 6); otherwise the question stays
  open and the confirmation at review is its answer. Prune the markers of closed
  issues (`WORK-MARKER.md` -> Removal). Record the PR with `link-delivery` - in
  solo-trunk the closing trunk commit is that ref - and, under Orca, link the
  issue and the PR to the workspace (Orca workspace links, below); transition
  the issue to `validate`, and **stop** - on a ready PR, once its CI is watched.
  **Draft or ready.** Open the PR ready (`gh pr create` without `--draft`), or
  ready an existing draft (`gh pr ready`), only when it holds nothing its author
  must read first, across the whole PR and not only the commits a later gate
  re-read: no round of the code gate left a high finding open, confirmed or
  not - a Trivial change, which skips the gate, qualifies; no medium finding or
  design question is left unanswered under *Notes for the reviewer* (a vetted
  plan, findings already resolved, a note its author answered in-session and a
  skipped gate's one line are record, not reading); no drift class is
  flagged; and no question awaits its owner's confirmation. Anything else
  stays a draft: its author reads it and marks it ready, which starts CI
  (`ready_for_review`) and makes that run theirs. A later `finish` that comes
  back clean readies its draft. A ready PR goes back to draft only when you
  readied it earlier in this conversation (opened it ready, or ran `gh pr
  ready` yourself - not a spawned worker's PR, and not one you cannot point to
  that step for), no review has been submitted on it since, and you must push
  before the round is done - work you cannot keep local, never the
  exploratory push for a CI-only failure (below), which needs the run: `gh pr
  ready --undo` before that push; when the round ends, push its last commits,
  then `gh pr ready` only on the conditions above, else it stays a draft for
  its author. An
  unattended run (rule `53-autonomous-loops`) always opens a draft. A PR
  `finish` opened or readied, and a push to one already ready, starts CI: watch
  that run to conclusion (`gh pr checks --watch`) - after `gh pr ready`, wait
  until `gh pr checks` lists the new run's checks as pending, since the draft's
  skipped ones show first - and treat a
  `skipped` check as a red flag, never a pass - it reads as green to `gh pr
  checks`. The first push of
  the new `issue/<n>` branch sets the upstream - `git push -u origin <branch>` -
  or it fails with `no upstream branch`; later pushes are a plain `git push`. **In solo-trunk,
  there is no PR: commit straight to `main` with a `Closes #N` trailer (see
  Closing ref if the tracker lives elsewhere) and watch
  CI on the trunk push** (`gh run watch`) the same way - the closed issue, not a
  merged PR, is the terminal evidence. On a red build - a ready PR's run, picked
  up by `resume #N`, or the trunk push -
  diagnose and fix it as part of the same unit of work ([`debug.md`](debug.md)):
  reproduce the failure locally with the task CI ran, fix everything that run reported, re-run the
  local gates green, then push **once** and re-watch - batch the fixes, never a
  push per attempt. A failure that only reproduces in CI (runner environment,
  secrets, services) is the exception that earns an exploratory push. Repeat
  until checks are green or a remaining failure is
  legitimately non-blocking (and said so). A PR-scoped failure
  is fixed or commented on the PR, **not** filed as a tracker issue - defer to the
  CI-failure triage in `ISSUE-WORKFLOW.md` (only a reproducible default-branch
  failure becomes a `source:ci` bug). **Never mark `done` merely because a PR was
  opened.** If you have stepped away, the in-turn watch blocks the turn; re-enter
  monitoring via the harness `/loop` over `gh pr checks` or a background watch -
  steer ships no background poller.
  **No authenticated `gh`?** Probe `gh auth status` before the PR step; when it
  fails, open-or-update the PR through the github MCP server:
  `list_pull_requests` (`head: <owner>:<branch>`) finds an open one,
  `create_pull_request` opens it as a draft (`draft: true`), `update_pull_request`
  edits it. With no MCP server either, print the compare URL
  (`https://github.com/<owner>/<repo>/compare/<base>...<branch>?expand=1`) for
  the human, who opens it as a draft. Say which path ran. The CI watch stays
  `gh`-only: without it, a clean gate still opens a draft, since its run could
  not be watched, and a ready PR's or trunk push's CI is reported **not
  watched**.

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent - re-running a
phase reconciles rather than duplicates. Naming two or more issues runs
`queue` instead (`SKILL.md` -> Multiple issues).

## Orca workspace links

Only when the session runs under Orca (`ORCA_WORKTREE_ID` is set) and the
`orca` CLI is on the PATH: attach the URLs to this checkout's Orca workspace,
so Orca's sidebar shows them and `orca reference find <url>` locates the agent
working on the issue.

```sh
orca reference add <issue-url> [<pr-url>] --worktree path:<git rev-parse --show-toplevel>
```

Write the top-level path out. Use `path:`, never `current`: from a worktree
nested in the checkout (a `queue` worker's), `current` resolves to the parent's
workspace and would link the issue there, while `path:` names the nested
worktree's own entry. The issue URL is the tracker's, which may be another repo's;
solo-trunk has no PR to add. A repeat add changes nothing. Best-effort: on any
failure say so in one line and carry on - it never blocks `start` or `finish`.

## Spec delta - derived, never staged

When the branch changes any `spec/features/<id>/contract.md`, fill the PR
template's `## Spec delta` section from the diff itself - there is no staged
delta file. Per changed contract, compare the `### R-NNN` headings and blocks on
the base (`git show <base>:<path>`) against the branch:

- **Added** - an ID only the branch has.
- **Modified** - an ID on both sides whose heading or block changed (a dropped
  `(derived ...)` marker counts: confirming as-built behavior is a change).
- **Removed** - an ID only the base has. Each one needs a `Reason:` line (why the
  behavior goes) and a `Migration:` line (what callers or users do instead, or
  `none` and why) - ask the dev rather than invent either.

Write one line per ID, `R-003 - <short name>`. An edit to plain unnumbered
bullets is listed as `Unnumbered rules changed` - never mint IDs to describe
it. In solo-trunk there is no PR body; put the same block in the trunk commit
body. When updating an open PR, recompute the block from the current diff
rather than appending to it.
