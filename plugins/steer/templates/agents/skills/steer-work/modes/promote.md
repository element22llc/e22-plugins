# `/steer-work promote` - open the production release PR

Read this file only when `promote` is the subcommand. It is the one unit of work
in `/steer-work` that is **not issue-scoped**: the thing being delivered is
everything already merged to the default branch, which is why the skill's
Preconditions step 0b exempts it from the tracker read and the issue
find-or-create.

**What this owns and where it stops.** It prepares PRs, cuts the release
snapshot branch, and opens the Release PR. **Merging the Release PR is the
production gate and stays human** (rule `45-delivery` -> Deployment &
environments) - never `gh pr merge` here, never deploy, never push to `prod`.

**The shape.** The Release PR comes from a `release/vX.Y.Z` snapshot of the
default branch, never from `main` itself, so prod receives exactly what QA
tested while `main` keeps taking merges. While it is open, the held environment
(`policy/delivery.yml` `release_hold`, default `non-prod`) runs the release
branch instead of `main`; QA fixes land on the release branch; after the merge,
`.github/workflows/backport.yml` carries them back to `main`.

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
  `/steer-setup protect`, which is what makes the merge an approval rather than a
  formality. Do not create it yourself - an unprotected `prod` is a gate that
  looks real and is not.
- **`prod` is protected.** If `/steer-setup protect verify` shows no
  required review on `prod`, say the Release PR would merge without an
  approval, and recommend `/steer-setup protect` before continuing. Offer to continue
  anyway only if the dev says so; record that they did.
- **One release at a time.** `gh pr list --base prod --state open --json
  number,headRefName,url`:
  - a `release/*` head -> that release is **in QA**. Refresh its body (Step 5's
    body, its commit list from the release branch) and run the drop check
    below against it, report it, and **stop** - no new cut, no second
    snapshot. Pending fragments on `main` belong to the next release.
  - a `main` head (left by the earlier flow) -> **stop** and ask the dev to
    close it before a snapshot replaces it; close it (`gh pr close`) only on
    their yes.
- **Nothing prod ships is dropped.** Prod's merges carry QA fixes and hotfixes
  that reach `main` only through their back-port; a release cut before that
  lands would ship without them. Copy the repo's checker and run it:

  ```sh
  git fetch origin main prod
  sh scripts/ci-promotion.sh --list-missing origin/main origin/prod
  ```

  For a release already in QA, check its branch instead of `origin/main`.
  Any output -> stop: name the open `backport/*` PR for a human to merge, or
  follow `modes/hotfix.md` -> follow-up to open it. The required `ci` check runs
  the same test (`ci:promotion`) on the Release PR. No `scripts/ci-promotion.sh`
  yet -> fall back to the version files:
  `git diff --name-only --diff-filter=A origin/main origin/prod -- '.changes/*.md'`,
  and recommend `/steer-setup sync`.
- **The default branch is green.** `gh pr checks` on the last merged PR, or
  `gh run list --branch main --limit 1`. A red default branch is not promotable;
  report it and stop.

## Step 3 - pick the version, and show what would ship

**A version already cut wins.** The newest `.changes/v*.md` on `origin/main`
that `origin/prod` lacks (sorted the way `release.yml` sorts, `sort -V`) is the
release to snapshot - go straight to Step 5. Fragments merged since that cut are
the next release's, not this one's.

Otherwise show two read-only views together:

- **The entries:** the pending fragments under `.changes/unreleased/` (their
  prose, not their filenames - that is what a reader will get).
- **The diff:** `git log --oneline origin/prod..origin/main` and
  `git diff --stat origin/prod..origin/main`.

If there are **no pending fragments but a non-empty diff**, say so plainly rather
than cutting an empty release: either the merged work shipped nothing
user-visible (promote without a cut - Step 5 with no version) or fragments were
missed (the fix is to add them, not to invent them here). If both are empty,
there is nothing to promote.

## Step 4 - cut the changelog, in its own PR to the default branch

**Why not on the release branch.** The cut has to land on the default branch:
`.changes/unreleased/` lives there, and a cut that exists only on `prod` leaves
the fragments pending on `main` to be cut again next time, with `CHANGELOG.md`
permanently divergent between the two branches. You cannot push to a protected
`main`, so the cut is a normal PR like any other change.

On a `chore/release-<version>` branch off the default branch, every profile
cuts semver:

```sh
changie batch auto && changie merge   # version: changie latest
```

`auto` takes the largest bump the pending kinds declare (`Added`/`Changed`
minor, `Fixed`/`Security` patch). No kind maps to major: when a fragment
describes a breaking change, say so and cut `changie batch major` instead.

