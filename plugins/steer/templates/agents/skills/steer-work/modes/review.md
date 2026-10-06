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
  number,title,author,isDraft,baseRefName,headRefName,headRefOid,additions,deletions,files,mergeable,reviewDecision,statusCheckRollup,url
```

`--mine` swaps the search for `--author @me`; explicit numbers take `gh pr view
<n> --json` with the same fields. Record each `headRefOid` - Step 4 approves
that exact commit and nothing pushed after it. Empty queue -> say so and stop.

## Step 2 - triage from metadata, before reading any diff

Compute per PR, from Step 1's JSON alone:

- **CI** - green, running, red, or none, from `statusCheckRollup`. A draft's
  skipped checks are not green (`NEXT-ACTION.md`).
- **Mergeable** - `CONFLICTING` is a blocker for the author, not a review
  finding.
- **Stacked** - `baseRefName` is another work branch (rule 45). Order a stack
  bottom-up; a PR can merge only after the one below it. A `batch/*` base is
  not a stack: its PRs are siblings and merge in any order.
- **Risk class** - High-risk when any path touches a rule `60-high-risk` area
  (auth, permissions, migrations, `/infra`, secrets, deletion, billing,
  CI/deploy workflows); otherwise leave the class to Step 3.

A **draft, red or conflicting PR is not reviewed** - it goes straight to the
`Blocked` bucket with its one blocking fact, and costs no subagent.

## Step 3 - one reviewer per PR, in parallel

For every remaining PR, spawn a **fresh read-only subagent** in the same message
(waves of up to 10), each with one PR - not `steer-reviewer`, which audits
on-disk code. Give it the PR number, `gh pr view <n>` and `gh pr diff <n>` to
read, and the rubric: rule `50-done` (Definition of Done and the drift classes),
rule `40-testing`, and rule `80-change-class`. Ask it to return a **card**, at
most 8 lines:

- one line on what the PR does, in the reader's terms;
- class: Trivial, Behavioral or High-risk (the heavier when arguable);
- tests present for the changed behavior, and `contract.md` updated where
  behavior changed - yes / no / n/a;
- every drift flag checked in the PR body, and any it should have checked;
- findings with `path:line`, severity-ranked, or `none`;
- a suggested verdict: `approve`, `changes` or `look`.

The cards are input to the human's call, not the call. Read them; drop a
finding you cannot reproduce from the diff.

## Step 4 - one decision, then one command

Sort every PR into a bucket and print them in this order, one line per PR
(`#n title - class - one-line reason`, plus `stacked on #m` where it is):

| Bucket | Holds | Batch-approvable |
|---|---|---|
| **Ready** | CI green, Trivial or Behavioral, tests + contract in place, no findings, no drift flag | yes |
| **Changes** | findings a reviewer would block on | no - post as a review |
| **Look** | High-risk, or any checked drift flag | no - line-by-line review |
| **Blocked** | draft, red CI, conflicting | no - the author's move |

**`Look` never batch-approves.** A High-risk change or a flagged drift class
needs line-by-line review and an explicit resolution (rule `50-done` § Drift
gates); offer to walk the human through each one after the batch.

Then ask **once**, in plain text - a picker caps out at four options: reply
with the `Ready` numbers to approve, `ready` for every one listed, and the
`Changes` numbers to post findings on. Nothing is pre-selected. Silence, "ok",
"looks good" or a number outside the printed list approves nothing.

Run the approvals as **one** command, so the harness asks once for the whole
batch, and skip any PR pushed to since its card was built:

```sh
for pr in "12 <sha12>" "15 <sha15>"; do
  set -- $pr
  [ "$(gh pr view "$1" --json headRefOid -q .headRefOid)" = "$2" ] \
    && gh pr review "$1" --approve --body "Approved in a /steer-work review batch." \
    || echo "#$1 changed since review - skipped"
done
```

Selected `Changes` PRs get `gh pr review <n> --request-changes --body-file
<card>` the same way, the body being the card's findings with paths.

## Step 5 - `--mine`: make each PR reviewable

Nothing here approves. Per PR, name the one move that unblocks it and do the
ones that are yours:

- **Draft, work complete** - `gh pr ready <n>`, then watch CI; a draft's
  skipped checks never counted as green.
- **CI red or conflicting** - `/steer-work resume #<issue>` fixes it on its
  branch.
- **Stacked, independent** - rebase onto the default branch and retarget
  (`gh pr edit <n> --base <default>`), one PR per run; the force push asks.
- **No reviewer requested** - ask the human who, then `gh pr edit <n>
  --add-reviewer <login>`. Never pick a reviewer yourself.

## Recommend the next action

Per `NEXT-ACTIONS.md`, from where the batch stopped:

| Observed state | Category | Action |
|---|---|---|
| Approved PRs now mergeable | Human decision required | The human merges them (no command) |
| `Look` PRs remain | Human decision required | Review each line by line - `/steer-work review #<n>` |
| `Blocked` or `--mine` items remain | Blocking now | The one move Step 5 named for the oldest |
| Queue empty | Complete | `No action is currently required.` |
