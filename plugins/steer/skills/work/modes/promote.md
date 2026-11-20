# `/steer:work promote` - open the production release PR

Read this file only when `promote` is the subcommand. It is **not
issue-scoped**: the thing being delivered is
everything already merged to the default branch, which is why the skill's
Preconditions step 0b exempts it from the tracker read and the issue
find-or-create.

**What this owns and where it stops.** It cuts the release branch, changelog
included, and opens the Release PR - **one PR per release**. **Merging it is
the production gate and stays human** (rule `45-delivery` -> Deployment &
environments) - never `gh pr merge` here, never deploy, never push to `prod`.

**Who runs it.** A dev or the PO: it opens a PR and changes no code. With a PO,
speak plainly and drive git and `gh` yourself; the merge still goes to its
approvers.

**The shape.** The Release PR comes from a `release/vX.Y.Z` snapshot of the
default branch, never from `main` itself, so prod receives exactly what QA
tested while `main` keeps taking merges. The changelog cut is a commit on that
branch, not a PR into `main`: it reaches `main` with everything else when prod
is merged back (`.github/workflows/merge-back.yml`), as a hotfix's cut does.
While the Release PR is open, the held environment (`policy/delivery.yml`
`release_hold`, default `non-prod`) runs the release branch instead of `main`,
and QA fixes land on the release branch.

## Step 1 - read the declared gate

```sh
sed -n 's/^production_gate:[[:space:]]*//p' policy/delivery.yml
```

Absent file or value -> `prod-branch-pr` (the org default), and say you assumed
it. Then:

| `production_gate` | What `promote` does |
|---|---|
| `prod-branch-pr` | The whole procedure below. |
| `github-environment` | **Stop.** The gate is a deployment-environment reviewer, not a PR - there is nothing here to open. Say which environment protects prod if the repo declares one, and that approving a deployment is the human's own action. |
| `manual` | **Stop.** Say what is unreleased (Step 3) so the human knows what they are about to ship, and name the deploy command only if the repo documents one. |
| `none` | **Stop.** This repo declares no production to promote to. If that is wrong, the fix is one line in `policy/delivery.yml`, not a flag here. |

## Step 2 - preconditions

- **The `prod` branch exists.** `gh api repos/{owner}/{repo}/branches/prod` -
  `404` means the branch-based gate was declared but never adopted. Stop and say
  so: create it (`git branch prod main && git push -u origin prod`) and run
  `/steer:setup protect`, which is what makes the merge an approval rather than a
  formality. Do not create it yourself - an unprotected `prod` is a gate that
  looks real and is not.
- **`prod` is protected.** If `/steer:setup protect verify` shows no
  required review on `prod`, say the Release PR would merge without an
  approval, and recommend `/steer:setup protect` before continuing. Offer to
  continue anyway only if a dev says so - it is the production gate, so a PO
  running `promote` asks one; record who did.
- **One release at a time.** `gh pr list --base prod --state open --json
  number,headRefName,url`:
  - a `release/*` head -> that release is **in QA**. Refresh its body (Step 4's
    body, its commit list from the release branch) and run the drop check
    below against it, report it, and **stop** - no new cut, no second
    snapshot. `main` still lists the fragments this release consumed until its
    merge-back lands; only the ones merged since the snapshot are the next
    release's.
  - a `main` head -> **stop** and ask to close it
    before a snapshot replaces it; close it (`gh pr close`) only on a yes.
- **Prod is merged back.** Every merge into `prod` is merged back into `main`
  (and into a release in QA) by a merge-back PR; a release cut before that lands
  would ship without a hotfix or a QA fix, and would cut the last release's
  entries a second time:

  ```sh
  git fetch origin main prod
  git merge-base --is-ancestor origin/prod origin/main || git log --oneline origin/main..origin/prod
  ```

  For a release already in QA, check its branch instead of `origin/main`.
  Any output -> stop: name the open `merge-back/*` PR for a dev to merge with
  **Create a merge commit**. None open -> push one at prod's tip
  (`git push origin origin/prod:refs/heads/merge-back/<short-sha>-to-main`)
  and open its PR into `main`. The required `ci` check runs the same test
  (`ci:promotion`) on the Release PR.
