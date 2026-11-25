# `/steer-work review` - clear the PR review queue in one batch

Read this file only when `review` is the subcommand. Like `promote` it is **not
issue-scoped**: the unit is the review queue, so it reads no tracker and
finds-or-creates no issue (Preconditions 0b).

**What this owns and where it stops.** It does the reading a reviewer would
otherwise do PR by PR, then carries out the human's decision in one pass. **The
decision is the human's**: an approval is posted only for a PR the human picked
from the list in this session, never on your own verdict, and never in an
unattended run - a loop has nobody to pick, so it reports the queue and stops
(rule `53-autonomous-loops`). **Merge stays human** - never `gh pr merge`, never
`--auto`.

Two queues, chosen by argument:

- **`review [#PR ...]`** (default) - PRs awaiting **your** review:
  `review-requested:@me`, or the PR numbers given. You can approve these.
- **`review --mine`** - **your own** open PRs. GitHub blocks an author's
  approval, so this queue gets readiness work only (Step 5), never Step 4.

## Step 1 - collect the queue in one call

```sh
gh pr list --search "is:open review-requested:@me" --limit 100 --json \
  number,title,author,isDraft,baseRefName,headRefName,headRefOid,additions,deletions,files,mergeable,reviewDecision,reviewRequests,reviews,statusCheckRollup,url
```

`--mine` swaps the search for `--author @me`; explicit numbers take `gh pr view
<n> --json` with the same fields. Record each `headRefOid` - Step 4 approves
that exact commit and nothing pushed after it. Read your login once (`gh api
user -q .login`) for Step 3's recall. A PR showing 100 `reviews` may hold more:
read its full list with `gh api repos/{owner}/{repo}/pulls/<n>/reviews
--paginate`, where the commit is `commit_id` and the login `user.login`.

Before anything else stops the run, prune: a stored card (Step 3) whose PR is
outside this queue is deleted when `gh pr view <n> --json state -q .state`
says `CLOSED` or `MERGED`. Then, empty queue -> say so and stop.

## Step 2 - triage from metadata, before reading any diff

Compute per PR, from Step 1's JSON (plus one stack lookup for a stacked PR):

- **CI** - green, running, red, or none, from `statusCheckRollup`. A draft's
  skipped checks are not green (`NEXT-ACTION.md`).
- **Mergeable** - `CONFLICTING` is a blocker for the author, not a review
  finding.
- **Stacked** - `baseRefName` is another work branch (rule 45). Order a stack
  bottom-up; a PR can merge only after the one below it. A `batch/*` base is
  not a stack: its PRs are siblings and merge in any order. When one is
  stacked, check once for a **native** stack (`gh api
  'repos/{owner}/{repo}/stacks?pull_request=<n>'`, `[]` when not): merging a
  PR merges every PR below it, so judge its readiness across the stack
  (`/steer-reference stacks`).
- **Risk class** - High-risk when any path touches a rule `60-high-risk` area
  (auth, permissions, migrations, `/infra`, secrets, deletion, billing,
  CI/deploy workflows); otherwise leave the class to Step 3.

A **draft, red or conflicting PR is not reviewed** - it goes straight to the
`Blocked` bucket with its one blocking fact, and costs no subagent.

## Step 3 - recall, then one reviewer per PR in parallel

**Recall first: a head already reviewed costs no reviewer, in this session or
any later one.** For each PR left after triage, the **prior review** is the
newer - the card's `built` against the review's `submittedAt` - of:

- **your card** for it - one this session holds, or a stored
  `spec/.work/reviews/<n>-<sha>.md` (below);
- **your own last posted review** - the newest `reviews` entry whose
  `author.login` is yours and whose state is `APPROVED`, `CHANGES_REQUESTED`
  or `DISMISSED`, at its `commit.oid`. Read `reviews`, never `latestReviews`,
  which leaves `commit.oid` empty. A `COMMENTED` review does not count: a
  reply in a thread posts one at whatever head is current. A `DISMISSED` one -
  stale-review dismissal turns an approval into it on the next push - anchors
  a delta, never a skip.

Then, per PR:

