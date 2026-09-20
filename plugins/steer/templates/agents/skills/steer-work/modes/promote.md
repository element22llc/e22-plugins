# `/steer-work promote` - open the production promotion PR

Read this file only when `promote` is the subcommand. It is the one unit of work
in `/steer-work` that is **not issue-scoped**: the thing being delivered is
everything already merged to the default branch, which is why the skill's
Preconditions step 0b exempts it from the tracker read and the issue
find-or-create.

**What this owns and where it stops.** It prepares and opens PRs. **Merging the
promotion PR is the production gate and stays human** (rule `45-delivery`,
rule `45-delivery` § Deployment & environments) - never `gh pr merge` here, never deploy, never push to
`prod`.

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
  `/steer-protect`, which is what makes the merge an approval rather than a
  formality. Do not create it yourself - an unprotected `prod` is a gate that
  looks real and is not.
- **`prod` is protected.** If `/steer-protect --check`-equivalent state shows no
  required review on `prod`, say the promotion PR would merge without an
  approval, and recommend `/steer-protect` before continuing. Offer to continue
  anyway only if the dev says so; record that they did.
- **The default branch is green.** `gh pr checks` on the last merged PR, or
  `gh run list --branch main --limit 1`. A red default branch is not promotable;
  report it and stop.

## Step 3 - show what would ship, before touching anything

Two views, both read-only, printed together:

- **The entries:** the pending fragments under `.changes/unreleased/` (their
  prose, not their filenames - that is what a reader will get).
- **The diff:** `git log --oneline prod..main` and `git diff --stat prod..main`.

If there are **no pending fragments but a non-empty diff**, say so plainly rather
than cutting an empty release: either the merged work shipped nothing
user-visible (promote without a cut - skip Step 4) or fragments were missed
(the fix is to add them, not to invent them here). If both are empty, there is
nothing to promote.

## Step 4 - cut the changelog, in its own PR to the default branch

**Why not in the promotion PR.** The cut has to land on the default branch:
`.changes/unreleased/` lives there, and a cut that exists only on `prod` leaves
the fragments pending on `main` to be cut again next time, with `CHANGELOG.md`
permanently divergent between the two branches. You cannot push to a protected
`main`, so the cut is a normal PR like any other change.

On a `chore/release-<version>` branch off the default branch:

```sh
changie batch $(date +%Y.%-m.%-d) && changie merge   # app / service - CalVer, the ship date
changie batch auto && changie merge                  # library / cli - the artifact version
```

`%-m`/`%-d` are load-bearing: changie normalizes `2026.09.15` to a `2026.9.15`
heading while naming the file `2026.09.15.md`, and the two then disagree
permanently. The profile decides which line runs - read the `CLAUDE.md`
`## Profile` marker; absent means `app`.

Commit, push, open the PR against the default branch, and **stop there this
run**. Its merge is an ordinary review, not the production gate.

## Step 5 - open the promotion PR

Run `promote` again once the cut has merged (or immediately, when Step 3 found
nothing to cut). The step is idempotent: if an open `main -> prod` PR already
exists, update its body rather than opening a second one.

```sh
gh pr create --base prod --head main \
  --title "promote: <version>" --body-file <body>
```

The body is the changelog section this promotion ships - the text a reviewer
needs to decide - followed by the commit list from Step 3. Then say, in one line,
that merging it deploys production and is the human's call.

Do not watch CI to green here and call the work done: on a promotion PR the
meaningful signal is the approval, not the run.

## Recommend the next action

Per `NEXT-ACTIONS.md`, derived from where the run stopped:

| Observed state | Category | Action |
|---|---|---|
| `production_gate` is not `prod-branch-pr` | Human decision required | The declared gate is the human's own step (no command) |
| No `prod` branch, or it is unprotected | Blocking now | `/steer-protect` |
| Default branch red | Blocking now | Fix the build before promoting |
| Changelog cut PR open | Human decision required | A dev reviews and merges the cut (no command) |
| Promotion PR open | Human decision required | A dev approves and merges - **that merge deploys production** (no command) |
| Nothing unreleased | Complete | `No action is currently required.` |