- **No release was left behind.** With no Release PR open, a `release/*`
  branch on origin that `origin/prod` does not contain is an abandoned release
  (its PR was closed unmerged), and its cut never reached the default branch.
  One that was squashed into `prod` is listed too - say so, a dev deletes it:

  ```sh
  git fetch --prune origin 'refs/heads/release/*:refs/remotes/origin/release/*'
  git branch -r --no-merged origin/prod --list 'origin/release/*'
  ```

  One that contains `origin/main` (`git merge-base --is-ancestor origin/main
  <branch>`) is still the release: open the Release PR from it (Step 4's body)
  and stop. Otherwise **stop** and report it: the default branch has moved on,
  and the branch may hold QA fixes that exist nowhere else, so what becomes of
  it is a dev's call - **never force-push or delete it**, and never cut a
  second release beside it.
- **No cut PR from the old flow is open.** `gh pr list --base <default> --state
  open --json number,headRefName` showing a `chore/release-*` head is a
  changelog cut opened before releases were one PR. Stop and ask a dev: merge
  it, and Step 3 snapshots its version; or close it, and Step 4 cuts on the
  release branch. Never both - the two cuts would collide at the merge-back.
- **The default branch is green.** `gh pr checks` on the last merged PR, or
  `gh run list --branch main --limit 1`. A red default branch is not promotable;
  report it and stop.

## Step 3 - pick the version, and show what would ship

Pin the commit first; every view below and the cut in Step 4 use it, so what
ships is what was shown:

```sh
base="$(git rev-parse origin/main)"   # fetched in Step 2
```

**A version already cut on the default branch wins.** A `.changes/v*.md` on
`${base}` that `origin/prod` lacks (the newest, sorted the way `release.yml`
sorts, `sort -V`) is a cut made the old way, through its own PR, or by hand.
That version is the release: go to Step 4 and snapshot it without cutting again.

Otherwise show two read-only views together:

- **The entries:** the pending fragments under `.changes/unreleased/` at
  `${base}` (their prose, not their filenames - that is what a reader will get).
- **The diff:** `git log --oneline origin/prod.."${base}"` and
  `git diff --stat origin/prod.."${base}"`.

If there are **no pending fragments but a non-empty diff**, say so plainly rather
than cutting an empty release: either the merged work shipped nothing
user-visible (promote without a cut - Step 4 with no version) or fragments were
missed (the fix is to add them, not to invent them here). If both are empty,
there is nothing to promote.

## Step 4 - cut the release branch and open the Release PR

**The cut is the release branch's first commit.** From a clean working tree (a
dirty one -> a temporary `git worktree add --detach`), every profile cuts
semver:

```sh
git switch --detach "${base}"
changie batch auto && changie merge
version="$(changie latest | sed 's/^v//')"
git add -A && git commit -m "chore(release): v${version}"
git push origin "HEAD:refs/heads/release/v${version}"
gh pr create --base prod --head "release/v${version}" \
  --title "Release v${version}" --body-file <body>
```

`auto` takes the largest bump the pending kinds declare (`Added`/`Changed`
minor, `Fixed`/`Security` patch). No kind maps to major: when a fragment
describes a breaking change, say so and cut `changie batch major` instead.

The cut is committed on a detached `HEAD` and pushed by refspec, never through
a local `release/*` branch: a run that stopped at a refused push leaves nothing
behind for the next one to push by mistake.

**Nothing lands on the default branch here.** Until the merge-back, `main`
keeps the consumed fragments and the previous `CHANGELOG.md`; the merge-back
removes the first and brings the second. Fragments merged to `main` after
`${base}` are untouched by it and wait for the next release.

**The push is refused** with `Required status check "ci" is expected` -> the
repo's `steer: release branches` ruleset predates this flow and asks for a green
`ci` on a commit no run has seen yet. **Stop**: a dev re-runs `/steer:setup
protect`, which makes that ruleset check `ci` on pushes to the branch, not on
its creation. Never force, never edit a ruleset here, and never push the
snapshot without its cut. The next run starts again from Step 1 and cuts from
the default branch as it stands then. Any other refusal (a `release/v<version>`
that already exists on origin, for one) -> report its text and stop.

**Step 3 found a version already cut** -> no cut here: snapshot the commit that
added it (`git log -1 --diff-filter=A --format=%H "${base}" --
.changes/v<version>.md`) with `git push origin <commit>:refs/heads/release/v<version>`,
and say which commit you chose. **Promotion with no version** (Step 3 found
nothing to cut) pushes `${base}` as `release/<short-sha>`, titled
`Promote <short-sha> (no version)`; `release.yml` then publishes nothing.