- **No prior review** - a full review, below.
- **Prior review at the current `headRefOid`** - spawn nothing. An `APPROVED`
  or `CHANGES_REQUESTED` review at this head puts the PR in `Reviewed` (Step 4)
  with that verdict; a card goes to Step 4 as-is, marked with the date it was
  built. A fresh look at an unchanged head happens only when the human asks to
  re-review it in so many words; naming the PR number is not that ask.
- **`DISMISSED` at the current head** - someone dismissed it by hand: a full
  review, told to read the full diff and given that review's body, without its
  SHA, to settle. Where no card is stored, this repeats each run until a new
  review is posted.
- **Head moved** - a delta. `gh api
  'repos/{owner}/{repo}/compare/<old>...<head>' -q .status` says how (the
  quotes matter: unquoted, `{` beside `...` is refused as brace expansion):
  `ahead` -> pass the reviewer the prior findings (the card, or the posted
  review's body) and the old SHA, with the delta to read in place of the full
  diff (`gh api -H "Accept: application/vnd.github.diff"
  'repos/{owner}/{repo}/compare/<old>...<head>'`); it settles each previous
  finding, reviews nothing unchanged, and skips what a merge from the base
  brought in - that is already on the base. The prior card's class and Step
  2's risk class are a floor for the delta card's class. Anything else -
  `diverged` after a force-push, a 404 for a SHA GitHub no longer has - is a
  full review, told the history was rewritten and still given the prior
  findings to settle.

For every PR still to review, spawn a fresh **`steer-pr-reviewer`** in the same
message (Claude Code: `subagent_type: "steer:steer-pr-reviewer"`; elsewhere a
fresh read-only subagent on a mid-tier model), waves of up to 10, each with one
PR - not `steer-reviewer`, which audits on-disk code. Give it the PR number,
its head SHA, `gh pr view <n>` and `gh pr diff <n>` to read, and the code-gate
rubric in
[`REVIEW-LOOP.md`](https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/reference/REVIEW-LOOP.md) section 4 - the same one
the author's `finish` ran: adversarial, with the specialist lenses the diff
triggers applied inline. Tell it to spawn no subagents of its own, so a batch
stays one reviewer per PR. The local checkout may sit at the base, not the PR
head: it serves the other-instances and peer passes, which look outside the
diff. Ask it to return a compact **card**:

- one line on what the PR does, in the reader's terms;
- class: Trivial, Behavioral or High-risk (the heavier when arguable);
- tests present for the changed behavior, and `contract.md` updated where
  behavior changed - yes / no / n/a;
- every drift flag checked in the PR body, and any it should have checked;
- findings with `path:line`, severity-ranked, or `none`;
- design questions the author should answer in the PR, or `none`;
- a suggested verdict: `approve`, `changes` or `look`.

Then run the refute pass (`REVIEW-LOOP.md` section 4): every PR whose card
from this step carries a high finding not already through a refute pass gets
one fresh `steer-pr-reviewer` verifier for all of them, the whole batch in one
message. A recalled card is never verified again. A refuted finding leaves the
card; an unsure one stays, marked unconfirmed.

**Store every new card before Step 4 asks anything** - the session can end
before the human answers, and an unposted card is otherwise lost. Write it to
`spec/.work/reviews/<n>-<head-sha>.md`, opening with `- pr: <n>`, `- head:
<sha>`, `- built: <UTC timestamp>`, then the card; delete that PR's older
cards. Store only where `git check-ignore -q spec/.work/reviews/`, run from the
repository root like every path here, succeeds - the scaffold `.gitignore`
ignores `spec/.work/`. Elsewhere store nothing: a
repo that does not ignore it would get an untracked `spec/`, and its memory is
your posted reviews alone. Ignored files are per checkout, so a card stored in
one worktree is not seen from another.

The cards are input to the human's call, not the call. Read them; drop a
finding you cannot reproduce from the diff or the checkout.

## Step 4 - one decision, then one command

Sort every PR into a bucket and print them in this order, one line per PR
(`#n title - class - one-line reason`, plus `stacked on #m` where it is):

| Bucket | Holds | Batch-approvable |
|---|---|---|
| **Ready** | CI green, Trivial or Behavioral, tests + contract in place, no findings, no drift flag | yes |
| **Changes** | findings a reviewer would block on | no - post as a review |
| **Look** | High-risk, or any checked drift flag | no - line-by-line review |
| **Reviewed** | your own `APPROVED` or `CHANGES_REQUESTED` review is already posted at the current head | no - shown with that verdict, tagged `re-requested` when your login is in `reviewRequests` (your review was requested again since) |
| **Blocked** | draft, red CI, conflicting | no - the author's move |

**`Look` never batch-approves.** A High-risk change or a flagged drift class
needs line-by-line review and an explicit resolution (rule `50-done` -> Drift
gates); after the batch, offer to go through each one.

Ask **once**, in plain text - a picker caps out at four options: reply
with the `Ready` numbers to approve, `ready` for every one listed, and the
`Changes` numbers to post findings on. Nothing is pre-selected. Silence, "ok",
"looks good" or a number outside the printed list approves nothing.

Run the approvals as **one** command, so the harness asks once for the whole
batch, and skip any PR pushed to since its card was built:

```sh
printf '%s %s\n' 12 "<sha12>" 15 "<sha15>" | while read -r n sha; do
  head=$(gh pr view "$n" --json headRefOid -q .headRefOid) \
    || { echo "#$n lookup failed - skipped"; continue; }
  [ "$head" = "$sha" ] || { echo "#$n changed since review - skipped"; continue; }
  gh pr review "$n" --approve --body "Approved in a /steer-work review batch." \
    || echo "#$n approve failed"
done
```

Feed the pairs through `read`, never `set -- $pr`: zsh - the macOS default
shell - does not word-split an unquoted parameter, so `$2` comes back empty and
every PR is reported as changed, approving nothing.

Selected `Changes` PRs get `gh pr review <n> --request-changes --body-file
<file>` the same way, the body being the card's findings with paths - never
the stored card file, whose header lines are not for the author.

**Then the `Look` PRs, one at a time. Line-by-line is how the reviewer reads,
not how you report.** Each `Look` PR gets one message: its full card, findings
ranked across every file, design questions, and a suggested verdict. Then ask
for one decision on the whole PR: approve, request changes, or post the
questions. Never split one PR into parts or wait for "next" between files; go
deeper on one finding only when the human asks.

## Step 5 - `--mine`: make each PR reviewable

Nothing here approves. Per PR, name the one move that unblocks it and do the
ones that are yours:

- **Draft, work complete** - `--mine` is the author asking to ready their own
  PRs, so here `gh pr ready <n>` is theirs: first ask any reviewer note left
  unanswered in it, as `finish` does (`subcommands.md` -> Ask the author), then
  run it and watch CI; a draft's skipped checks never counted as green. A note
  answered `Decide later` keeps that PR a draft.
- **CI red or conflicting** - `/steer-work resume #<issue>` fixes it on its
  branch.
- **Stacked, independent** - rebase onto the default branch and retarget
  (`gh pr edit <n> --base <default>`), one PR per run. Force-push as `git push
  --force-with-lease origin <branch>`: the flag ahead of `origin` keeps it out
  of this skill's `git push origin *` grant, so it asks. A **native** stack is
  not retargeted: report it to the human, since leaving one is a restructuring
  (`gh stack modify` or unstacking).
- **No reviewer requested** - ask the human who, then `gh pr edit <n>
  --add-reviewer <login>`. Never pick a reviewer yourself.

## Recommend the next action

Per `NEXT-ACTIONS.md`, from where the batch stopped:

| Observed state | Category | Action |
|---|---|---|
| Approved PRs now mergeable | Human decision required | The human merges them (no command) |
| `Look` PRs remain | Human decision required | Review each line by line - `/steer-work review #<n>` |
| `Blocked` or `--mine` items remain | Blocking now | The one move Step 5 named for the oldest |
| A `re-requested` `Reviewed` PR remains | Human decision required | Read the replies since your review, then ask for a re-review of it in so many words - `/steer-work review #<n>` |
| Only untagged `Reviewed` PRs remain | Human decision required | Their authors act on your posted reviews (no command) |
| Queue empty | Complete | `No action is currently required.` |