Commit, push, open the PR against the default branch, and **stop there this
run**. Its merge is an ordinary review, not the production gate.

## Step 5 - cut the release branch and open the Release PR

Run `promote` again once the cut has merged. **Cut the snapshot at the cut's
merge commit on the default branch** - not at `main`'s tip, whose later commits
carry fragments this version's notes do not list:

```sh
cut="$(gh pr view chore/release-<version> --json mergeCommit --jq .mergeCommit.oid)"
git push origin "${cut}:refs/heads/release/v<version>"
gh pr create --base prod --head release/v<version> \
  --title "Release v<version>" --body-file <body>
```

The cut PR cannot be found by name (merged elsewhere, renamed) -> use the
default-branch commit that added `.changes/v<version>.md`
(`git log -1 --diff-filter=A --format=%H origin/main -- .changes/v<version>.md`)
and say which commit you chose. **Promotion with no version** (Step 3 found
nothing to cut) snapshots `main`'s tip as `release/<short-sha>`, titled
`Promote <short-sha> (no version)`; `release.yml` then publishes nothing.

A `release/v<version>` branch that already exists with no open PR (its PR was
closed unmerged) is reused when it is an ancestor-or-equal of the cut, otherwise
reported - **never force-pushed**: it may carry QA fixes.

The body is the changelog section this release ships - the text a reviewer
needs to decide - followed by `git log --oneline origin/prod..origin/release/v<version>`,
then a short **QA** paragraph: the held environment now runs this branch, QA
fixes come as PRs into it, and who must approve (Step 6). Then say, in one line,
that merging it deploys production and is the human's call.

Do not watch CI to green here and call the work done: on a Release PR the
meaningful signal is the approval, not the run.

## Step 6 - while the release is open (QA)

Say this once, in the handoff, so the team knows the rules of the window:

- **The held environment runs the release branch.** Product deploy jobs ask
  `scripts/release-target.sh` which branch to deploy (`infra/README.md` ->
  Release flow). Merges into `main` keep landing; they deploy once the Release
  PR closes. `release_hold: none` turns this off.
- **A QA defect is fixed on the release branch**: a `qa-fix/<n>` branch from
  `release/v<version>`, a PR into it, one dev approval, `ci` green. It needs **no
  changelog fragment** - the release entries already describe the work it
  repairs (`ci:changelog` passes PRs into `release/*`). The merge redeploys the
  held environment and dismisses the Release PR's approvals (stale-review
  dismissal on `prod`), so QA re-tests and the approvers look again.
- **A hotfix during QA** reaches the release branch too: `backport.yml` opens
  that back-port beside the one into `main`, and `ci:promotion` fails the
  Release PR until it lands.
- **Who approves the Release PR**: a member of the PO team **and** a member of
  the dev team (the `prod` ruleset, `/steer-setup protect`); never its author.

## Step 7 - after the merge

Merging deploys production and `release.yml` tags `vX.Y.Z`. Then
`.github/workflows/backport.yml` pushes `backport/<pr>-to-main` with each QA fix
cherry-picked `-x` and comments a link on the merged PR; a human opens that PR
and merges it with **Rebase and merge**, so the cherry-pick trailers reach
`main` (`ci:promotion` reads them). No `backport.yml` installed, or it
reported a conflict -> the commands are in its comment, else
`modes/hotfix.md` -> follow-up applies the same way. The release branch is
deleted by GitHub's "Automatically delete head branches"; without it, name the
merged `release/*` branches for a human to delete - `promote` never deletes a
branch.

## Recommend the next action

Per `NEXT-ACTIONS.md`, derived from where the run stopped:

| Observed state | Category | Action |
|---|---|---|
| `production_gate` is not `prod-branch-pr` | Human decision required | The declared gate is the human's own step (no command) |
| No `prod` branch, or it is unprotected | Blocking now | `/steer-setup protect` |
| An old `main -> prod` PR is open | Human decision required | A dev closes it so a snapshot can replace it (no command) |
| Prod ships a change `main` lacks | Human decision required | A dev merges the open back-port PR into `main` (no command) |
| Default branch red | Blocking now | Fix the build before promoting |
| Changelog cut PR open | Human decision required | A dev reviews and merges the cut (no command) |
| Release PR open, in QA | Human decision required | QA signs off; a PO and a dev approve and merge - **that merge deploys production** (no command) |
| Release merged, back-port pending | Human decision required | A dev opens and merges the back-port PR from the bot's link (no command) |
| Nothing unreleased | Complete | `No action is currently required.` |