The body is the changelog section this release ships - the text a reviewer
needs to decide - followed by `git log --oneline origin/prod..origin/release/v<version>`,
then a short **QA** paragraph: the held environment now runs this branch, the
PO tests it there, QA fixes come as PRs into it, and who must approve (Step 5). Then say, in one line,
that merging it deploys production and is the human's call.

Do not watch CI to green here and call the work done: on a Release PR the
meaningful signal is the approval, not the run.

## Step 5 - while the release is open (QA)

Say this once, in the handoff, so the team knows the rules of the window:

- **The held environment runs the release branch, and the PO tests it there**
  for as long as QA needs. Product deploy jobs ask
  `scripts/release-target.sh` which branch to deploy (`infra/README.md` ->
  Release flow). Merges into `main` keep landing; they deploy once the Release
  PR closes. `release_hold: none` turns this off.
- **A QA defect is fixed on the release branch**: a `qa-fix/<n>` branch from
  `release/v<version>`, a PR into it, one dev approval, `ci` green. It needs **no
  changelog fragment** - the release entries already describe the work it
  repairs (`ci:changelog` passes PRs into `release/*`). The merge redeploys the
  held environment and dismisses the Release PR's approvals (stale-review
  dismissal on `prod`), so QA re-tests and the approvers look again.
- **A hotfix during QA** reaches the release branch too: `merge-back.yml`
  pushes a merge-back branch into it beside the one into `main`. The Release
  PR's last green `ci` predates the hotfix, so **re-run its checks** (or merge
  that merge-back, which re-runs them) before approving: `ci:promotion` fails it
  until prod is merged back into the release branch.
- **Who approves the Release PR**: a member of the PO team **and** a member of
  the dev team (the `prod` ruleset, `/steer:setup protect`); never its author.

## Step 6 - after the merge

Merging deploys production and `release.yml` tags `vX.Y.Z`. Then
`.github/workflows/merge-back.yml` pushes `merge-back/<pr>-to-main` at prod's
tip and comments a link on the merged PR; a dev opens that PR and merges it with
**Create a merge commit**, never squash - a squashed merge-back leaves prod out
of `main`, and the next Release PR fails `ci:promotion`. That PR is also what
brings the cut to `main` - `CHANGELOG.md`, `.changes/vX.Y.Z.md`, the consumed
fragments gone - so until it merges, `promote` refuses the next release
(Step 2). A conflict is resolved on the merge-back branch by merging `main`
into it, never on `prod`. No `merge-back.yml` installed -> push the branch by
hand (Step 2). GitHub deletes
the merged release branch (`delete_branch_on_merge`, applied by `/steer:setup
protect`); with that setting off, name the merged `release/*` branches for a
human to delete - `promote` never deletes a branch.

## Recommend the next action

Per `NEXT-ACTIONS.md`, derived from where the run stopped:

| Observed state | Category | Action |
|---|---|---|
| `production_gate` is not `prod-branch-pr` | Human decision required | The declared gate is the human's own step (no command) |
| No `prod` branch, or it is unprotected | Blocking now | `/steer:setup protect` |
| A `main -> prod` PR is open | Human decision required | Close it so a snapshot can replace it (no command) |
| Prod is not merged back into `main` | Human decision required | A dev merges the open merge-back PR with **Create a merge commit** (no command) |
| Default branch red | Blocking now | Fix the build before promoting |
| The release-branch push was refused for `ci` | Blocking now | `/steer:setup protect` (a dev), then `/steer:work promote` again |
| An abandoned `release/*` branch the default branch has moved past | Human decision required | A dev decides what becomes of that branch and its QA fixes (no command) |
| A `chore/release-*` cut PR from the old flow is open | Human decision required | A dev merges it or closes it (no command), then `/steer:work promote` again |
| Release PR open, in QA | Human decision required | The PO tests on the held environment and signs off; a PO and a dev approve and merge - **that merge deploys production** (no command) |
| Release merged, merge-back pending | Human decision required | A dev opens the merge-back PR from the bot's link and merges it with **Create a merge commit** (no command) |
| Nothing unreleased | Complete | `No action is currently required.` |
